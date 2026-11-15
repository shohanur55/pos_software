import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../repositories/transfer_repository.dart';

final class CancelTransferUseCase {
  CancelTransferUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<void, Failure>> call(String id) => repository.cancel(id);
}
