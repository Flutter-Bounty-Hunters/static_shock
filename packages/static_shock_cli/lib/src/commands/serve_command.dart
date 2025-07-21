import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock_cli/src/dev_server.dart';
import 'package:static_shock_cli/src/version_check.dart';
import 'package:static_shock_cli/src/website_builder.dart';

/// CLI [Command] that builds and serves a static website from a Static Shock
/// project.
///
/// This command watches for file changes within the source file set and automatically
/// rebuilds the Static Shock website. After completing a rebuild, all browsers currently
/// connected to the dev web server are instructed to refresh to get the latest updates.
class ServeCommand extends Command with PubVersionCheck {
  ServeCommand(this.log) {
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
      )
      ..addOption(
        "base-path",
        defaultsTo: null,
        help: "Base path that's expected to begin every URL path.",
      )
      ..addOption(
        "build-mode",
        defaultsTo: "dev",
        help: "The build mode to use for the website build, e.g., 'production', 'dev'.",
      );
  }

  @override
  final Logger log;

  @override
  final name = "serve";

  @override
  final description = "Serves a pre-built Static Shock site via localhost.";

  @override
  final bool takesArguments = true;

  @override
  Future<void> run() async {
    await super.run();

    final buildMode = argResults!.option("build-mode") ?? "dev";
    final appArguments = [
      if (argResults != null) ...[
        ...argResults!.rest,
        "--build-mode", buildMode, //
      ],
    ];

    // Run a website build just in case the user has never built, or hasn't built recently.
    log.info("Building website.");
    try {
      if (argResults?.rest.isNotEmpty == true) {
        log.detail("Passing extra arguments to the website builder: ${argResults!.rest.join(", ")}");
      }

      final result = await buildWebsite(appArguments: appArguments);
      if (result == null) {
        log.err("Failed to build website, therefore not starting the dev server.");
        return;
      }
    } catch (exception) {
      log.err("Failed to build website, therefore not starting the dev server.");
      return;
    }

    if (!Directory("./build").existsSync()) {
      log.err("Failed to serve website - Couldn't find the build directory for the Static Shock website.");
      return;
    }

    final port = int.tryParse(argResults!["port"]);
    if (port == null) {
      log.err("Tried to serve the website at an invalid port: '${argResults!["port"]}'");
      return;
    }
    final isPortSearchingAllowed = argResults!["find-open-port"] == true;

    final basePath = argResults!["base-path"];

    StaticShockDevServer(log, buildWebsite, appArguments: appArguments).run(
      port: port,
      findAnOpenPort: isPortSearchingAllowed,
      basePath: basePath,
    );
  }
}
