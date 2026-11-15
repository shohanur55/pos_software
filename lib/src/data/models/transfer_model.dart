import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_error_kind.dart';
import '../../domain/entities/transfer_status.dart';
import '../../domain/entities/transfer_type.dart';
import 'transfer_events.dart';

/// Persisted transfer row.
///
/// [taskId] points at the native task currently backing this transfer. It
/// changes on retry and when a paused upload restarts, while [id] stays put.
class TransferModel extends TransferEntity {
  const TransferModel({
    required super.id,
    required this.taskId,
    required super.type,
    required super.fileName,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.remoteFileName,
    super.localPath,
    super.savedPath,
    super.url,
    super.progress,
    super.totalBytes,
    super.transferredBytes,
    super.speedBytesPerSecond,
    super.timeRemaining,
    super.errorKind,
    super.errorMessage,
    super.canPauseNatively,
    this.pendingFinalize = false,
  });

  final String taskId;

  /// A completed download whose file has not been moved to its final place.
  final bool pendingFinalize;

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: json['id'] as String,
      taskId: json['taskId'] as String,
      type: TransferType.values.byName(json['type'] as String),
      fileName: json['fileName'] as String,
      status: TransferStatus.values.byName(json['status'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      remoteFileName: json['remoteFileName'] as String?,
      localPath: json['localPath'] as String?,
      savedPath: json['savedPath'] as String?,
      url: json['url'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      totalBytes: (json['totalBytes'] as num?)?.toInt(),
      transferredBytes: (json['transferredBytes'] as num?)?.toInt() ?? 0,
      errorKind: switch (json['errorKind']) {
        final String name => TransferErrorKind.values.asNameMap()[name],
        _ => null,
      },
      errorMessage: json['errorMessage'] as String?,
      canPauseNatively: json['canPauseNatively'] as bool? ?? false,
      pendingFinalize: json['pendingFinalize'] as bool? ?? false,
    );
  }

  /// Speed and ETA are transient and intentionally not persisted.
  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'type': type.name,
    'fileName': fileName,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'remoteFileName': remoteFileName,
    'localPath': localPath,
    'savedPath': savedPath,
    'url': url,
    'progress': progress,
    'totalBytes': totalBytes,
    'transferredBytes': transferredBytes,
    'errorKind': errorKind?.name,
    'errorMessage': errorMessage,
    'canPauseNatively': canPauseNatively,
    'pendingFinalize': pendingFinalize,
  };

  /// Applies a native status change.
  TransferModel applyStatus(TransferStatusEvent event, DateTime now) {
    final completed = event.status == TransferStatus.completed;
    final failed = event.status == TransferStatus.failed;
    return copyWith(
      status: event.status,
      progress: completed ? 1 : progress,
      transferredBytes: completed && totalBytes != null
          ? totalBytes
          : transferredBytes,
      errorKind: failed ? (event.errorKind ?? TransferErrorKind.unknown) : null,
      clearError: !failed,
      errorMessage: failed ? event.errorMessage : null,
      clearTransient: event.status != TransferStatus.running,
      updatedAt: now,
    );
  }

  /// Applies a progress tick. Negative sentinel values never reach here.
  TransferModel applyProgress(TransferProgressEvent event, DateTime now) {
    final total = event.expectedBytes ?? totalBytes;
    return copyWith(
      status: status.isActive ? TransferStatus.running : status,
      progress: event.progress,
      totalBytes: total,
      transferredBytes: total == null
          ? transferredBytes
          : (event.progress.clamp(0, 1) * total).round(),
      speedBytesPerSecond: event.speedBytesPerSecond,
      timeRemaining: event.timeRemaining,
      clearSpeed: event.speedBytesPerSecond == null,
      clearTimeRemaining: event.timeRemaining == null,
      updatedAt: now,
    );
  }

  /// State for a fresh native task replacing the current one.
  TransferModel restartedWith(
    String newTaskId,
    DateTime now, {
    TransferErrorKind? notice,
  }) {
    return copyWith(
      taskId: newTaskId,
      status: TransferStatus.queued,
      progress: 0,
      transferredBytes: 0,
      clearTransient: true,
      clearError: notice == null,
      errorKind: notice,
      updatedAt: now,
      pendingFinalize: false,
    );
  }

  TransferModel copyWith({
    String? taskId,
    String? fileName,
    String? remoteFileName,
    String? localPath,
    String? savedPath,
    String? url,
    TransferStatus? status,
    double? progress,
    int? totalBytes,
    int? transferredBytes,
    double? speedBytesPerSecond,
    Duration? timeRemaining,
    TransferErrorKind? errorKind,
    String? errorMessage,
    DateTime? updatedAt,
    bool? canPauseNatively,
    bool? pendingFinalize,
    bool clearError = false,
    bool clearTransient = false,
    bool clearSpeed = false,
    bool clearTimeRemaining = false,
  }) {
    return TransferModel(
      id: id,
      taskId: taskId ?? this.taskId,
      type: type,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteFileName: remoteFileName ?? this.remoteFileName,
      localPath: localPath ?? this.localPath,
      savedPath: savedPath ?? this.savedPath,
      url: url ?? this.url,
      progress: progress ?? this.progress,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      speedBytesPerSecond: clearTransient || clearSpeed
          ? null
          : (speedBytesPerSecond ?? this.speedBytesPerSecond),
      timeRemaining: clearTransient || clearTimeRemaining
          ? null
          : (timeRemaining ?? this.timeRemaining),
      errorKind: clearError ? errorKind : (errorKind ?? this.errorKind),
      errorMessage: clearError
          ? errorMessage
          : (errorMessage ?? this.errorMessage),
      canPauseNatively: canPauseNatively ?? this.canPauseNatively,
      pendingFinalize: pendingFinalize ?? this.pendingFinalize,
    );
  }

  @override
  List<Object?> get props => [...super.props, taskId, pendingFinalize];
}
