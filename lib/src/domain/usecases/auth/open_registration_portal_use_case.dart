import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../repositories/authentication_repository.dart';

final class OpenRegistrationPortalUseCase {
  OpenRegistrationPortalUseCase(this.repository);

  final AuthenticationRepository repository;

  Future<Result<void, Failure>> call() => repository.openRegistrationPortal();
}
