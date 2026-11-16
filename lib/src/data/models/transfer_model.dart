import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_error_kind.dart';
import '../../domain/entities/transfer_pause_reason.dart';
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
    super.pauseReason,
    super.resumeFromByte,
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
      pauseReason: switch (json['pauseReason']) {
        final String name => TransferPauseReason.values.asNameMap()[name],
        _ => null,
      },
      resumeFromByte: (json['resumeFromByte'] as num?)?.toInt() ?? 0,
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
    'pauseReason': pauseReason?.name,
    'resumeFromByte': resumeFromByte,
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
      clearPauseReason: event.status != TransferStatus.paused,
      updatedAt: now,
    );
  }

  // Applies a progress tick. A resumed upload only sends the bytes after
  // resumeFromByte, so the size and fraction describe that remainder; rebase
  // them onto the whole file so the bar doesn't jump back to 0%.
  TransferModel applyProgress(TransferProgressEvent event, DateTime now) {
    final offset = isUpload ? resumeFromByte : 0;
    final total = offset > 0 ? totalBytes : (event.expectedBytes ?? totalBytes);
    final fraction = _rebase(
      event.progress.clamp(0, 1).toDouble(),
      offset,
      total,
    );
    return copyWith(
      status: status.isActive ? TransferStatus.running : status,
      progress: fraction,
      totalBytes: total,
      transferredBytes: total == null
          ? transferredBytes
          : (fraction * total).round(),
      speedBytesPerSecond: event.speedBytesPerSecond,
      timeRemaining: event.timeRemaining,
      clearSpeed: event.speedBytesPerSecond == null,
      clearTimeRemaining: event.timeRemaining == null,
      updatedAt: now,
    );
  }

  static double _rebase(double fraction, int offset, int? total) {
    if (offset <= 0 || total == null || total <= offset) return fraction;
    return (offset + fraction * (total - offset)) / total;
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
      resumeFromByte: 0,
      clearPauseReason: true,
    );
  }

  /// State for a fresh native task that continues from [offset] rather than
  /// starting the file over, so the progress already on screen stays put.
  TransferModel resumedWith(String newTaskId, int offset, DateTime now) {
    final total = totalBytes;
    return copyWith(
      taskId: newTaskId,
      status: TransferStatus.queued,
      resumeFromByte: offset,
      transferredBytes: offset,
      progress: total == null || total <= 0 ? progress : offset / total,
      clearTransient: true,
      clearError: true,
      clearPauseReason: true,
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
    TransferPauseReason? pauseReason,
    int? resumeFromByte,
    bool? pendingFinalize,
    bool clearPauseReason = false,
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
      pauseReason: clearPauseReason
          ? pauseReason
          : (pauseReason ?? this.pauseReason),
      resumeFromByte: resumeFromByte ?? this.resumeFromByte,
      pendingFinalize: pendingFinalize ?? this.pendingFinalize,
    );
  }

  @override
  List<Object?> get props => [...super.props, taskId, pendingFinalize];
}
