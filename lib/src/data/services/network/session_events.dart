import 'dart:async';

/// Broadcasts that the server rejected the current token.
class SessionEvents {
  final StreamController<void> _expired = StreamController<void>.broadcast();

  Stream<void> get expired => _expired.stream;

  void notifyExpired() => _expired.add(null);
}
