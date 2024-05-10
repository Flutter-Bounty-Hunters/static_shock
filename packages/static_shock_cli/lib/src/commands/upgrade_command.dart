import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock_cli/src/version.dart';
import 'package:static_shock_cli/src/version_check.dart';

/// CLI [Command] that upgrades the user's version of `static_shock_cli`.
class UpgradeCommand extends Command {
  UpgradeCommand(this.log);

  final Logger log;

  @override
  final name = "upgrade";

  @override
  final description = "Upgrades your version of static_shock_cli to the latest from Pub.";

  @override
  Future<void> run() async {
    log.info("Checking for newer versions of static_shock_cli...");
    final isUpToDate = await StaticShockCliVersion.isAtLeastUpToDateWithPub();
    if (isUpToDate) {
      log.info("No updates available.\n");
      return;
    }

    final newestVersion = await StaticShockCliVersion.getLatestVersion();
    log.info(
        "New version of ${lightYellow.wrap("static_shock_cli")} is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}");

    log.info("Updating your static_shock_cli package to version ${lightGreen.wrap(newestVersion)}...");
    await StaticShockCliVersion.update();
    log.info("Done upgrading static_shock_cli. Your current version is $packageVersion.");
  }
}
