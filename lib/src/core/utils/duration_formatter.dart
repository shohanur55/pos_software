/// Compact remaining-time units, resolved to localized text by the caller.
enum RemainingUnit { seconds, minutes, hours }

final class RemainingTime {
  const RemainingTime(this.value, this.unit);

  final int value;
  final RemainingUnit unit;

  @override
  bool operator ==(Object other) =>
      other is RemainingTime && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'RemainingTime($value ${unit.name})';
}

abstract final class DurationFormatter {
  /// Rounds [duration] up to the most readable unit: `20 s`, `3 min`, `2 h`.
  static RemainingTime remaining(Duration duration) {
    final seconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
    if (seconds < 60) return RemainingTime(seconds, RemainingUnit.seconds);
    final minutes = (seconds / 60).ceil();
    if (minutes < 60) return RemainingTime(minutes, RemainingUnit.minutes);
    return RemainingTime((minutes / 60).ceil(), RemainingUnit.hours);
  }
}
