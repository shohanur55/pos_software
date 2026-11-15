/// Outcome of an operation that can fail without throwing.
sealed class Result<T, E> {
  const Result();

  bool get isSuccess => this is Success<T, E>;

  /// Returns the success value, or `null` for an [Error].
  T? get dataOrNull => switch (this) {
    Success(:final data) => data,
    Error() => null,
  };
}

final class Success<T, E> extends Result<T, E> {
  const Success(this.data);

  final T data;
}

final class Error<T, E> extends Result<T, E> {
  const Error(this.error);

  final E error;
}
