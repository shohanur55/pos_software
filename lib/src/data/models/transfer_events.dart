import '../../domain/entities/transfer_error_kind.dart';
import '../../domain/entities/transfer_status.dart';
import 'transfer_task_meta.dart';

/// Native task change, already translated to domain vocabulary.
sealed class TransferTaskEvent {
  const TransferTaskEvent(this.taskId, this.meta);

  final String taskId;
  final TransferTaskMeta? meta;
}

final class TransferStatusEvent extends TransferTaskEvent {
  const TransferStatusEvent(
    super.taskId,
    super.meta, {
    required this.status,
    this.errorKind,
    this.errorMessage,
    this.responseBody,
  });

  final TransferStatus status;
  final TransferErrorKind? errorKind;
  final String? errorMessage;
  final String? responseBody;
}

final class TransferProgressEvent extends TransferTaskEvent {
  const TransferProgressEvent(
    super.taskId,
    super.meta, {
    required this.progress,
    this.expectedBytes,
    this.speedBytesPerSecond,
    this.timeRemaining,
  });

  /// Always within 0..1.
  final double progress;
  final int? expectedBytes;
  final double? speedBytesPerSecond;
  final Duration? timeRemaining;
}
