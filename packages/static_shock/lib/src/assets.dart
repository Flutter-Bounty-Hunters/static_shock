import 'dart:async';
import 'dart:typed_data';

import 'package:static_shock/src/files.dart';
import 'package:static_shock/src/pipeline.dart';

/// Loads some number of assets, possibly by loading them from remote sources,
/// or by generating them locally.
///
/// Asset loading runs before asset transformation.
abstract class AssetLoader {
  FutureOr<void> loadAssets(StaticShockPipelineContext context);
}

abstract class AssetTransformer {
  FutureOr<void> transformAsset(StaticShockPipelineContext context, Asset asset);
}

class Asset {
  Asset({
    this.sourcePath,
    this.sourceContent,
    this.destinationPath,
    this.destinationContent,
  });

  /// The relative file path of the source asset, within the website source files, or `null`
  /// if this asset is generated at runtime or comes from a non-file location.
  final FileRelativePath? sourcePath;

  /// The content of the source file, or `null` if this asset is generated at runtime, or comes
  /// from a non-file location.
  final AssetContent? sourceContent;

  /// The relative file path where this asset will be written within the website build directory,
  /// or `null` if the pipeline hasn't chosen a destination yet.
  FileRelativePath? destinationPath;

  /// The content of the final asset, as written to the website build directory, or `null` if
  /// the pipeline hasn't chosen the final content yet.
  AssetContent? destinationContent;

  String describe() {
    return '''Asset:
Source: "$sourcePath"
Destination: "$destinationPath"

Source Content:
$sourceContent

Destination Content:
$destinationContent
''';
  }

  @override
  String toString() => "[Asset] - Source: $sourcePath, Destination: $destinationPath";

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Asset && runtimeType == other.runtimeType && sourcePath == other.sourcePath;

  @override
  int get hashCode => sourcePath.hashCode;
}

class AssetContent {
  AssetContent.text(this._text);

  AssetContent.binary(this._binary);

  String? get text => _text;
  String? _text;
  set text(String? text) {
    _text = text;
    _binary = null;
  }

  Uint8List? get binary => _binary;
  Uint8List? _binary;
  set binary(Uint8List? binary) {
    _binary = binary;
    _text = null;
  }

  bool get isText => text != null;

  bool get isBinary => binary != null;

  @override
  String toString() => isText ? text! : "$binary";
}
