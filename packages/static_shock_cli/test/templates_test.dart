// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'static_shock_matchers.dart';

// WARNING: Run these tests from the static_shock_cli directory. These tests depend
// upon knowledge of the nearby file system so that they can generate projects during
// the tests.
void main() {
  final rootTestGoldenDirectory = Directory(
      "${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}template_goldens${Platform.pathSeparator}");
  final rootTestOutputDirectory = Directory(
      "${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}.template_test_output${Platform.pathSeparator}");

  setUp(() {
    // Clear out the directory that's used to generate new static website
    // projects in the test suite.
    if (rootTestOutputDirectory.existsSync()) {
      rootTestOutputDirectory.deleteSync(recursive: true);
    }
    rootTestOutputDirectory.createSync(recursive: true);
  });

  tearDown(() {
    // Clear out the directory that's used to generate new static website
    // projects in the test suite.
    if (rootTestOutputDirectory.existsSync()) {
      rootTestOutputDirectory.deleteSync(recursive: true);
    }
  });

  group("Template project reaction > ", () {
    group("empty >", () {
      test("minimal", () async {
        final testGoldenDirectory = Directory("${rootTestGoldenDirectory.path}empty${Platform.pathSeparator}minimal");
        final testOutputDirectory = Directory("${rootTestOutputDirectory.path}empty${Platform.pathSeparator}minimal");
        testOutputDirectory.createSync(recursive: true);

        final process = await Process.start(
          'dart',
          [
            '../../../../bin/static_shock_cli.dart',
            'template',
            'empty',
            '--project-name=empty_golden',
            '--project-description="Golden project structure for the empty template."',
            '--no-auto-initialize',
          ],
          workingDirectory: testOutputDirectory.path,
        );

        // We have to connect to stderr to get the command to run. Not sure why.
        print(await utf8.decodeStream(process.stderr));

        expect(testOutputDirectory, hasSameFiles(testGoldenDirectory));
      });
    });

    group("blog >", () {
      test("standard", () async {
        final testGoldenDirectory = Directory("${rootTestGoldenDirectory.path}blog${Platform.pathSeparator}standard");
        final testOutputDirectory = Directory("${rootTestOutputDirectory.path}blog${Platform.pathSeparator}standard");
        testOutputDirectory.createSync(recursive: true);

        final process = await Process.start(
          'dart',
          [
            '../../../../bin/static_shock_cli.dart',
            'template',
            'blog',
            '--project-name=my_blog',
            '--project-description="My blog website project"',
            '--blog-title="Better Living"',
            '--blog-description="Articles about living a better life"',
            '--no-auto-initialize',
          ],
          workingDirectory: testOutputDirectory.path,
        );

        // We have to connect to stderr to get the command to run. Not sure why.
        print(await utf8.decodeStream(process.stderr));

        expect(testOutputDirectory, hasSameFiles(testGoldenDirectory));
      });
    });

    group("docs multi page >", () {
      test("minimal", () async {
        final testGoldenDirectory =
            Directory("${rootTestGoldenDirectory.path}docs_multi_page${Platform.pathSeparator}minimal");
        final testOutputDirectory =
            Directory("${rootTestOutputDirectory.path}docs_multi_page${Platform.pathSeparator}minimal");
        testOutputDirectory.createSync(recursive: true);

        final process = await Process.start(
          'dart',
          [
            '../../../../bin/static_shock_cli.dart',
            'template',
            'docs-multi-page',
            '--project-name=super_editor_docs',
            '--project-description="Documentation for Super Editor"',
            '--package-name=super_editor',
            '--package-title="Super Editor"',
            '--package-description="A document editing toolkit for Flutter"',
            '--no-auto-initialize',
          ],
          workingDirectory: testOutputDirectory.path,
        );

        // We have to connect to stderr to get the command to run. Not sure why.
        print(await utf8.decodeStream(process.stderr));

        expect(testOutputDirectory, hasSameFiles(testGoldenDirectory));
      });

      test("complete", () async {
        final testGoldenDirectory =
            Directory("${rootTestGoldenDirectory.path}docs_multi_page${Platform.pathSeparator}complete");
        final testOutputDirectory =
            Directory("${rootTestOutputDirectory.path}docs_multi_page${Platform.pathSeparator}complete");
        testOutputDirectory.createSync(recursive: true);

        final process = await Process.start(
          'dart',
          [
            '../../../../bin/static_shock_cli.dart',
            'template',
            'docs-multi-page',
            '--project-name=super_editor_docs',
            '--project-description="Documentation for Super Editor"',
            '--package-name=super_editor',
            '--package-title="Super Editor"',
            '--package-description="A document editing toolkit for Flutter"',
            '--package-is-on-pub',
            '--github-organization=superlistapp',
            '--github-repo-name=super_editor',
            '--sponsorship=https://flutterbountyhunters.com',
            '--discord=https://discord.gg/8hna2VD32s',
            '--no-auto-initialize',
          ],
          workingDirectory: testOutputDirectory.path,
        );

        // We have to connect to stderr to get the command to run. Not sure why.
        print(await utf8.decodeStream(process.stderr));

        expect(testOutputDirectory, hasSameFiles(testGoldenDirectory));
      });
    });

    group("docs >", () {
      test("minimal", () async {
        final testGoldenDirectory = Directory("${rootTestGoldenDirectory.path}docs${Platform.pathSeparator}minimal");
        final testOutputDirectory = Directory("${rootTestOutputDirectory.path}docs${Platform.pathSeparator}minimal");
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
        final testGoldenDirectory = Directory("${rootTestGoldenDirectory.path}docs${Platform.pathSeparator}complete");
        final testOutputDirectory = Directory("${rootTestOutputDirectory.path}docs${Platform.pathSeparator}complete");
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
  });
}
