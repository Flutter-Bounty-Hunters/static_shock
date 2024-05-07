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
  void transformPage(StaticShockPipelineContext context, Page page) {
    if (page.destinationPath?.filename == "index") {
      // The file is already an index file. Nothing to prettify.
      return;
    }

    final originalPath = page.destinationPath ?? page.sourcePath;
    if (originalPath == null) {
      // For some reason this page hasn't been fully configured. It's missing its destination
      // path info. Ignore it.
      return;
    }

    final destination = originalPath.copyWith(
      directoryPath: "${originalPath.directoryPath}${originalPath.filename}${Platform.pathSeparator}",
      filename: "index",
    );
    context.log.detail("Pretty Urls: Setting page (${page.title}) destination URL to: ${destination.value}");
    page
      ..url = "${originalPath.directoryPath}${originalPath.filename}${Platform.pathSeparator}"
      ..destinationPath = destination;
  }
}
