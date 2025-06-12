import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pub_updater/pub_updater.dart';

import 'version.dart';

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
  Logger get log;

  @override
  Future<void> run() async {
    try {
      final isUpToDate = await StaticShockCliVersion.isAtLeastUpToDateWithPub();
      if (isUpToDate) {
        return;
      }
    } on SocketException {
      log.warn('Unable to reach pub.dev. Skipping version check.');
      return;
    }

    final newestVersion = await StaticShockCliVersion.getLatestVersion();
    log.info(
      "New version of ${lightYellow.wrap("static_shock_cli")} is available: ${lightRed.wrap(packageVersion)} -> ${lightGreen.wrap(newestVersion)}",
    );
    log.info("Run `shock upgrade` to upgrade to the latest version.\n");
  }
}

/// Tools for managing the package version for `static_shock_cli`.
class StaticShockCliVersion {
  /// Returns `true` if the version of `static_shock_cli` that's running right now
  /// is at least as recent as the latest version on Pub.
  static Future<bool> isAtLeastUpToDateWithPub() async {
    final pubUpdater = PubUpdater();
    final latestVersion = await pubUpdater.getLatestVersion("static_shock_cli");

    final currentVersionDesc = Version.parse(packageVersion);
    final latestVersionDesc = Version.parse(latestVersion);

    if (!latestVersionDesc.isPreRelease && currentVersionDesc.isPreRelease) {
      // If the current version is a pre-release but the latest isn't,
      // skip the version checking.
      return true;
    }

    return currentVersionDesc >= latestVersionDesc;
  }

  /// Returns the latest Pub version of the `static_shock_cli` package.
  static Future<String> getLatestVersion() {
    return PubUpdater().getLatestVersion("static_shock_cli");
  }

  /// Updates the version of `static_shock_cli` running on this computer to
  /// the latest version from Pub.
  static Future<void> update() {
    return PubUpdater().update(packageName: "static_shock_cli");
  }

  const StaticShockCliVersion._();
}
