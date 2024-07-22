import 'dart:io';

import 'package:mason/mason.dart';

class Project {
  static Future<void> build({
    Logger? log,
    Directory? workingDirectory,
  }) async {
    log?.info("Running 'pub get' to initialize your project...");
    final pubGetResult = await Process.run(
      'dart',
      ['pub', 'get'],
      workingDirectory: (workingDirectory ?? Directory.current).absolute.path,
    );
    log?.detail(pubGetResult.stdout);
    if (pubGetResult.exitCode != 0) {
      log?.err("Command 'pub get' failed. Please check your project for errors.");
      return;
    }

    log?.info("Successfully initialized your project. Now we'll run an initial build of your static site.");
  }

  static Future<void> pubGet({
    Logger? log,
    Directory? workingDirectory,
    String executablePath = 'bin/main.dart',
  }) async {
    final buildResult = await Process.run(
      'dart',
      ['run', executablePath],
      workingDirectory: (workingDirectory ?? Directory.current).absolute.path,
    );
    log?.detail(buildResult.stdout);
    if (buildResult.exitCode != 0) {
      log?.err("Failed to build your static site. Please check your project for errors.");
      return;
    }
  }

  const Project._();
}
