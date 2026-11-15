import '../../core/base/failure.dart';
import '../../core/base/repository.dart';
import '../../core/base/result.dart';
import '../entities/auth_session_entity.dart';

abstract class AuthenticationRepository extends Repository {
  Future<Result<AuthSessionEntity, Failure>> login({
    required String username,
    required String password,
  });

  /// Returns the stored session when present and not expired, otherwise `null`.
  Future<Result<AuthSessionEntity?, Failure>> getValidSession();

  Future<Result<void, Failure>> logout();

  /// Opens the web portal where accounts are created. The app cannot register.
  Future<Result<void, Failure>> openRegistrationPortal();

  /// Emits whenever the server rejects the stored token.
  Stream<void> watchSessionExpired();
}
