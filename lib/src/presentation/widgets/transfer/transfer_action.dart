import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/entities/transfer_status.dart';

enum TransferAction { pause, resume, cancel, retry, open, remove }

extension AvailableTransferActions on TransferEntity {
  /// Actions that make sense for the current state, most important first.
  List<TransferAction> get availableActions => switch (status) {
    TransferStatus.queued ||
    TransferStatus.running ||
    TransferStatus.waitingToRetry => const [
      TransferAction.pause,
      TransferAction.cancel,
    ],
    TransferStatus.paused => const [
      TransferAction.resume,
      TransferAction.cancel,
    ],
    TransferStatus.failed || TransferStatus.canceled => const [
      TransferAction.retry,
      TransferAction.remove,
    ],
    TransferStatus.completed => [
      if (isDownload) TransferAction.open,
      TransferAction.remove,
    ],
  };
}
