import '../../entities/transfer_notification_tap_entity.dart';
import '../../repositories/transfer_repository.dart';

final class WatchTransferNotificationTapsUseCase {
  WatchTransferNotificationTapsUseCase(this.repository);

  final TransferRepository repository;

  Stream<TransferNotificationTapEntity> call() =>
      repository.watchNotificationTaps();
}
