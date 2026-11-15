import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/entities/transfer_status.dart';

enum TransferFilter {
  all,
  active,
  completed,
  failed;

  bool matches(TransferEntity transfer) => switch (this) {
    TransferFilter.all => true,
    TransferFilter.active => transfer.status.isInProgress,
    TransferFilter.completed => transfer.status == TransferStatus.completed,
    TransferFilter.failed =>
      transfer.status == TransferStatus.failed ||
          transfer.status == TransferStatus.canceled,
  };
}
