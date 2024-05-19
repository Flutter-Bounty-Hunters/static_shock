import 'package:mason_logger/mason_logger.dart';

/// A timer that prints timing info for a series of checkpoints.
///
/// Consider Static Shock, which runs a series of operations, including:
///  - load file data
///  - load external data
///  - transform pages
///  - render pages
///  - transform assets
///  - write pages and assets to file system
///
/// A checkpoint timer helps to track the time for each step, independently,
/// and print those times to the given [Logger].
class CheckpointTimer {
  CheckpointTimer(
    this._log, [
    this._messageWriter = _defaultWriteCheckpointTimingMessage,
  ]);

  final Logger _log;
  final CheckpointMessageWriter _messageWriter;

  Stopwatch? _stopwatch;
  int _lastCheckpointInMillis = 0;

  void start() {
    if (_stopwatch != null) {
      // We're already running the timer.
      return;
    }

    _stopwatch = Stopwatch()..start();
    _lastCheckpointInMillis = 0;
  }

  void checkpoint(String name, String description) {
    if (_stopwatch == null) {
      // No timer is active.
      _log.warn("Tried to print a checkpoint time for '$name', but the CheckpointTimer isn't running.");
      return;
    }

    final stepDuration = Duration(milliseconds: _stopwatch!.elapsedMilliseconds - _lastCheckpointInMillis);
    _messageWriter(_log, stepDuration, name, description);
    _lastCheckpointInMillis = _stopwatch!.elapsedMilliseconds;
  }

  void totalTime(String description) {
    if (_stopwatch == null) {
      // No timer is active.
      _log.warn("Tried to print a total time for '$description', but the CheckpointTimer isn't running.");
      return;
    }

    final totalTime = Duration(milliseconds: _stopwatch!.elapsedMilliseconds);
    _messageWriter(_log, totalTime, description);
  }

  void stop() {
    if (_stopwatch == null) {
      return;
    }

    _stopwatch!.stop();
  }
}

typedef CheckpointMessageWriter = void Function(
  Logger log,
  Duration duration,
  String name, [
  String? description,
]);

void _defaultWriteCheckpointTimingMessage(
  Logger log,
  Duration duration,
  String name, [
  String? description,
]) {
  final seconds = (duration.inMilliseconds / 1000).toStringAsFixed(3);
  log.detail("Timing: ${seconds}s - $name${description != null ? " - $description" : ""}");
}
