import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/transfer_entity.dart';
import '../../repositories/transfer_repository.dart';

final class ResyncTransfersUseCase {
  ResyncTransfersUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<List<TransferEntity>, Failure>> call() => repository.resync();
}
