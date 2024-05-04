import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart' hide packageVersion;
import 'package:static_shock_cli/src/package_name_validation.dart';
import 'package:static_shock_cli/src/version_check.dart';
import 'package:static_shock_cli/static_shock_cli.dart';

final _log = Logger(level: Level.verbose);

Future<void> main(List<String> arguments) async {
  // Configure available commands that the user might run.
  final runner = CommandRunner("shock", "A static site generator, written in Dart.")
    ..addCommand(CreateCommand())
    ..addCommand(BuildCommand())
    ..addCommand(ServeCommand())
    ..addCommand(UpgradeCommand())
    ..addCommand(VersionCommand());

  // Run the desired command.
  try {
    await runner.run(arguments);
  } on UsageException catch (exception) {
    _log.err("Command failed - please check your usage.\n");
    _log.err(exception.message);
    _log.detail(exception.usage);
  }
}

class CreateCommand extends Command with PubVersionCheck {
  @override
  final name = "create";

  @override
  final description = "Creates a new static site project at the desired location.";

  @override
  bool get takesArguments => false;

  @override
  Future<void> run() async {
    await super.run();

    _log.info("Creating a new Static Shock project...");

    final workingDirectory = Directory.current;
    _log.detail("Current directory: ${workingDirectory.path}");

    final projectConfiguration = await _promptForConfiguration();

    final bundle = await _loadNewProjectTemplateBundle();
    final generator = await MasonGenerator.fromBundle(bundle);
    final target = DirectoryGeneratorTarget(Directory.current);

    await generator.generate(target, vars: projectConfiguration);

    _log.success("Successfully created a new Static Shock project!\n");

    _log.info("Running 'pub get' to initialize your project...");
    final pubGetResult = await Process.run('dart', ['pub', 'get']);
    _log.detail(pubGetResult.stdout);
    if (pubGetResult.exitCode != 0) {
      _log.err("Command 'pub get' failed. Please check your project for errors.");
      return;
    }

    _log.info("Successfully initialized your project. Now we'll run an initial build of your static site.");
    final buildResult = await Process.run('dart', ['run', 'bin/${projectConfiguration['project_name']}.dart']);
    _log.detail(buildResult.stdout);
    if (buildResult.exitCode != 0) {
      _log.err("Failed to build your static site. Please check your project for errors.");
      return;
    }

    _log.success("Congratulations, your Static Shock project is ready to go!");

    _log.info("\nTo learn how to use Static Shock, check out staticshock.io\n");
  }

  Future<Map<String, dynamic>> _promptForConfiguration() async {
    final vars = <String, dynamic>{};

    // Prompt for project package name.
    String? projectName;
    do {
      projectName = _log.prompt("Project name (e.g., 'static_shock_docs')");
      if (projectName.trim().isEmpty) {
        _log.err("Your project name can't be blank");
        continue;
      }

      // Check validity of package name and let user fix it.
      if (!PackageName.isValid(projectName)) {
        _log.warn("Your project name doesn't follow Dart package naming guidelines.");
        final choice = _log.chooseOne("What would you like to do?", choices: [
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
    vars["project_name"] = projectName;

    // Prompt for project description.
    vars["project_description"] = _log.prompt("Project description (e.g., 'Documentation for Static Shock')");

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
    final packageUri = Uri.parse('package:static_shock_cli/templates/new_project.bundle');
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

class BuildCommand extends Command {
  @override
  final name = "build";

  @override
  final description = "Builds a Static Shock website when run at the top-level of a Static Shock project.";

  @override
  final bool takesArguments = true;

  @override
  Future<void> run() async {
    _log.info("Building a Static Shock website.");
    if (argResults?.rest.isNotEmpty == true) {
      _log.detail("Passing extra arguments to the website builder: ${argResults!.rest.join(", ")}");
    }

    await buildWebsite(
      appArguments: argResults?.rest ?? [],
      log: _log,
    );
  }
}

class ServeCommand extends Command with PubVersionCheck {
  ServeCommand() {
    argParser
      ..addOption(
        "port",
        abbr: "p",
        defaultsTo: "4000",
        help: "The port used to serve the Static Shock website via localhost.",
      )
      ..addFlag(
        "find-open-port",
        defaultsTo: true,
        help: "When flag is set, Static Stock looks for open ports if the desired port isn't available.",
      );
  }

  @override
  final name = "serve";

  @override
  final description = "Serves a pre-built Static Shock site via localhost.";

  @override
  final bool takesArguments = true;

  @override
  Future<void> run() async {
    await super.run();

    // Run a website build just in case the user has never built, or hasn't built recently.
    _log.info("Building website.");
    try {
      if (argResults?.rest.isNotEmpty == true) {
        _log.detail("Passing extra arguments to the website builder: ${argResults!.rest.join(", ")}");
      }

      final result = await buildWebsite(
        appArguments: argResults?.rest ?? [],
      );
      if (result == null) {
        _log.err("Failed to build website, therefore not starting the dev server.");
        return;
      }
    } catch (exception) {
      _log.err("Failed to build website, therefore not starting the dev server.");
      return;
    }

    if (!Directory("./build").existsSync()) {
      _log.err("Failed to serve website - Couldn't find the build directory for the Static Shock website.");
      return;
    }

    final port = int.tryParse(argResults!["port"]);
    if (port == null) {
      _log.err("Tried to serve the website at an invalid port: '${argResults!["port"]}'");
      return;
    }
    final isPortSearchingAllowed = argResults!["find-open-port"] == true;

    StaticShockDevServer(_log, buildWebsite).run(
      port: port,
      findAnOpenPort: isPortSearchingAllowed,
    );
  }
}

class UpgradeCommand extends Command {
  @override
  final name = "upgrade";

  @override
  final description = "Upgrades your version of static_shock_cli to the latest from Pub.";

  @override
  Future<void> run() async {
    _log.info("Checking for newer versions of static_shock_cli...");
    final isUpToDate = await StaticShockCliVersion.isAtLeastUpToDateWithPub();
    if (isUpToDate) {
      _log.info("No updates available.\n");
      return;
    }

    final newestVersion = await StaticShockCliVersion.getLatestVersion();
    _log.info(
        "New version of ${lightYellow.wrap("static_shock_cli")} is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}");

    _log.info("Updating your static_shock_cli package to version ${lightGreen.wrap(newestVersion)}...");
    await StaticShockCliVersion.update();
    _log.info("Done upgrading static_shock_cli. Your current version is $packageVersion.");
  }
}

class VersionCommand extends Command {
  @override
  String get name => "version";

  @override
  String get description => "Tells you your current version of static_shock_cli, and checks for newer versions on Pub.";

  @override
  Future<void> run() async {
    _log.info(
        "Your current version of ${lightYellow.wrap("static_shock_cli")} is: ${lightYellow.wrap(packageVersion)}");

    final isUpToDate = await StaticShockCliVersion.isAtLeastUpToDateWithPub();
    if (isUpToDate) {
      return;
    }

    final newestVersion = await StaticShockCliVersion.getLatestVersion();
    _log.info("A new version is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}");
    _log.info("Run `shock upgrade` to upgrade to the latest version.\n");
  }
}

/// Mixin that checks Pub for a new version.
///
/// This mixin only notifies the user - it doesn't run an upgrade.
///
/// [Command]s that mixin this behavior should begin their [run] method by
/// calling the mixin's [run] method:
///
///     await super.run();
///
///
mixin PubVersionCheck on Command {
  @override
  Future<void> run() async {
    final isUpToDate = await StaticShockCliVersion.isAtLeastUpToDateWithPub();
    if (isUpToDate) {
      return;
    }

    final newestVersion = await StaticShockCliVersion.getLatestVersion();
    _log.info(
      "New version of ${lightYellow.wrap("static_shock_cli")} is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}",
    );
    _log.info("Run `shock upgrade` to upgrade to the latest version.\n");
  }
}
