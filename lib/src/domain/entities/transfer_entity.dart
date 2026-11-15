import 'package:equatable/equatable.dart';

import 'transfer_error_kind.dart';
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
  final bool canPauseNatively;

  bool get isUpload => type == TransferType.upload;

  bool get isDownload => type == TransferType.download;

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
  ];
}
