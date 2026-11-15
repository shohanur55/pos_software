import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/auth_session_entity.dart';
import '../../repositories/authentication_repository.dart';

final class GetSessionUseCase {
  GetSessionUseCase(this.repository);

  final AuthenticationRepository repository;

  Future<Result<AuthSessionEntity?, Failure>> call() =>
      repository.getValidSession();
}
