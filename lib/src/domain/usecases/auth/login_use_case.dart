import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/auth_session_entity.dart';
import '../../repositories/authentication_repository.dart';

final class LoginUseCase {
  LoginUseCase(this.repository);

  final AuthenticationRepository repository;

  Future<Result<AuthSessionEntity, Failure>> call({
    required String username,
    required String password,
  }) {
    return repository.login(username: username.trim(), password: password);
  }
}
