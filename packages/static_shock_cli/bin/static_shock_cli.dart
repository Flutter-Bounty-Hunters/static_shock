import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart' hide packageVersion;
import 'package:pub_updater/pub_updater.dart';
import 'package:static_shock_cli/static_shock_cli.dart';

final _log = Logger(level: Level.verbose);

Future<void> main(List<String> arguments) async {
  // Run the desired command.
  CommandRunner("shock", "A static site generator, written in Dart.")
    ..addCommand(CreateCommand())
    ..addCommand(BuildCommand())
    ..addCommand(ServeCommand())
    ..addCommand(UpgradeCommand())
    ..addCommand(VersionCommand())
    ..run(arguments);
}

class CreateCommand extends Command with PubVersionCheck {
  @override
  final name = "create";

  @override
  final description = "Creates a new static site project at the desired location.";

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

    _log.success("Successfully created a new Static Shock project!");
  }

  Future<Map<String, dynamic>> _promptForConfiguration() async {
    final vars = <String, dynamic>{};

    vars["project_name"] = _log.prompt("Project name (e.g., 'static_shock_docs')");
    if (vars["project_name"].trim().isEmpty) {
      _log.err("Your project name can't be blank");
      exit(ExitCode.ioError.code);
    }

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
  Future<void> run() async {
    _log.info("Building a Static Shock website.");
    await buildWebsite();
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
  Future<void> run() async {
    await super.run();

    // Run a website build just in case the user has never built, or hasn't built recently.
    _log.info("Building website.");
    try {
      final result = await buildWebsite();
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
    final pubUpdater = PubUpdater();

    _log.info("Checking for newer versions of static_shock_cli...");
    final isUpToDate = await pubUpdater.isUpToDate(packageName: "static_shock_cli", currentVersion: packageVersion);
    if (isUpToDate) {
      _log.info("No updates available.\n");
      return;
    }

    final newestVersion = await pubUpdater.getLatestVersion("static_shock_cli");
    _log.info(
        "New version of ${lightYellow.wrap("static_shock_cli")} is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}");

    _log.info("Updating your static_shock_cli package to version ${lightGreen.wrap(newestVersion)}...");
    await pubUpdater.update(packageName: "static_shock_cli");
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

    _log.detail("Checking for newer versions of static_shock_cli on Pub...");
    final pubUpdater = PubUpdater();
    final isUpToDate = await pubUpdater.isUpToDate(packageName: "static_shock_cli", currentVersion: packageVersion);
    if (isUpToDate) {
      _log.info("You're up to date!\n");
      return;
    }

    final newestVersion = await pubUpdater.getLatestVersion("static_shock_cli");
    _log.info("A new version is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}\n");
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
    final pubUpdater = PubUpdater();

    _log.detail("Checking for newer versions of static_shock_cli...");
    final isUpToDate = await pubUpdater.isUpToDate(packageName: "static_shock_cli", currentVersion: packageVersion);
    if (isUpToDate) {
      _log.info("No updates available.\n");
      return;
    }

    final newestVersion = await pubUpdater.getLatestVersion("static_shock_cli");
    _log.info(
        "New version of ${lightYellow.wrap("static_shock_cli")} is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}\n");
  }
}
