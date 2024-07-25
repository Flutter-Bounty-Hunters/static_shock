import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/project_maintenance/build_project.dart';
import 'package:static_shock_cli/src/templates/basic_template_cli.dart';

/// Walks the user through a selection of details that are required to generate
/// an empty project, and then generates the project.
Future<Directory> runEmptyTemplateWizard(Logger log) async {
  final configuration = BasicTemplateConfigurator.promptForConfiguration(log);
  final targetDirectory = BasicTemplateConfigurator.promptForOutputDirectory(log);

  await generateEmptyTemplate(
    targetDirectory,
    projectName: configuration.projectName,
    projectDescription: configuration.projectDescription,
  );

  return targetDirectory;
}

/// A CLI command that can be directly run with provided arguments, to generate
/// a new Static Shock project with a minimal collection of files.
class EmptyTemplateCommand extends Command {
  static const argProjectName = "project-name";
  static const argProjectDescription = "project-description";
  static const argAutoInitialize = "auto-initialize";

  EmptyTemplateCommand(this.log) {
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
      ..addFlag(
        argAutoInitialize,
        help:
            "True if this command should immediately run 'dart pub get' and 'shock build' after generating the project.",
        defaultsTo: true,
      );
  }

  final Logger log;

  @override
  String get name => "empty";

  @override
  String get description => "Generate a new, empty Static Shock project.";

  @override
  Future<void> run() async {
    if (!argResults!.wasParsed(argProjectName)) {
      log.err("Argument $argProjectName is required.");
      printUsage();
      return;
    }
    final projectName = argResults![argProjectName] as String;
    final projectDescription = argResults![argProjectDescription] as String;

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

    await generateEmptyTemplate(
      targetDirectory,
      projectName: projectName,
      projectDescription: projectDescription,
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

/// Generates a new Static Shock project using the "empty" template, placing
/// the files in the given [targetDirectory].
///
/// The generated files are configured with the given properties.
Future<void> generateEmptyTemplate(
  Directory targetDirectory, {
  required String projectName,
  required String projectDescription,
}) async {
  final bundle = await _loadTemplateBundle();
  final generator = await MasonGenerator.fromBundle(bundle);
  final target = DirectoryGeneratorTarget(targetDirectory);

  await generator.generate(target, vars: {
    _templateKeyProjectName: projectName,
    _templateKeyProjectDescription: projectDescription,
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
  final packageUri = Uri.parse('package:static_shock_cli/templates/empty.bundle');
  final absoluteUri = await Isolate.resolvePackageUri(packageUri);

  final file = File.fromUri(absoluteUri!);
  if (!file.existsSync()) {
    throw Exception(
        "Couldn't locate the Static Shock 'empty' template in the package assets. Looked in: '${file.path}'");
  }

  // Decode the file's bytes into a Mason bundle. Return it.
  return await MasonBundle.fromUniversalBundle(file.readAsBytesSync());
}

const _templateKeyProjectName = "project_name";
const _templateKeyProjectDescription = "project_description";
