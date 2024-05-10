import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:mason/mason.dart' hide packageVersion;
import 'package:static_shock_cli/src/commands/build_command.dart';
import 'package:static_shock_cli/src/commands/create_command.dart';
import 'package:static_shock_cli/src/commands/serve_command.dart';
import 'package:static_shock_cli/src/commands/upgrade_command.dart';
import 'package:static_shock_cli/src/commands/version_command.dart';
import 'package:static_shock_cli/src/templates/template_command.dart';

final _log = Logger(level: Level.verbose);

Future<void> main(List<String> arguments) async {
  // Configure available commands that the user might run.
  final runner = CommandRunner("shock", "A static site generator, written in Dart.")
    ..addCommand(CreateCommand(_log))
    ..addCommand(TemplateCommand(_log))
    ..addCommand(BuildCommand(_log))
    ..addCommand(ServeCommand(_log))
    ..addCommand(UpgradeCommand(_log))
    ..addCommand(VersionCommand(_log));

  // Run the desired command.
  try {
    await runner.run(arguments);
  } on UsageException catch (exception) {
    _log.err("Command failed - please check your usage.\n");
    _log.err(exception.message);
    _log.detail(exception.usage);
  }
}
