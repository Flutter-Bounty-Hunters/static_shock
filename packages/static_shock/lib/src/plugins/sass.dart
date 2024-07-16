import 'dart:async';

import 'package:mason_logger/mason_logger.dart';
import 'package:sass/sass.dart' as sass;
import 'package:static_shock/static_shock.dart';

/// A [StaticShockPlugin] that loads and compiles Sass to CSS.
///
/// The plugin loads all source files with a `sass` or `scss` extension.
///
/// Remote Sass files can be loaded using the standard remote file loading APIs
/// in `StaticShock`. Any remotely loaded file with an extension of `sass` or
/// `scss` will be compiled to CSS.
class SassPlugin implements StaticShockPlugin {
  const SassPlugin();

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    // We assemble our own Sass importer that we call SassEnvironment where we
    // collect all the available Sass files so they can reference each other.
    //
    // The Sass package supports automatic file resolution for Sass imports, but
    // because we support remote Sass files, we need to collect all the Sass content
    // and handle importing ourselves.
    final sassEnvironment = SassEnvironment(context.log);

    pipeline
      // Load all local Sass files into artifacts.
      ..pick(ExtensionPicker("sass"))
      ..pick(ExtensionPicker("scss"))
      // Index all the loaded Sass files so they can import each other.
      ..transformAssets(
        SassIndexTransformer(context.log, sassEnvironment),
      )
      // Compile all Sass files to CSS.
      ..transformAssets(
        SassAssetTransformer(context.log, sassEnvironment),
      );
  }
}

/// An [AssetTransformer] that processes every loaded Sass asset and adds them to
/// a [SassEnvironment] so that each Sass file can import the others.
class SassIndexTransformer implements AssetTransformer {
  const SassIndexTransformer(this._log, this._environment);

  final Logger _log;
  final SassEnvironment _environment;

  @override
  void transformAsset(StaticShockPipelineContext context, Asset asset) {
    if (asset.sourcePath == null) {
      // We don't know the source name, so we don't know if this is a Sass
      // file. Ignore it.
      // TODO: Re-work API so that Sass without a source file can still be applied.
      return;
    }

    if (!_extensions.contains(asset.sourcePath!.extension.toLowerCase())) {
      // This isn't a Sass asset. Ignore it.
      return;
    }

    if (asset.sourceContent?.text == null) {
      // There's no content for this Sass file.
      return;
    }

    _log.detail("Adding Sass content to cache: ${asset.sourcePath}");
    _environment.cache["${asset.destinationPath!.filename}.${asset.destinationPath!.extension}"] =
        asset.sourceContent!.text!;
  }
}

/// An [AssetTransformer] that compiles loaded Sass assets to CSS assets.
///
/// This transformer requires a [SassEnvironment], which is used to locate
/// Sass files that are imported by other Sass files.
class SassAssetTransformer implements AssetTransformer {
  const SassAssetTransformer(this._log, this._sassEnvironment);

  final Logger _log;
  final SassEnvironment _sassEnvironment;

  @override
  FutureOr<void> transformAsset(StaticShockPipelineContext context, Asset asset) async {
    if (asset.sourcePath == null) {
      // We don't know the source name, so we don't know if this is a Sass
      // file. Ignore it.
      // TODO: Re-work API so that Sass without a source file can still be applied.
      return;
    }

    if (!_extensions.contains(asset.sourcePath!.extension.toLowerCase())) {
      // This isn't a Sass asset. Ignore it.
      return;
    }

    if (asset.sourceContent?.text == null) {
      // There's no content for this Sass file. Ignore it.
      return;
    }

    asset.destinationPath = asset.destinationPath!.copyWith(
      extension: "css",
    );

    asset.destinationContent = AssetContent.text(
      sass
          .compileStringToResult(
            asset.sourceContent!.text!,
            importer: _sassEnvironment,
          )
          .css,
    );

    _log.detail("Compiled Sass to CSS for '${asset.sourcePath}' -> '${asset.destinationPath}'");
  }
}

/// The environment for Sass compilation, including support for locating Sass files
/// that are imported by other Sass files.
class SassEnvironment extends sass.Importer {
  SassEnvironment(this._log);

  final Logger _log;

  /// Cache of Sass files mapping from their file path to their Sass content.
  final cache = <String, String>{};

  @override
  Uri? canonicalize(Uri url) {
    // This method adds a "shock" scheme to the Sass `Uri` because the Sass
    // package complains if we return the same `url` that it provides us.
    //
    // It's not clear to me what this "canonicalize" process is trying to achieve.
    // There might be bugs here for any number of situations that we haven't considered.
    if (url.scheme == "shock") {
      return url;
    }

    return Uri(scheme: "shock", path: url.path);
  }

  @override
  sass.ImporterResult? load(Uri url) {
    final content = cache[url.path] ?? cache["${url.path}.scss"] ?? cache["${url.path}.sass"];
    if (content == null || content.isEmpty) {
      _log.warn("Tried to import a Sass file that isn't available in the SassEnvironment: ${url.path}");
      _log.warn("Available Sass files in environment:");
      for (final path in cache.keys) {
        _log.warn(" - $path");
      }
      return null;
    }

    return sass.ImporterResult(content, syntax: sass.Syntax.scss);
  }
}

const _extensions = ["sass", "scss"];
