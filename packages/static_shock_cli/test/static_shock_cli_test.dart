import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group("project creation >", () {
    final testSamplesDirectory =
        Directory("${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}cli_output_samples");
    final testOutputDirectory =
        Directory("${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}cli_output_tests");

    setUp(() {
      // Clear out the directory that's used to generate new static website
      // projects in the test suite.
      if (testOutputDirectory.existsSync()) {
        testOutputDirectory.deleteSync(recursive: true);
      }
      testOutputDirectory.createSync();
    });

    test("default", () async {
      // final randomNumber = Random().nextInt(1000);
      // File("${testOutputDirectory.path}${Platform.pathSeparator}my_test_file_$randomNumber.txt").createSync();

      for (final entity in testSamplesDirectory.listSync(recursive: true)) {
        print("${entity.path}");
      }
      print("");

      final testOutputDirectoryPath = "${testOutputDirectory.path}/project_creation/default";
      print("Test output directory: $testOutputDirectoryPath");
      Directory(testOutputDirectoryPath).createSync(recursive: true);

      print("Generating new project...");
      final process = await Process.start(
        'dart',
        ["../../../../bin/static_shock_cli.dart", "create"],
        workingDirectory: testOutputDirectoryPath,
        // stdoutEncoding: utf8,
        // stderrEncoding: utf8,
      );
      print("Process is started. Process: $process");
      final stdErr = await utf8.decodeStream(process.stderr);
      print("stderr: $stdErr");

      // print("Result: ${result.exitCode}");
      // print("Stdout: ${result.stdout}");
      // print("Stderr: ${result.stderr}");

      print("Generation is complete. Files:");
      for (final entity in testOutputDirectory.listSync(recursive: true)) {
        print("${entity.path}");
      }
    });
  });
}
