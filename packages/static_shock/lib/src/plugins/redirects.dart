import 'dart:async';

import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/plugins/links.dart';
import 'package:static_shock/src/static_shock.dart';

/// A [StaticShockPlugin] that configures HTML redirects for pages that want redirects.
///
/// To configure redirects, add the `redirectFrom` property to a page.
///
/// Example: A single old URL:
///
///     ---
///     redirectFrom: /my/old/url/page.html
///     ---
///
/// Example: Multiple old URLs:
///
///     ---
///     redirectFrom:
///       - /my/old/url/1/page.html
///       - /my/old/url/2/page.html
///     ---
@Deprecated("Use the LinksPlugin instead - this was moved over there")
class RedirectsPlugin implements StaticShockPlugin {
  const RedirectsPlugin();

  @override
  final id = "io.staticshock.redirects";

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.finish(
      RedirectsFinisher(
        basePath: context.dataIndex.getAtPath(["basePath"]) as String,
      ),
    );
  }
}
