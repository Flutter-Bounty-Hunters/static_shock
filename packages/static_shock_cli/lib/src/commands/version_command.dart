import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:static_shock_cli/src/version.dart';
import 'package:static_shock_cli/src/version_check.dart';

/// CLI [Command] that tells the user which version of [static_shock_cli] he's
/// currently using.
class VersionCommand extends Command {
  VersionCommand(this.log);

  final Logger log;

  @override
  String get name => "version";

  @override
  String get description => "Tells you your current version of static_shock_cli, and checks for newer versions on Pub.";

  @override
  Future<void> run() async {
    log.info("Your current version of ${lightYellow.wrap("static_shock_cli")} is: ${lightYellow.wrap(packageVersion)}");

    final isUpToDate = await StaticShockCliVersion.isAtLeastUpToDateWithPub();
    if (isUpToDate) {
      return;
    }

    final newestVersion = await StaticShockCliVersion.getLatestVersion();
    log.info("A new version is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}");
    log.info("Run `shock upgrade` to upgrade to the latest version.\n");
  }
}
