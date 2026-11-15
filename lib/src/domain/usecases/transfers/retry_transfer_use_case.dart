import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/transfer_entity.dart';
import '../../repositories/transfer_repository.dart';

final class RetryTransferUseCase {
  RetryTransferUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<TransferEntity, Failure>> call(String id) =>
      repository.retry(id);
}
