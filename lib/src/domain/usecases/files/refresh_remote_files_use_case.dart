import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/remote_files_snapshot.dart';
import '../../repositories/remote_files_repository.dart';

final class RefreshRemoteFilesUseCase {
  RefreshRemoteFilesUseCase(this.repository);

  final RemoteFilesRepository repository;

  Future<Result<RemoteFilesSnapshot, Failure>> call() =>
      repository.refreshFiles();
}
