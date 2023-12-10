import 'dart:io';

import 'package:mason/mason.dart';
import 'package:yaml/yaml.dart';

/// Builds a static shock website from a source directory.
///
/// Expects to find a `pubspec.yaml` in the current directory.
///
/// Expects to find a project name in the `pubspec.yaml`, which is then expected to lead
/// to the executable file via `bin/[package_name].dart`.
Future<int?> buildWebsite({
  Logger? log,
  bool attachBuildProcessToStdIo = true,
}) async {
  final pubspecFile = File("pubspec.yaml");
  if (!pubspecFile.existsSync()) {
    log?.err("Couldn't find pubspec.yaml. This must not be a Static Shock project.");
    return null;
  }

  final pubspec = loadYaml(pubspecFile.readAsStringSync());
  final packageName = pubspec["name"] as String?;
  if (packageName == null || packageName.isEmpty) {
    log?.err("Couldn't find the project's package name in pubspec.yaml.");
    return null;
  }

  final packageNameExecutable = File("bin${Platform.pathSeparator}$packageName.dart");
  final mainExecutable = File("bin${Platform.pathSeparator}main.dart");
  if (!packageNameExecutable.existsSync() && !mainExecutable.existsSync()) {
    log?.err("Couldn't find the project's executable. Please check your /bin directory.");
    return null;
  }

  final executableFile = packageNameExecutable.existsSync() ? packageNameExecutable : mainExecutable;

  log?.detail("Running Static Shock executable: ${executableFile.path}");
  final process = await Process.start(
    'dart',
    [executableFile.path],
  );

  stdout.addStream(process.stdout);
  stderr.addStream(process.stderr);

  return process.exitCode;
}

typedef WebsiteBuilder = Future<int?> Function({bool attachBuildProcessToStdIo});
