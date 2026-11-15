import '../../entities/transfer_entity.dart';
import '../../repositories/transfer_repository.dart';

/// Live transfer changes: updated records and ids of removed ones.
final class WatchTransfersUseCase {
  WatchTransfersUseCase(this.repository);

  final TransferRepository repository;

  Stream<TransferEntity> call() => repository.watchTransfers();

  Stream<String> removed() => repository.watchRemovedTransfers();
}
