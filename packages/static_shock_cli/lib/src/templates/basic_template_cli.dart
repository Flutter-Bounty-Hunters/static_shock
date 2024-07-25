import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock_cli/src/package_name_validation.dart';

class BasicTemplateConfigurator {
  static BasicTemplateConfiguration promptForConfiguration(Logger log) {
    final projectName = _promptForProjectName(log);
    final projectDescription = _promptForProjectDescription(log);

    return BasicTemplateConfiguration(
      projectName: projectName,
      projectDescription: projectDescription,
    );
  }

  static Directory promptForOutputDirectory(Logger log) {
    return _promptForTargetDiretory(log);
  }

  const BasicTemplateConfigurator._();
}

class BasicTemplateConfiguration {
  const BasicTemplateConfiguration({
    required this.projectName,
    required this.projectDescription,
  });

  final String projectName;
  final String projectDescription;
}

String _promptForProjectName(Logger log) {
  String? projectName;
  do {
    projectName = log.prompt(
      "Choose a website project name, e.g., 'static_shock_docs' (used as project name in pubspec.yaml):",
    );
    if (projectName.trim().isEmpty) {
      log.err("Your project name can't be blank");
      continue;
    }

    // Check validity of package name and let user fix it.
    if (!PackageName.isValid(projectName)) {
      log.warn("Your project name doesn't follow Dart package naming guidelines.");
      final choice = log.chooseOne("What would you like to do?", choices: [
        if (PackageName.canFix(projectName)) //
          "autoFix",
        "newName",
        "useAnyway",
      ], display: (String option) {
        switch (option) {
          case "autoFix":
            return "Adjust name to '${PackageName.fix(projectName!)}'";
          case "newName":
            return "Enter a new name";
          case "useAnyway":
            return "Use the name anyway";
          default:
            throw Exception("Unknown choice: '$option'");
        }
      });

      switch (choice) {
        case "autoFix":
          projectName = PackageName.fix(projectName);
        case "newName":
          projectName = "";
      }
    }
  } while (projectName.trim().isEmpty);

  log.info("");

  return projectName;
}

String _promptForProjectDescription(Logger log) {
  final description = log.prompt(
    "Website project description, e.g., 'Documentation for Static Shock' (used as project description in pubspec.yaml):",
  );
  log.info("");

  return description;
}

Directory _promptForTargetDiretory(Logger log) {
  late Directory directory;

  do {
    final response =
        log.prompt("In which directory would you like to generate the project? Leave blank for current directory:");
    log.info("");
    directory = response.isEmpty ? Directory.current : Directory(response);

    if (!directory.existsSync()) {
      final createDirectory = log.confirm("The chosen directory doesn't exist yet. Would you like us to create it?");
      log.info("");

      if (createDirectory) {
        directory.createSync();
      }
    }
  } while (!directory.existsSync());

  return directory;
}
