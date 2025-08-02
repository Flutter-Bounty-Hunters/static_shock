import 'dart:io';

import 'package:path/path.dart';
import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/source_files.dart';

abstract class Theme {
  static Theme fromGit({
    required String url,
    String? path,
    String? ref,
  }) =>
      GitTheme(url: url, path: path, ref: ref);

  Future<void> load(StaticShockPipeline pipeline, StaticShockPipelineContext context);

  String get describe;
}

class GitTheme implements Theme {
  const GitTheme({
    required this.url,
    this.path,
    this.ref,
  });

  final String url;
  final String? path;
  final String? ref;

  @override
  Future<void> load(StaticShockPipeline pipeline, StaticShockPipelineContext context) async {
    final normalizedUrl = Uri.parse(url).normalizePath();
    final directoryName = "${normalizedUrl.host}/${normalizedUrl.path}".replaceAll("/", "_");

    final cloneDirectory = context.buildCacheDirectory.subDir(["themes", "git", directoryName]).absolute;
    cloneDirectory.createSync(recursive: true);

    // Clone the theme repo into the build cache. This repo might already exist
    // here in the cache, but trying to clone again shouldn't cause any issues.
    await Process.run("git", ["clone", url, cloneDirectory.path]);

    // Checkout the desired ref.
    await Process.run("git", ["fetch", "origin"], workingDirectory: cloneDirectory.path);
    if (ref != null) {
      final result = await Process.run("git", ["checkout", ref!], workingDirectory: cloneDirectory.path);
      if (result.exitCode != 0) {
        context.errorLog.crash("Failed to checkout Git theme ref ($ref): ${result.stderr}");
      }
    } else {
      final result = await Process.run("git", ["checkout", "HEAD"], workingDirectory: cloneDirectory.path);
      if (result.exitCode != 0) {
        context.errorLog.crash("Failed to checkout Git theme ref (HEAD): ${result.stderr}");
      }
    }

    // Pull the latest for the branch.
    await Process.run("git", ["pull"], workingDirectory: cloneDirectory.path);

    // Walk all files within the desired path and add them to the pipeline.
    final themeDirectory = path != null ? cloneDirectory.subDir(path!.split(separator)) : cloneDirectory;

    final sourceFiles = SourceFiles(
      directory: themeDirectory,
      excludedPaths: {},
    );

    pipeline.addSourceExtension(sourceFiles);
  }

  @override
  String get describe => "Theme (from git) - url: $url, path: ${path ?? "none"}, ref: ${ref ?? "none"}";
}
