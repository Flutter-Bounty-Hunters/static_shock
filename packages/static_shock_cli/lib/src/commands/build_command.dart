import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:static_shock_cli/src/website_builder.dart';

/// CLI [Command] that builds a Static Shock website from source files.
class BuildCommand extends Command {
  BuildCommand(this.log) {
    argParser //
      ..addFlag("production", help: "Build in production mode.")
      ..addFlag("dev", help: "Build in dev mode");
  }

  final Logger log;

  @override
  final name = "build";

  @override
  final description = "Builds a Static Shock website when run at the top-level of a Static Shock project.";

  @override
  final bool takesArguments = true;

  @override
  Future<void> run() async {
    log.info("Building a Static Shock website.");
    if (argResults?.rest.isNotEmpty == true) {
      log.detail("Passing extra arguments to the website builder: ${argResults!.rest.join(", ")}");
    }

    await buildWebsite(
      appArguments: [
        if (argResults!.flag("production")) //
          "--production",
        if (argResults!.flag("dev")) //
          "--dev",
        ...argResults!.rest,
      ],
      log: log,
    );
  }
}
