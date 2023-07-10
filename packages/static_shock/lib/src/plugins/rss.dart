import 'dart:async';

import 'package:static_shock/src/finishers.dart';
import 'package:static_shock/src/pipeline.dart';
import 'package:static_shock/src/static_shock.dart';

class RssPlugin implements StaticShockPlugin {
  @override
  FutureOr<void> configure(StaticShockPipeline pipeline, StaticShockPipelineContext context) {
    pipeline.finish(const _RssFinisher());
  }
}

class _RssFinisher implements Finisher {
  const _RssFinisher();

  @override
  FutureOr<void> execute(StaticShockPipelineContext context) {
    // TODO:
  }
}
