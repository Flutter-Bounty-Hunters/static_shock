import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock_cli/src/package_name_validation.dart';

class BasicTemplateConfigurator {
  static Future<Map<String, dynamic>> promptForConfiguration(Logger log, Map<String, dynamic> cliArgs) async {
    final vars = <String, dynamic>{};

    if (cliArgs["project_name"] == null) {
      vars["project_name"] = _promptForProjectName(log);
    }

    if (cliArgs["project_description"] == null) {
      vars["project_description"] = _promptForProjectDescription(log);
    }

    return vars;
  }

  const BasicTemplateConfigurator._();
}

String _promptForProjectName(Logger log) {
  String? projectName;
  do {
    projectName = log.prompt("Project name (e.g., 'static_shock_docs')");
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

  return projectName;
}

String _promptForProjectDescription(Logger log) {
  return log.prompt("Project description (e.g., 'Documentation for Static Shock')");
}
