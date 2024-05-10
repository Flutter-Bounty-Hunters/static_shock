import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/templates/basic_template_cli.dart';
import 'package:static_shock_cli/src/version_check.dart';

/// CLI [Command] that generates a new Static Shock project based on user preferences.
class CreateCommand extends Command with PubVersionCheck {
  CreateCommand(this.log);

  @override
  final Logger log;

  @override
  final name = "create";

  @override
  final description = "Creates a new static site project at the desired location.";

  @override
  bool get takesArguments => true;

  @override
  Future<void> run() async {
    await super.run();

    log.info("Creating a new Static Shock project...");

    final workingDirectory = Directory.current;
    log.detail("Current directory: ${workingDirectory.path}");

    final projectConfiguration = await BasicTemplateConfigurator.promptForConfiguration(log, {});

    final bundle = await _loadNewProjectTemplateBundle();
    final generator = await MasonGenerator.fromBundle(bundle);
    final target = DirectoryGeneratorTarget(Directory.current);

    await generator.generate(target, vars: projectConfiguration);

    log.success("Successfully created a new Static Shock project!\n");

    log.info("Running 'pub get' to initialize your project...");
    final pubGetResult = await Process.run('dart', ['pub', 'get']);
    log.detail(pubGetResult.stdout);
    if (pubGetResult.exitCode != 0) {
      log.err("Command 'pub get' failed. Please check your project for errors.");
      return;
    }

    log.info("Successfully initialized your project. Now we'll run an initial build of your static site.");
    final buildResult = await Process.run('dart', ['run', 'bin/${projectConfiguration['project_name']}.dart']);
    log.detail(buildResult.stdout);
    if (buildResult.exitCode != 0) {
      log.err("Failed to build your static site. Please check your project for errors.");
      return;
    }

    log.success("Congratulations, your Static Shock project is ready to go!");

    log.info("\nTo learn how to use Static Shock, check out staticshock.io\n");
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
