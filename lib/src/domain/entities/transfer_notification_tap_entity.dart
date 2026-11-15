import 'package:equatable/equatable.dart';

import 'transfer_type.dart';

/// A tap on a transfer's system notification.
class TransferNotificationTapEntity extends Equatable {
  const TransferNotificationTapEntity({
    required this.transferId,
    required this.type,
    required this.isCompleted,
  });

  final String transferId;
  final TransferType type;
  final bool isCompleted;

  @override
  List<Object?> get props => [transferId, type, isCompleted];
}
