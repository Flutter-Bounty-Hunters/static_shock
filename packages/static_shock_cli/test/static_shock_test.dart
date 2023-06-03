import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';

void main() {
  group("project creation", () {
    final testProjectDirectory =
        Directory("${Directory.current.path}${Platform.pathSeparator}test${Platform.pathSeparator}cli_output_tests");

    setUp(() {
      // Clear out the directory that's used to generate new static website
      // projects in the test suite.
      if (testProjectDirectory.existsSync()) {
        testProjectDirectory.deleteSync(recursive: true);
      }
      testProjectDirectory.createSync();
    });

    test("simplest", () {
      final randomNumber = Random().nextInt(1000);
      File("${testProjectDirectory.path}${Platform.pathSeparator}my_test_file_$randomNumber.txt").createSync();
    });
  });
}
