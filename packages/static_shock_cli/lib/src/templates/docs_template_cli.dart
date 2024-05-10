import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/package_name_validation.dart';

/// Assembles configuration details for a new documentation website, e.g.,
/// prompts the user for new project details.
///
/// Fully specified command:
///
/// ```shell
/// shock template docs \
///   --project-name=super_editor_docs \
///   --project-description="Documentation for Super Editor" \
///   \
///   --package-name=super_editor \
///   --package-title="Super Editor" \
///   --package-description="A document editing toolkit for Flutter" \
///   --package-is-on-pub=true \
///   \
///   --github-repo-url=https://github.com/superlistapp/super_editor \
///   --github-organization=superlistapp \
///   --github-repo-name=super_editor \
///   --discord=https://discord.gg/8hna2VD32s \
///   --sponsorship=https://flutterbountyhunters.com
/// ```
class DocsTemplateCommand extends Command {
  static const argProjectName = "project-name";
  static const argProjectDescription = "project-description";
  static const argPackageName = "package-name";
  static const argPackageTitle = "package-title";
  static const argPackageDescription = "package-description";
  static const argPackageIsOnPub = "package-is-on-pub";
  static const argGithubRepoUrl = "github-repo-url";
  static const argGithubRepoOrganization = "github-repo-organization";
  static const argGithubRepoName = "github-repo-name";
  static const argDiscord = "discord";
  static const argSponsorship = "sponsorship";
  static const argArgsOnly = "args-only";
  static const argAutoInitialize = "auto-initialize";

  static const templateKeyProjectName = "project_name";
  static const templateKeyProjectDescription = "project_description";
  static const templateKeyPackageName = "package_name";
  static const templateKeyPackageTitle = "package_title";
  static const templateKeyPackageDescription = "package_description";
  static const templateKeyPackageIsOnPub = "package_is_on_pub";
  static const templateKeyGithubRepoUrl = "github_url";
  static const templateKeyGithubRepoOrganization = "github_organization";
  static const templateKeyGithubRepoName = "github_repo_name";
  static const templateKeyDiscord = "discord_url";
  static const templateKeySponsorship = "sponsorship_url";

  DocsTemplateCommand(this.log) {
    argParser
      ..addOption(
        argProjectName,
        help: "The name of the new Static Shock project - it should be a valid Dart package name.",
      )
      ..addOption(
        argProjectDescription,
        help: "The description of the new Static Shock project - will be added to the project's pubspec file.",
        defaultsTo: "",
      )
      ..addOption(
        argPackageName,
        help: "The name of the package that this website will document (e.g., super_editor).",
      )
      ..addOption(
        argPackageTitle,
        help: "Human readable title of the package that this website will document (e.g., Super Editor).",
      )
      ..addOption(
        argPackageDescription,
        help:
            "Human readable description of the package that this website will document (e.g., A document editing toolkit for Flutter).",
      )
      ..addFlag(
        argPackageIsOnPub,
        help: "True if the documented package is published to Pub, or false otherwise.",
        defaultsTo: false,
      )
      ..addOption(
        argGithubRepoUrl,
        help: "The full URL to the documented package on GitHub.",
      )
      ..addOption(
        argGithubRepoOrganization,
        help: "The organization/user to which the documented package belongs on GitHub.",
      )
      ..addOption(
        argGithubRepoName,
        help: "The name of the GitHub repository that contains the documented package.",
      )
      ..addOption(
        argDiscord,
        help: "The URL to the Discord channel associated with the documented package.",
      )
      ..addOption(
        argSponsorship,
        help: "The URL to a website where users can financially support your work.",
      )
      ..addFlag(
        argArgsOnly,
        help:
            "True if this command is expected to run fully with the provided arguments, or false if user intervention is expected.",
        defaultsTo: false,
      )
      ..addFlag(
        argAutoInitialize,
        help:
            "True if this command should immediately run 'dart pub get' and 'shock build' after generating the project.",
        defaultsTo: true,
      );
  }

  final Logger log;

  @override
  String get name => "docs";

  @override
  String get description => "Create a template for a documentation website.";

  @override
  Future<void> run() async {
    final masonTemplateConfig = await _promptForConfiguration(log, argResults);

    final bundle = await _loadNewProjectTemplateBundle();
    final generator = await MasonGenerator.fromBundle(bundle);
    final target = DirectoryGeneratorTarget(Directory.current);

    await generator.generate(target, vars: masonTemplateConfig);

    log.success("Successfully created a new Static Shock project!\n");

    if (argResults?[argAutoInitialize] == true) {
      log.info("Running 'pub get' to initialize your project...");
      final pubGetResult = await Process.run('dart', ['pub', 'get']);
      log.detail(pubGetResult.stdout);
      if (pubGetResult.exitCode != 0) {
        log.err("Command 'pub get' failed. Please check your project for errors.");
        return;
      }

      log.info("Successfully initialized your project. Now we'll run an initial build of your static site.");
      final buildResult = await Process.run('dart', ['run', 'bin/${masonTemplateConfig['project_name']}.dart']);
      log.detail(buildResult.stdout);
      if (buildResult.exitCode != 0) {
        log.err("Failed to build your static site. Please check your project for errors.");
        return;
      }
    }

    log.success("Congratulations, your Static Shock project is ready to go!");

    log.info("\nTo learn how to use Static Shock, check out staticshock.io\n");
  }

  Future<Map<String, dynamic>> _promptForConfiguration(Logger log, ArgResults? cliArgs) async {
    final vars = <String, dynamic>{};

    if (cliArgs != null) {
      print("Collected args:");
      for (final optionName in cliArgs.options) {
        print(" - $optionName: ${cliArgs[optionName]} - ${cliArgs[optionName].runtimeType}");
      }
    }

    if (cliArgs != null && cliArgs[argArgsOnly]) {
      // The user wants to run this command exclusively with CLI args - no human
      // interaction. Validate the provided information and then return the
      // configuration data.
      final missingArgs = <String>[];

      if (_isNullOrEmpty(cliArgs[argProjectName])) {
        missingArgs.add(argProjectName);
      }
      if (_isNullOrEmpty(cliArgs[argPackageName])) {
        missingArgs.add(argPackageName);
      }
      if (_isNullOrEmpty(cliArgs[argPackageTitle])) {
        missingArgs.add(argPackageTitle);
      }

      if (missingArgs.isNotEmpty) {
        log.err("The command is missing the following required arguments: ${missingArgs.join(", ")}");
        return {};
      }

      return {
        templateKeyProjectName: cliArgs[argProjectName],
        templateKeyProjectDescription: cliArgs[argProjectDescription],
        templateKeyPackageName: cliArgs[argPackageName],
        templateKeyPackageTitle: cliArgs[argPackageTitle],
        templateKeyPackageDescription: cliArgs[argPackageDescription],
        templateKeyPackageIsOnPub: cliArgs[argPackageIsOnPub],
        templateKeyGithubRepoUrl: cliArgs[argGithubRepoUrl],
        templateKeyGithubRepoOrganization: cliArgs[argGithubRepoOrganization],
        templateKeyGithubRepoName: cliArgs[argGithubRepoName],
        templateKeyDiscord: cliArgs[argDiscord],
        templateKeySponsorship: cliArgs[argSponsorship],
      };
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argProjectName])) {
      vars[templateKeyProjectName] = _promptForProjectName(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argProjectDescription])) {
      vars[templateKeyProjectDescription] = _promptForProjectDescription(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argPackageName])) {
      vars[templateKeyPackageName] = _promptForPackageName(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argPackageTitle])) {
      vars[templateKeyPackageTitle] = _promptForPackageTitle(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argPackageDescription])) {
      vars[templateKeyPackageDescription] = _promptForPackageDescription(log);
    }

    if (cliArgs == null || !cliArgs[argPackageIsOnPub]) {
      vars[templateKeyPackageIsOnPub] = _promptForPackageIsOnPub(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argGithubRepoUrl])) {
      vars[templateKeyGithubRepoUrl] = _promptForGithubRepoUrl(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argGithubRepoOrganization])) {
      vars[templateKeyGithubRepoOrganization] = _promptForGithubRepoOrganization(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argGithubRepoName])) {
      vars[templateKeyGithubRepoName] = _promptForGithubRepoName(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argDiscord])) {
      vars[templateKeyDiscord] = _promptForDiscordUrl(log);
    }

    if (cliArgs == null || _isNullOrEmpty(cliArgs[argSponsorship])) {
      vars[templateKeySponsorship] = _promptForSponsorshipUrl(log);
    }

    return vars;
  }

  Future<MasonBundle> _loadNewProjectTemplateBundle() async {
    // We expect to run as a globally activated Dart package. To access assets bundled
    // with our package, we need to resolve a package path to a file system path, as
    // shown below.
    //
    // Note: Dart automatically looks under "lib/" within a package. When reading the
    // path below, mentally insert "/lib/" between the package name and the first sub-directory.
    //
    // Reference: https://stackoverflow.com/questions/72255508/how-to-get-the-file-path-to-an-asset-included-in-a-dart-package
    final packageUri = Uri.parse('package:static_shock_cli/templates/docs.bundle');
    final absoluteUri = await Isolate.resolvePackageUri(packageUri);

    final file = File.fromUri(absoluteUri!);
    if (!file.existsSync()) {
      throw Exception(
          "Couldn't locate the Static Shock 'new project' template in the package assets. Looked in: '${file.path}'");
    }

    // Decode the file's bytes into a Mason bundle. Return it.
    return await MasonBundle.fromUniversalBundle(file.readAsBytesSync());
  }
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

String _promptForPackageName(Logger log) {
  String? packageName;
  do {
    packageName = log.prompt("Name of documented package (e.g., static_shock)");
    if (packageName.trim().isEmpty) {
      log.err("The documented package name can't be blank.");
      continue;
    }

    // Check validity of package name and let user fix it.
    if (!PackageName.isValid(packageName)) {
      log.warn("It looks like you entered an invalid Dart package name.");
      final choice = log.chooseOne("What would you like to do?", choices: [
        if (PackageName.canFix(packageName)) //
          "autoFix",
        "newName",
        "useAnyway",
      ], display: (String option) {
        switch (option) {
          case "autoFix":
            return "Adjust name to '${PackageName.fix(packageName!)}'";
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
          packageName = PackageName.fix(packageName);
        case "newName":
          packageName = "";
      }
    }
  } while (packageName.trim().isEmpty);

  return packageName;
}

String _promptForPackageTitle(Logger log) {
  String? packageTitle;
  do {
    packageTitle = log.prompt("Human readable title of documented package (e.g., 'Static Shock')");
    if (packageTitle.trim().isEmpty) {
      log.err("The documented package title can't be blank.");
      continue;
    }
  } while (packageTitle.trim().isEmpty);

  return packageTitle;
}

String _promptForPackageDescription(Logger log) {
  return log.prompt("Description of documented package (e.g., 'A static site generator for Dart')");
}

bool _promptForPackageIsOnPub(Logger log) {
  return log.confirm("Is the documented package published to Pub?");
}

String _promptForGithubRepoUrl(Logger log) {
  return log.prompt("GitHub URL of the documented package");
}

String _promptForGithubRepoOrganization(Logger log) {
  return log.prompt("GitHub organization/user of the documented package");
}

String _promptForGithubRepoName(Logger log) {
  return log.prompt("GitHub repo name of the documented package");
}

String _promptForDiscordUrl(Logger log) {
  return log.prompt("Discord URL for the documented package");
}

String _promptForSponsorshipUrl(Logger log) {
  return log.prompt("Sponsorship URL for the documented package");
}

bool _isNullOrEmpty(dynamic subject) => subject == null || (subject as String).trim().isEmpty;
