import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/package_name_validation.dart';
import 'package:static_shock_cli/src/project_maintenance/build_project.dart';
import 'package:static_shock_cli/src/templates/basic_template_cli.dart';

/// Walks the user through a selection of details that are required to generate
/// a multi-page documentation project, and then generates the project.
Future<Directory> runMultiPageDocsTemplateWizard(Logger log) async {
  final basicProjectConfiguration = BasicTemplateConfigurator.promptForConfiguration(log);

  final docsConfiguration = _promptForMultiPageDocsConfiguration(log);

  final targetDirectory = BasicTemplateConfigurator.promptForOutputDirectory(log);

  await generateMultiPageDocumentationProject(
    targetDirectory,
    projectName: basicProjectConfiguration.projectName,
    projectDescription: basicProjectConfiguration.projectDescription,
    packageName: docsConfiguration.packageName,
    packageTitle: docsConfiguration.packageTitle,
    packageDescription: docsConfiguration.packageDescription,
    isPackageOnPub: docsConfiguration.isPackageOnPub,
    githubRepoOrganization: docsConfiguration.githubRepoOrganization,
    githubRepoName: docsConfiguration.githubRepoName,
    discordUrl: docsConfiguration.discordUrl,
    sponsorshipUrl: docsConfiguration.sponsorshipUrl,
  );

  return targetDirectory;
}

MultiPageDocsConfiguration _promptForMultiPageDocsConfiguration(Logger log) {
  // Package and Pub prompts.
  log.info("Let's collect some info about the package that you're documenting...\n");
  final packageName = _promptForPackageName(log);
  final packageTitle = _promptForPackageTitle(log);
  final packageDescription = _promptForPackageDescription(log);
  final isPackageOnPub = _promptForPackageIsOnPub(log);
  log.info("");

  // GitHub prompts.
  log.info("Let's collect some info about the package's GitHub presence...\n");
  final isOnGitHub = _promptForPackageIsOnGitHub(log);
  String? githubOrganization;
  String? githubRepoName;
  if (isOnGitHub) {
    githubOrganization = _promptForGithubRepoOrganization(log);
    if (githubOrganization.isEmpty) {
      githubOrganization = null;
    }

    if (githubOrganization != null) {
      githubRepoName = _promptForGithubRepoName(log);
    }
  }
  log.info("");

  // Social media prompts.
  log.info("Let's collect some info about the package's social media presence...\n");
  final discordUrl = _promptForDiscordUrl(log);
  final sponsorshipUrl = _promptForSponsorshipUrl(log);
  log.info("");

  return MultiPageDocsConfiguration(
    packageName: packageName,
    packageTitle: packageTitle,
    packageDescription: packageDescription,
    isPackageOnPub: isPackageOnPub,
    githubRepoOrganization: githubOrganization,
    githubRepoName: githubRepoName,
    discordUrl: discordUrl,
    sponsorshipUrl: sponsorshipUrl,
  );
}

class MultiPageDocsConfiguration {
  const MultiPageDocsConfiguration({
    required this.packageName,
    required this.packageTitle,
    required this.packageDescription,
    required this.isPackageOnPub,
    this.githubRepoOrganization,
    this.githubRepoName,
    this.discordUrl,
    this.sponsorshipUrl,
  });

  final String packageName;
  final String packageTitle;
  final String packageDescription;
  final bool isPackageOnPub;
  final String? githubRepoOrganization;
  final String? githubRepoName;
  final String? discordUrl;
  final String? sponsorshipUrl;
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

bool _promptForPackageIsOnGitHub(Logger log) {
  return log.confirm("Is this package hosted on GitHub?");
}

String _promptForGithubRepoOrganization(Logger log) {
  return log.prompt("GitHub organization/user of the documented package:");
}

String? _promptForGithubRepoName(Logger log) {
  String repoName = "";
  do {
    repoName = log.prompt("GitHub repo name of the documented package:");

    if (repoName.isEmpty) {
      log.warn("To link to GitHub, you must provide a repo name.");
      final stillWantsGitHub = log.confirm("Do you still want to link to GitHub?", defaultValue: true);
      if (!stillWantsGitHub) {
        // User bailed on GitHub linking.
        return null;
      }
    }
  } while (repoName.isEmpty);

  return repoName;
}

String _promptForDiscordUrl(Logger log) {
  return log.prompt("Discord URL for the documented package:");
}

String _promptForSponsorshipUrl(Logger log) {
  return log.prompt("Sponsorship URL for the documented package:");
}

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
///   --github-organization=superlistapp \
///   --github-repo-name=super_editor \
///   --discord=https://discord.gg/8hna2VD32s \
///   --sponsorship=https://flutterbountyhunters.com
/// ```
class DocsMultiPageTemplateCommand extends Command {
  static const argProjectName = "project-name";
  static const argProjectDescription = "project-description";
  static const argPackageName = "package-name";
  static const argPackageTitle = "package-title";
  static const argPackageDescription = "package-description";
  static const argPackageIsOnPub = "package-is-on-pub";
  static const argGithubRepoOrganization = "github-organization";
  static const argGithubRepoName = "github-repo-name";
  static const argDiscord = "discord";
  static const argSponsorship = "sponsorship";
  static const argAutoInitialize = "auto-initialize";

  DocsMultiPageTemplateCommand(this.log) {
    argParser
      ..addOption(
        argProjectName,
        help: "The name of the new Static Shock project - it should be a valid Dart package name.",
        mandatory: true,
      )
      ..addOption(
        argProjectDescription,
        help: "The description of the new Static Shock project - will be added to the project's pubspec file.",
        defaultsTo: "",
      )
      ..addOption(
        argPackageName,
        help: "The name of the package that this website will document (e.g., super_editor).",
        mandatory: true,
      )
      ..addOption(
        argPackageTitle,
        help: "Human readable title of the package that this website will document (e.g., Super Editor).",
        mandatory: true,
      )
      ..addOption(
        argPackageDescription,
        help:
            "Human readable description of the package that this website will document (e.g., A document editing toolkit for Flutter).",
        mandatory: true,
      )
      ..addFlag(
        argPackageIsOnPub,
        help: "True if the documented package is published to Pub, or false otherwise.",
        defaultsTo: false,
      )
      ..addOption(
        argGithubRepoOrganization,
        help: "The organization/user to which the documented package belongs on GitHub.",
        defaultsTo: null,
      )
      ..addOption(
        argGithubRepoName,
        help: "The name of the GitHub repository that contains the documented package.",
        defaultsTo: null,
      )
      ..addOption(
        argDiscord,
        help: "The URL to the Discord channel associated with the documented package.",
        defaultsTo: null,
      )
      ..addOption(
        argSponsorship,
        help: "The URL to a website where users can financially support your work.",
        defaultsTo: null,
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
  String get name => "docs-multi-page";

  @override
  String get description => "Generate the starting point for a multi-page documentation website with Static Shock.";

  @override
  Future<void> run() async {
    if (!argResults!.wasParsed(argProjectName)) {
      log.err("Argument $argProjectName is required.");
      printUsage();
      return;
    }
    if (!argResults!.wasParsed(argPackageName)) {
      log.err("Argument $argPackageName is required.");
      printUsage();
      return;
    }
    if (!argResults!.wasParsed(argPackageTitle)) {
      log.err("Argument $argPackageTitle is required.");
      printUsage();
      return;
    }
    if (!argResults!.wasParsed(argPackageDescription)) {
      log.err("Argument $argPackageDescription is required.");
      printUsage();
      return;
    }

    final projectName = argResults![argProjectName] as String;
    final projectDescription = argResults![argProjectDescription] as String;

    final packageName = argResults![argPackageName] as String;
    final packageTitle = argResults![argPackageTitle] as String;
    final packageDescription = argResults![argPackageDescription] as String;

    final targetPath = argResults!.rest.lastOrNull;
    final targetDirectory = targetPath != null ? Directory(targetPath) : Directory.current;
    if (!targetDirectory.existsSync()) {
      try {
        targetDirectory.createSync(recursive: true);
      } catch (exception) {
        log.err("Failed to create project directory: ${targetDirectory.absolute}");
        log.err("$exception");
        return;
      }
    }

    await generateMultiPageDocumentationProject(
      targetDirectory,
      projectName: projectName,
      projectDescription: projectDescription,
      packageName: packageName,
      packageTitle: packageTitle,
      packageDescription: packageDescription,
      isPackageOnPub: argResults![argPackageIsOnPub] as bool,
      githubRepoOrganization: argResults![argGithubRepoOrganization] as String?,
      githubRepoName: argResults![argGithubRepoName] as String?,
      discordUrl: argResults![argDiscord] as String?,
      sponsorshipUrl: argResults![argSponsorship] as String?,
    );

    log.success("Successfully created a new Static Shock project!\n");

    if (argResults![argAutoInitialize]) {
      // Run "shock build".
      await Project.build(log: log, workingDirectory: targetDirectory);

      // Run "pub get".
      await Project.pubGet(log: log, workingDirectory: targetDirectory);
    }

    log.success("Congratulations, your Static Shock project is ready to go!");

    log.info("\nTo learn how to use Static Shock, check out staticshock.io\n");
  }
}

/// Generates a new Static Shock project using the "multi-page docs" template, placing
/// the files in the given [targetDirectory].
///
/// The generated files are configured with the given properties.
Future<void> generateMultiPageDocumentationProject(
  Directory targetDirectory, {
  required String projectName,
  required String projectDescription,
  required String packageName,
  required String packageTitle,
  required String packageDescription,
  required bool isPackageOnPub,
  String? githubRepoOrganization,
  String? githubRepoName,
  String? discordUrl,
  String? sponsorshipUrl,
}) async {
  final bundle = await _loadTemplateBundle();
  final generator = await MasonGenerator.fromBundle(bundle);
  final target = DirectoryGeneratorTarget(targetDirectory);

  await generator.generate(target, vars: {
    _templateKeyProjectName: projectName,
    _templateKeyProjectDescription: projectDescription,
    _templateKeyPackageName: packageName,
    _templateKeyPackageTitle: packageTitle,
    _templateKeyPackageDescription: packageDescription,
    _templateKeyIsPackageOnPub: isPackageOnPub,
    _templateKeyGitHubRepoOrganization: githubRepoOrganization,
    _templateKeyGitHubRepoName: githubRepoName,
    _templateKeyDiscordUrl: discordUrl,
    _templateKeySponsorshipUrl: sponsorshipUrl,
  });
}

Future<MasonBundle> _loadTemplateBundle() async {
  // We expect to run as a globally activated Dart package. To access assets bundled
  // with our package, we need to resolve a package path to a file system path, as
  // shown below.
  //
  // Note: Dart automatically looks under "lib/" within a package. When reading the
  // path below, mentally insert "/lib/" between the package name and the first sub-directory.
  //
  // Reference: https://stackoverflow.com/questions/72255508/how-to-get-the-file-path-to-an-asset-included-in-a-dart-package
  final packageUri = Uri.parse('package:static_shock_cli/templates/docs_multi_page.bundle');
  final absoluteUri = await Isolate.resolvePackageUri(packageUri);

  final file = File.fromUri(absoluteUri!);
  if (!file.existsSync()) {
    throw Exception(
        "Couldn't locate the Static Shock 'docs_multi_page' template in the package assets. Looked in: '${file.path}'");
  }

  // Decode the file's bytes into a Mason bundle. Return it.
  return await MasonBundle.fromUniversalBundle(file.readAsBytesSync());
}

const _templateKeyProjectName = "project_name";
const _templateKeyProjectDescription = "project_description";
const _templateKeyPackageName = "package_name";
const _templateKeyPackageTitle = "package_title";
const _templateKeyPackageDescription = "package_description";
const _templateKeyIsPackageOnPub = "package_is_on_pub";
const _templateKeyGitHubRepoOrganization = "github_organization";
const _templateKeyGitHubRepoName = "github_repo_name";
const _templateKeyDiscordUrl = "discord_url";
const _templateKeySponsorshipUrl = "sponsorship_url";
