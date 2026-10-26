import 'dart:async';

class MissedFollowupTimer {
  MissedFollowupTimer._();

  static final MissedFollowupTimer instance =
      MissedFollowupTimer._();

  Timer? _timer;
  Object? _owner;

  /// How often the check runs. Each run is cheap until [interval] has
  /// passed since the last successful check (only a saved time is read).
  static const Duration tickInterval = Duration(minutes: 5);

  /// Minimum gap between two missed follow-up API checks / popups.
  static const Duration interval = Duration(hours: 1);

  /// A check (API call) is running — a second one must not start.
  bool checking = false;

  /// The missed follow-up popup is on screen — don't open another.
  bool popupOpen = false;

  /// Starts one centralized timer for the entire app, owned by [owner].
  /// Replaces any running timer: when the shell is rebuilt (e.g. '/home'
  /// pushed again) the new one starts before the old one is disposed.
  void start({
    required Object owner,
    required Future<void> Function() onTick,
  }) {
    _timer?.cancel();
    _owner = owner;

    // A new shell means the route stack was rebuilt, so any old popup
    // is gone with it.
    popupOpen = false;

    // Run immediately once.
    onTick();

    // Then every [tickInterval].
    _timer = Timer.periodic(
      tickInterval,
      (_) async {
        await onTick();
      },
    );
  }

  /// Stops the centralized timer. With [owner], stops it only if that
  /// owner started it, so a disposed shell can't stop its replacement's
  /// timer. Without [owner] (logout), always stops.
  void stop({Object? owner}) {
    if (owner != null && !identical(owner, _owner)) return;

    _timer?.cancel();
    _timer = null;
    _owner = null;
  }

  /// Whether the timer is currently running.
  bool get isRunning =>
      _timer != null && _timer!.isActive;
}
