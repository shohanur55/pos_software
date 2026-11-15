import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../repositories/authentication_repository.dart';
import '../../repositories/remote_files_repository.dart';
import '../../repositories/transfer_repository.dart';

/// Clears the session. A deliberate logout also cancels running transfers and
/// wipes the local history and file cache, so the next account never sees
/// them. After a session expiry everything is kept, so transfers can be
/// retried once the same user logs back in.
final class LogoutUseCase {
  LogoutUseCase(this.repository, this.transferRepository, this.filesRepository);

  final AuthenticationRepository repository;
  final TransferRepository transferRepository;
  final RemoteFilesRepository filesRepository;

  Future<Result<void, Failure>> call({bool cancelTransfers = true}) async {
    if (cancelTransfers) {
      await transferRepository.cancelAllActive();
      await transferRepository.clearFinished();
      await filesRepository.clearCache();
    }
    return repository.logout();
  }
}
