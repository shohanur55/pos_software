import 'package:equatable/equatable.dart';

import 'transfer_error_kind.dart';
import 'transfer_pause_reason.dart';
import 'transfer_status.dart';
import 'transfer_type.dart';

class TransferEntity extends Equatable {
  const TransferEntity({
    required this.id,
    required this.type,
    required this.fileName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.remoteFileName,
    this.localPath,
    this.savedPath,
    this.url,
    double progress = 0,
    this.totalBytes,
    this.transferredBytes = 0,
    this.speedBytesPerSecond,
    this.timeRemaining,
    this.errorKind,
    this.errorMessage,
    this.canPauseNatively = false,
    this.pauseReason,
    this.resumeFromByte = 0,
  }) : progress = progress < 0 ? 0 : (progress > 1 ? 1 : progress);

  /// Stable id that survives retries and upload restarts.
  final String id;
  final TransferType type;

  /// Name shown to the user.
  final String fileName;

  /// Name of the file on the server, once known.
  final String? remoteFileName;

  /// Upload source file, or private working file of a download.
  final String? localPath;

  /// Final location of a completed download.
  final String? savedPath;
  final String? url;
  final TransferStatus status;

  /// Always within 0..1.
  final double progress;
  final int? totalBytes;
  final int transferredBytes;
  final double? speedBytesPerSecond;
  final Duration? timeRemaining;
  final TransferErrorKind? errorKind;

  /// Technical detail for logs only.
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Downloads only: the server answered a range request, so the partial file
  /// on disk can be continued instead of fetched again.
  final bool canPauseNatively;

  /// Only meaningful while [status] is paused.
  final TransferPauseReason? pauseReason;

  /// Uploads only: the byte offset the server confirmed it already holds.
  /// Zero means a resume has to send the file from the start.
  final int resumeFromByte;

  bool get isUpload => type == TransferType.upload;

  bool get isDownload => type == TransferType.download;

  /// Whether resuming continues from where the transfer stopped rather than
  /// starting the file over. Downloads rely on HTTP range requests, uploads
  /// on the endpoint accepting an offset.
  bool get resumesWhereItStopped =>
      isDownload ? canPauseNatively : resumeFromByte > 0;

  /// Parked by a dropped connection and waiting for it to come back.
  bool get isWaitingForNetwork =>
      status == TransferStatus.paused &&
      pauseReason == TransferPauseReason.noNetwork;

  @override
  List<Object?> get props => [
    id,
    type,
    fileName,
    remoteFileName,
    localPath,
    savedPath,
    url,
    status,
    progress,
    totalBytes,
    transferredBytes,
    speedBytesPerSecond,
    timeRemaining,
    errorKind,
    errorMessage,
    createdAt,
    updatedAt,
    canPauseNatively,
    pauseReason,
    resumeFromByte,
  ];
}
