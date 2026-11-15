import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../repositories/transfer_repository.dart';

final class ClearFinishedTransfersUseCase {
  ClearFinishedTransfersUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<void, Failure>> call() => repository.clearFinished();
}
