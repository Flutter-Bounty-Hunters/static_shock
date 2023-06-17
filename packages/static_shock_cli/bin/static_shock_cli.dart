import 'dart:io';
import 'dart:isolate';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

final _log = Logger(level: Level.verbose);

void main(List<String> arguments) {
  CommandRunner("shock", "A static site generator, written in Dart.")
    ..addCommand(CreateCommand())
    // ..addCommand(BuildCommand())
    ..addCommand(ServeCommand())
    // ..addCommand(ValidateCommand())
    ..run(arguments);
}

class CreateCommand extends Command {
  @override
  final name = "create";

  @override
  final description = "Creates a new static site project at the desired location.";

  @override
  Future<void> run() async {
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

// class BuildCommand extends Command {
//   @override
//   final name = "build";
//
//   @override
//   final description = "Builds a deployable static website by copying and transforming all source files.";
//
//   @override
//   Future<void> run() async {
//     // TODO: run a shell command that runs the main dart file in the current directory
//   }
// }

class ServeCommand extends Command {
  @override
  final name = "serve";

  @override
  final description = "Serves a pre-built Static Shock site via localhost.";

  @override
  Future<void> run() async {
    print("Serving a static site!");

    var handler = const Pipeline() //
        .addMiddleware(logRequests()) //
        .addHandler(
          createStaticHandler(
            'build',
            defaultDocument: 'index.html',
          ),
        );

    var server = await shelf_io.serve(handler, 'localhost', 4000);

    // Enable content compression
    server.autoCompress = true;

    print('Serving at http://${server.address.host}:${server.port}');
  }
}

// class ValidateCommand extends Command {
//   @override
//   final name = "validate";
//
//   @override
//   final description = "Inspects the current working directory and validates its structure as a Static Shock project.";
//
//   @override
//   Future<void> run() async {
//     // TODO:
//     print("Validating Static Shock project!");
//   }
// }
