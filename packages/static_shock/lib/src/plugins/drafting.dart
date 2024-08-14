import 'dart:async';

import 'package:static_shock/src/cache.dart';
import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

/// Plugin that helps with drafting content.
///
/// Drafting is the process of creating content over time. For example, an early version of an article
/// might be written and committed, but that article shouldn't appear in the built website. With this
/// plugin, that article can be marked as a draft, and it will be ignored in the website build.
///
/// To mark a [Page] as being a draft, set `draft` to `true` in the page configuration, e.g.,
///
/// ```
/// ---
/// title: My Article (WIP)
/// draft: true
/// ---
/// ```
///
/// To preview draft content, build the website with [showDrafts] set to `true`.
class DraftingPlugin implements StaticShockPlugin {
  const DraftingPlugin({
    this.showDrafts = false,
  });

  @override
  final id = "io.staticshock.drafting";

  final bool showDrafts;

  @override
  FutureOr<void> configure(
    StaticShockPipeline pipeline,
    StaticShockPipelineContext context,
    StaticShockCache pluginCache,
  ) {
    pipeline.filterPages(
      _DraftPageFilter(showDrafts: showDrafts),
    );
  }
}

class _DraftPageFilter implements PageFilter {
  const _DraftPageFilter({
    this.showDrafts = false,
  });

  final bool showDrafts;

  @override
  bool shouldInclude(StaticShockPipelineContext context, Page page) {
    if (showDrafts) {
      return true;
    }

    return page.data['draft'] != true;
  }
}
