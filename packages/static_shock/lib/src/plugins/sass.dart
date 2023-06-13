import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sass/sass.dart' as sass;
import 'package:static_shock/static_shock.dart';

final _log = Logger(level: Level.verbose);

class SassPlugin implements StaticShockPlugin {
  const SassPlugin();

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.transformAssets(
      const SassAssetTransformer(
        DirectoryRelativePath("styles/"),
      ),
    );
  }
}

class SassAssetTransformer implements AssetTransformer {
  static const _extensions = ["sass", "scss"];

  const SassAssetTransformer(this._outputDirectory);

  final DirectoryRelativePath _outputDirectory;

  @override
  FutureOr<void> transformAsset(StaticShockPipelineContext context, Asset asset) async {
    if (!_extensions.contains(asset.sourcePath.extension.toLowerCase())) {
      // This isn't a Sass asset. Ignore it.
      return;
    }

    asset.destinationPath = asset.destinationPath!.copyWith(
      directoryPath: _outputDirectory.value,
      extension: "css",
    );
    asset.destinationContent = AssetContent.text(
      sass
          .compileToResult(
            context.resolveSourceFile(asset.sourcePath).path,
          )
          .css,
    );

    _log.detail("Compiled Sass to CSS for '${asset.sourcePath}' -> '${asset.destinationPath}'");
  }
}
