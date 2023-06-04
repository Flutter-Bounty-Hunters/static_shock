import 'dart:async';
import 'dart:typed_data';

import 'files.dart';
import 'pipeline.dart';

abstract class AssetTransformer {
  FutureOr<void> transformAsset(StaticShockPipelineContext context, Asset asset);
}

class Asset {
  Asset(
    this.sourcePath,
    this.sourceContent, {
    this.destinationPath,
    this.destinationContent,
  });

  final FileRelativePath sourcePath;
  final AssetContent sourceContent;

  FileRelativePath? destinationPath;
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
