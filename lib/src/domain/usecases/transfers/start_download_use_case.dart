import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/remote_file_entity.dart';
import '../../entities/transfer_entity.dart';
import '../../repositories/transfer_repository.dart';

final class StartDownloadUseCase {
  StartDownloadUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<TransferEntity, Failure>> call(RemoteFileEntity file) =>
      repository.startDownload(file);
}
