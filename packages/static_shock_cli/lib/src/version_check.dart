import 'package:pub_semver/pub_semver.dart';
import 'package:pub_updater/pub_updater.dart';

import 'version.dart';

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
