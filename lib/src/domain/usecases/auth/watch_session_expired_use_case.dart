import '../../repositories/authentication_repository.dart';

final class WatchSessionExpiredUseCase {
  WatchSessionExpiredUseCase(this.repository);

  final AuthenticationRepository repository;

  Stream<void> call() => repository.watchSessionExpired();
}
