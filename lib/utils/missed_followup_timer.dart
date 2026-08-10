import 'dart:async';

class MissedFollowupTimer {
  MissedFollowupTimer._();

  static final MissedFollowupTimer instance =
      MissedFollowupTimer._();

  Timer? _timer;

  static const Duration interval = Duration(hours: 1);

  /// Starts one centralized timer for the entire app.
  void start({
    required Future<void> Function() onTick,
  }) {
    // Prevent multiple timers from being created.
    if (_timer != null && _timer!.isActive) {
      return;
    }

    // Run immediately once.
    onTick();

    // Then run every 1 hour.
    _timer = Timer.periodic(
      interval,
      (_) async {
        await onTick();
      },
    );
  }

  /// Stops the centralized timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Whether the timer is currently running.
  bool get isRunning =>
      _timer != null && _timer!.isActive;
}