import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../repositories/remote_files_repository.dart';

final class DeleteRemoteFileUseCase {
  DeleteRemoteFileUseCase(this.repository);

  final RemoteFilesRepository repository;

  Future<Result<void, Failure>> call(String name) =>
      repository.deleteFile(name);
}
