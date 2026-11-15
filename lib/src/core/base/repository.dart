import 'failure.dart';
import 'result.dart';

/// Base for every repository contract.
///
/// Implementations wrap all async work in [asyncGuard] and override
/// [mapException] to translate infrastructure errors into a [Failure].
abstract class Repository {
  const Repository();

  Future<Result<T, Failure>> asyncGuard<T>(Future<T> Function() body) async {
    try {
      return Success(await body());
    } on Failure catch (failure) {
      return Error(failure);
    } catch (error, stackTrace) {
      return Error(mapException(error, stackTrace));
    }
  }

  Failure mapException(Object error, StackTrace stackTrace) =>
      Failure(FailureKind.unknown, error.toString());
}
