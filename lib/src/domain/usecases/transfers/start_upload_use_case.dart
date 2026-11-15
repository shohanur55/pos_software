import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/transfer_entity.dart';
import '../../entities/upload_request_entity.dart';
import '../../repositories/transfer_repository.dart';

final class StartUploadUseCase {
  StartUploadUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<TransferEntity, Failure>> call(UploadRequestEntity request) =>
      repository.startUpload(request);
}
