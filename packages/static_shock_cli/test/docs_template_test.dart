// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'static_shock_matchers.dart';

// WARNING: Run these tests from the static_shock_cli directory. These tests depend
// upon knowledge of the nearby file system so that they can generate projects during
// the tests.
void main() {
  group("Template project reaction > docs >", () {
    final rootTestGoldenDirectory = Directory(
        "${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}template_goldens${Platform.pathSeparator}docs");
    final rootTestOutputDirectory = Directory(
        "${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}.template_test_output${Platform.pathSeparator}docs");

    setUp(() {
      // Clear out the directory that's used to generate new static website
      // projects in the test suite.
      if (rootTestOutputDirectory.existsSync()) {
        rootTestOutputDirectory.deleteSync(recursive: true);
      }
      rootTestOutputDirectory.createSync(recursive: true);
    });

    test("minimal", () async {
      final testGoldenDirectory = Directory("${rootTestGoldenDirectory.path}${Platform.pathSeparator}minimal");

      final testOutputDirectory = Directory("${rootTestOutputDirectory.path}${Platform.pathSeparator}minimal");
      testOutputDirectory.createSync(recursive: true);

      final process = await Process.start(
        'dart',
        [
          '../../../../bin/static_shock_cli.dart',
          'template',
          'docs',
          '--args-only',
          '--project-name=super_editor_docs',
          '--package-name=super_editor',
          '--package-title=Super Editor',
          '--no-auto-initialize',
        ],
        workingDirectory: testOutputDirectory.path,
        // stdoutEncoding: utf8,
        // stderrEncoding: utf8,
      );

      // We have to connect to stderr to get the command to run. Not sure why.
      await utf8.decodeStream(process.stderr);

      expect(testOutputDirectory, hasSameFiles(testGoldenDirectory));
    });

    test("complete", () async {
      final testGoldenDirectory = Directory("${rootTestGoldenDirectory.path}${Platform.pathSeparator}complete");

      final testOutputDirectory = Directory("${rootTestOutputDirectory.path}${Platform.pathSeparator}complete");
      testOutputDirectory.createSync(recursive: true);

      final process = await Process.start(
        'dart',
        [
          '../../../../bin/static_shock_cli.dart',
          'template',
          'docs',
          '--args-only',
          '--project-name=super_editor_docs',
          '--project-description=Documentation for Super Editor',
          '--package-name=super_editor',
          '--package-title=Super Editor',
          '--package-description=A document editing toolkit for Flutter',
          '--package-is-on-pub',
          '--github-repo-url=https://github.com/superlistapp/super_editor',
          '--github-repo-organization=superlistapp',
          '--github-repo-name=super_editor',
          '--sponsorship=https://flutterbountyhunters.com',
          '--discord=https://discord.gg/8hna2VD32s',
          '--no-auto-initialize',
        ],
        workingDirectory: testOutputDirectory.path,
        // stdoutEncoding: utf8,
        // stderrEncoding: utf8,
      );

      // We have to connect to stderr to get the command to run. Not sure why.
      await utf8.decodeStream(process.stderr);

      expect(testOutputDirectory, hasSameFiles(testGoldenDirectory));
    });
  });
}
