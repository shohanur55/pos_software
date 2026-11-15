import 'package:pos_software/src/domain/entities/auth_session_entity.dart';
import 'package:pos_software/src/domain/entities/picked_file_entity.dart';
import 'package:pos_software/src/domain/entities/remote_file_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_pause_reason.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';

final DateTime fixedNow = DateTime(2026, 11, 13, 12);

AuthSessionEntity session({DateTime? expiresAt}) => AuthSessionEntity(
  token: 'token',
  tokenType: 'Bearer',
  expiresAt: expiresAt ?? fixedNow.add(const Duration(hours: 24)),
  userId: 5,
  username: 'cashier',
);

const PickedFileEntity csvFile = PickedFileEntity(
  path: '/tmp/catalog.csv',
  name: 'catalog.csv',
  sizeBytes: 2048,
  extension: 'csv',
);

const RemoteFileEntity remoteCsv = RemoteFileEntity(
  name: 'catalog.csv',
  url: 'http://host/get?file=catalog.csv',
  sizeBytes: 2048,
);

TransferEntity transfer({
  String id = 't1',
  TransferType type = TransferType.upload,
  TransferStatus status = TransferStatus.running,
  double progress = 0.4,
  String fileName = 'catalog.csv',
  String? remoteFileName,
  String? savedPath,
  DateTime? createdAt,
  TransferErrorKind? errorKind,
  int? totalBytes = 1000,
  double? speedBytesPerSecond,
  Duration? timeRemaining,
  TransferPauseReason? pauseReason,
  int resumeFromByte = 0,
  bool canPauseNatively = false,
}) {
  final created = createdAt ?? fixedNow;
  return TransferEntity(
    id: id,
    type: type,
    fileName: fileName,
    remoteFileName: remoteFileName,
    savedPath: savedPath,
    status: status,
    progress: progress,
    totalBytes: totalBytes,
    transferredBytes: totalBytes == null ? 0 : (progress * totalBytes).round(),
    speedBytesPerSecond: speedBytesPerSecond,
    timeRemaining: timeRemaining,
    createdAt: created,
    updatedAt: created,
    errorKind: errorKind,
    pauseReason: pauseReason,
    resumeFromByte: resumeFromByte,
    canPauseNatively: canPauseNatively,
  );
}
