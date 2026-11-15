part of 'transfer_bloc.dart';

enum TransferListStatus { initial, loading, ready, failure }

enum TransferNoticeKind {
  uploadCompleted,
  downloadCompleted,
  downloadStarted,
  autoResumed,
  alreadyDownloading,
  resumeRestarting,
  unauthorized,
  actionFailed,
  cannotOpen,
}

final class TransferState extends Equatable {
  const TransferState({
    this.status = TransferListStatus.initial,
    this.transfers = const [],
    this.acknowledgedFailureIds = const {},
    this.notice,
  });

  final TransferListStatus status;

  /// Active and paused first, then newest first.
  final List<TransferEntity> transfers;
  final Set<String> acknowledgedFailureIds;
  final UiNotice<TransferNoticeKind>? notice;

  List<TransferEntity> get activeTransfers =>
      transfers.where((transfer) => transfer.status.isInProgress).toList();

  int get activeCount =>
      transfers.where((transfer) => transfer.status.isInProgress).length;

  List<TransferEntity> get failedTransfers => transfers
      .where((transfer) => transfer.status == TransferStatus.failed)
      .toList();

  int get failedCount => failedTransfers.length;

  int get unseenFailedCount => failedTransfers
      .where((transfer) => !acknowledgedFailureIds.contains(transfer.id))
      .length;

  int get completedCount => transfers
      .where((transfer) => transfer.status == TransferStatus.completed)
      .length;

  int get finishedCount =>
      transfers.where((transfer) => transfer.status.isFinished).length;

  /// Average progress of in-progress transfers, 0 when none.
  double get overallProgress {
    final active = activeTransfers;
    if (active.isEmpty) return 0;
    return active.fold<double>(0, (sum, transfer) => sum + transfer.progress) /
        active.length;
  }

  TransferEntity? byId(String? id) => id == null
      ? null
      : transfers.where((transfer) => transfer.id == id).firstOrNull;

  TransferEntity? activeDownloadFor(String remoteName) => transfers
      .where(
        (transfer) =>
            transfer.isDownload &&
            transfer.remoteFileName == remoteName &&
            transfer.status.isInProgress,
      )
      .firstOrNull;

  /// Most recent download of [remoteName]; [transfers] is already ordered.
  TransferEntity? latestDownloadFor(String remoteName) => transfers
      .where(
        (transfer) =>
            transfer.isDownload && transfer.remoteFileName == remoteName,
      )
      .firstOrNull;

  TransferState copyWith({
    TransferListStatus? status,
    List<TransferEntity>? transfers,
    Set<String>? acknowledgedFailureIds,
    UiNotice<TransferNoticeKind>? notice,
  }) {
    return TransferState(
      status: status ?? this.status,
      transfers: transfers ?? this.transfers,
      acknowledgedFailureIds:
          acknowledgedFailureIds ?? this.acknowledgedFailureIds,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    status,
    transfers,
    acknowledgedFailureIds,
    notice,
  ];
}
