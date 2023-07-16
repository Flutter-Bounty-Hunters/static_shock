import 'dart:async';

import 'package:pub_updater/pub_updater.dart';
import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

/// A [StaticShockPlugin] that looks up Pub information about one or more packages, and makes that
/// information available to all pages.
class PubPackagePlugin implements StaticShockPlugin {
  const PubPackagePlugin(this._packageNames);

  final Set<String> _packageNames;

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.loadData(
      _PubPackageDataLoader(_packageNames),
    );
  }
}

class _PubPackageDataLoader implements DataLoader {
  _PubPackageDataLoader(this.packageNames);

  final Set<String> packageNames;

  @override
  Future<Map<String, Object>> loadData() async {
    final data = {
      "pub": {},
    };

    final pub = PubUpdater();
    for (final packageName in packageNames) {
      final version = await pub.getLatestVersion(packageName);
      data["pub"]![packageName] = {
        "version": version,
      };
    }

    return data;
  }
}
