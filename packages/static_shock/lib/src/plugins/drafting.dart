import 'dart:async';

import 'package:static_shock/src/pages.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

class DraftingPlugin implements StaticShockPlugin {
  const DraftingPlugin({
    this.showDrafts = false,
  });

  final bool showDrafts;

  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.filterPages(
      DraftPageFilter(showDrafts: showDrafts),
    );
  }
}

class DraftPageFilter implements PageFilter {
  const DraftPageFilter({
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
