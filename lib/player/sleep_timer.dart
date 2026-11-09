import 'dart:async';

/// Minuteur de sommeil. À l’échéance, [onElapsed] est celui du lecteur.
class SleepTimer {
  Timer? _timer;

  void arm({
    Duration? duration,
    bool atEnd = false,
    required void Function() onCleared,
    required void Function() onUntilEnd,
    required void Function(DateTime ends) onArmed,
    required void Function(DateTime ends) onTick,
    required Future<void> Function() onElapsed,
  }) {
    _timer?.cancel();
    if (duration == null && !atEnd) {
      onCleared();
      return;
    }
    if (atEnd) {
      onUntilEnd();
      return;
    }
    final ends = DateTime.now().add(duration!);
    onArmed(ends);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().isBefore(ends)) {
        onTick(ends);
        return;
      }
      _timer?.cancel();
      unawaited(onElapsed());
    });
  }

  void close() {
    _timer?.cancel();
    _timer = null;
  }
}
