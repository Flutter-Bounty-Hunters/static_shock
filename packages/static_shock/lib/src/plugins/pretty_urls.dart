import 'dart:async';
import 'dart:io';

import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

import '../pages.dart';

class PrettyUrlsPlugin implements StaticShockPlugin {
  const PrettyUrlsPlugin();

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.transformPages(const PrettyPathPageTransformer());
  }
}

/// Prettify the destination page path by making the page an index.html within
/// a directory named after the page:
///
///    posts/hello-world.html -> posts/hello-world/index.html
class PrettyPathPageTransformer implements PageTransformer {
  const PrettyPathPageTransformer();

  @override
  FutureOr<void> transformPage(StaticShockPipelineContext context, Page page) async {
    if (page.destinationPath?.filename == "index") {
      // The file is already an index file. Nothing to prettify.
      return;
    }

    final originalPath = page.destinationPath ?? page.sourcePath;
    page
      ..url = "${originalPath.directoryPath}${originalPath.filename}${Platform.pathSeparator}"
      ..destinationPath = originalPath.copyWith(
        directoryPath: "${originalPath.directoryPath}${originalPath.filename}${Platform.pathSeparator}",
        filename: "index",
      );
  }
}
