import 'dart:async';
import 'dart:io';

import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

import '../pages.dart';

class PrettyUrlsPlugin implements StaticShockPlugin {
  const PrettyUrlsPlugin();

  @override
  final id = "io.staticshock.prettyurls";

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.transformPages(const PrettyPathPageTransformer());
  }
}

/// Prettify the destination page path by making the page an index.html within
/// a directory named after the page:
///
///    posts/hello-world.html -> posts/hello-world/index.html
class PrettyPathPageTransformer implements PageTransformer {
  const PrettyPathPageTransformer();

  @override
  FutureOr<void> transformPage(StaticShockPipelineContext context, Page page) async {
    final originalPath = page.destinationPath ?? page.sourcePath;
    if (originalPath.directories.isEmpty && originalPath.filename == "index") {
      // This is the root index file.
      page.pagePath = "";
      return;
    }

    final pathBeforePageFile = originalPath.directories.isNotEmpty ? "${originalPath.directories.join("/")}/" : "";

    page.pagePath = originalPath.filename != "index"
        // First case is like "posts/news/hello-world.md" -> "posts/news/hello-world/"
        ? "$pathBeforePageFile${originalPath.filename}/"
        // Second case is like "posts/news/hello-world/index.md" -> "posts/news/hello-world/"
        : pathBeforePageFile;

    if (page.destinationPath?.filename != "index") {
      // This page's destination hasn't been fully configured yet. Set
      // destination page to an index file so webservers can serve it.
      page.destinationPath = originalPath.copyWith(
        directoryPath: "${originalPath.directoryPath}${originalPath.filename}${Platform.pathSeparator}",
        filename: "index",
      );
    }
  }
}
