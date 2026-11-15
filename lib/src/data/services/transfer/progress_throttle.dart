/// Lets at most one progress event per [interval] through for each key.
class ProgressThrottle {
  ProgressThrottle(this.interval, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Duration interval;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastEmitted = {};

  /// Final progress (1.0) is always let through so bars never stop short.
  bool shouldEmit(String key, double progress) {
    final now = _clock();
    final last = _lastEmitted[key];
    if (progress >= 1 || last == null || now.difference(last) >= interval) {
      _lastEmitted[key] = now;
      return true;
    }
    return false;
  }

  void forget(String key) => _lastEmitted.remove(key);
}
