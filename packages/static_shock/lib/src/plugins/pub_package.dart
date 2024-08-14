import 'dart:async';

import 'package:pub_updater/pub_updater.dart';
import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/data.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';
import 'package:yaml/yaml.dart';

/// A [StaticShockPlugin] that looks up Pub information about one or more packages, and makes that
/// information available to all pages.
///
/// There are two ways to request package lookup.
///
/// First, through code, you can provide a `Set` of package names in the [_packageNames] property.
///
/// Second, through configuration, you can provide a list of package names in the top-level of the
/// data hierarchy by creating a `_data.yaml` at the root of the source directory with a structure
/// like the following:
///
///     pub:
///       packages:
///         - static_shock
///         - static_shock_cli
///
/// Typically, only one approach should be used, for clarity. However, the package names provided
/// in code are combined with the package names provided in data configuration.
class PubPackagePlugin implements StaticShockPlugin {
  const PubPackagePlugin([this._packageNames = const <String>{}]);

  @override
  final id = "io.staticshock.pubpackage";

  final Set<String> _packageNames;

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.loadData(
      _PubPackageDataLoader(_packageNames),
    );
  }
}

class _PubPackageDataLoader implements DataLoader {
  _PubPackageDataLoader(this.packageNames);

  final Set<String> packageNames;

  @override
  Future<Map<String, Object>> loadData(StaticShockPipelineContext context) async {
    final data = {
      "pub": {},
    };

    final pub = PubUpdater();
    final allPackageNames = _getAllDesiredPackageNames(context).toList(growable: false);
    final requestFutures = <Future<String>>[];
    for (final packageName in allPackageNames) {
      requestFutures.add(pub.getLatestVersion(packageName));
    }

    final packageVersions = await Future.wait(requestFutures);
    for (int i = 0; i < allPackageNames.length; i += 1) {
      data["pub"]![allPackageNames[i]] = {
        "version": packageVersions[i],
      };
    }

    return data;
  }

  Set<String> _getAllDesiredPackageNames(StaticShockPipelineContext context) {
    final allDesiredPackageNames = Set<String>.from(packageNames);

    List<String>? dataPackageNames;
    if (context.dataIndex.getAtPath(["pub", "packages"]) is List<String>) {
      dataPackageNames = context.dataIndex.getAtPath(["pub", "packages"]) as List<String>;
    } else if (context.dataIndex.getAtPath(["pub", "packages"]) is YamlList) {
      dataPackageNames = (context.dataIndex.getAtPath(["pub", "packages"]) as YamlList).toList().cast();
    }

    if (dataPackageNames != null) {
      allDesiredPackageNames.addAll(dataPackageNames);
    }

    return allDesiredPackageNames;
  }
}
