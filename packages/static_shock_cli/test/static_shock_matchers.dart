import 'dart:io';

import 'package:test/expect.dart';

/// Returns a [ProjectFileExistenceMatcher] that matches against the given [golden] directory.
Matcher hasSameFiles(Directory golden) => ProjectFileExistenceMatcher(golden);

/// A [Matcher] that expects the same file names and file locations between a "golden"
/// directory and a given test directory.
///
/// This matcher doesn't compare file contents.
class ProjectFileExistenceMatcher extends Matcher {
  const ProjectFileExistenceMatcher(this.golden);

  final Directory golden;

  @override
  Description describe(Description description) {
    return description.add("Contains every and only files in '${golden.path}'");
  }

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! Directory) {
      matchState["error"] = "The given comparison directory isn't a Directory: $item";
      return false;
    }

    if (!item.existsSync()) {
      matchState["error"] = "The given comparison directory doesn't exist: ${item.path}";
      return false;
    }

    if (!golden.existsSync()) {
      matchState["error"] = "The given golden directory doesn't exist: ${golden.path}";
      return false;
    }

    final missingFiles = <File>[];
    for (final file in golden.listSync(recursive: true)) {
      if (file is! File) {
        // This is a Directory or Link. Ignore it.
        continue;
      }

      final relativeFilePath = file.path.replaceFirst("${golden.path}${Platform.pathSeparator}", "");
      final expectedTestFile = File("${item.path}${Platform.pathSeparator}$relativeFilePath");

      if (!expectedTestFile.existsSync()) {
        missingFiles.add(expectedTestFile);
      }
    }

    final unexpectedFiles = <File>[];
    for (final file in item.listSync(recursive: true)) {
      if (file is! File) {
        // This is a Directory or Link. Ignore it.
        continue;
      }

      final relativeFilePath = file.path.replaceFirst("${item.path}${Platform.pathSeparator}", "");
      final testFileInGoldenDirectory = File("${golden.path}${Platform.pathSeparator}$relativeFilePath");

      if (!testFileInGoldenDirectory.existsSync()) {
        unexpectedFiles.add(file);
      }
    }

    if (missingFiles.isNotEmpty || unexpectedFiles.isNotEmpty) {
      matchState["missingFiles"] = missingFiles;
      matchState["unexpectedFiles"] = unexpectedFiles;
      return false;
    }

    return true;
  }

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription, Map matchState, bool verbose) {
    final missingFiles = matchState["missingFiles"];
    if (missingFiles is List<File> && missingFiles.isNotEmpty) {
      mismatchDescription
        ..add("is missing expected files:")
        ..addAll(" - ", "\n", "", missingFiles.map((file) => file.path));
    }

    final unexpectedFiles = matchState["unexpectedFiles"];
    if (unexpectedFiles is List<File> && unexpectedFiles.isNotEmpty) {
      mismatchDescription
        ..add("contains unexpected files")
        ..addAll(" - ", "\n", "", unexpectedFiles.map((file) => file.path));
    }

    return mismatchDescription;
  }
}
