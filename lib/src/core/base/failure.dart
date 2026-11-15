/// Categories the presentation layer turns into localized messages.
enum FailureKind {
  network,
  unauthorized,
  invalidCredentials,
  notFound,
  server,
  fileTooLarge,
  invalidFile,
  storage,
  invalidResponse,
  resumeFailed,
  alreadyInProgress,
  cannotOpen,
  notAllowed,
  unknown,
}

/// A recoverable error crossing layer boundaries.
///
/// [message] is technical detail for logs and must never be shown to users.
final class Failure implements Exception {
  const Failure(this.kind, [this.message]);

  final FailureKind kind;
  final String? message;

  @override
  String toString() =>
      'Failure(${kind.name}${message == null ? '' : ': $message'})';

  @override
  bool operator ==(Object other) =>
      other is Failure && other.kind == kind && other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);
}
