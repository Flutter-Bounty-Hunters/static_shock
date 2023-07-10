import 'dart:async';

import 'package:static_shock/src/pipeline.dart';

/// An action that runs after all pages are loaded, indexed, and written to their
/// destination.
abstract class Finisher {
  FutureOr<void> execute(StaticShockPipelineContext context);
}
