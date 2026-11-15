import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../../domain/entities/remote_file_entity.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/entities/transfer_error_kind.dart';
import '../../../domain/entities/transfer_status.dart';
import '../../../domain/usecases/transfers/cancel_transfer_use_case.dart';
import '../../../domain/usecases/transfers/clear_finished_transfers_use_case.dart';
import '../../../domain/usecases/transfers/get_transfers_use_case.dart';
import '../../../domain/usecases/transfers/open_transfer_file_use_case.dart';
import '../../../domain/usecases/transfers/pause_transfer_use_case.dart';
import '../../../domain/usecases/transfers/remove_transfer_use_case.dart';
import '../../../domain/usecases/transfers/resume_transfer_use_case.dart';
import '../../../domain/usecases/transfers/resync_transfers_use_case.dart';
import '../../../domain/usecases/transfers/retry_transfer_use_case.dart';
import '../../../domain/usecases/transfers/start_download_use_case.dart';
import '../../../domain/usecases/transfers/watch_transfers_use_case.dart';
import '../common/ui_notice.dart';

part 'transfer_event.dart';
part 'transfer_state.dart';

/// Single source of truth for every upload and download in the app.
class TransferBloc extends Bloc<TransferEvent, TransferState> {
  TransferBloc({
    required this._getTransfers,
    required this._watchTransfers,
    required this._resyncTransfers,
    required this._startDownload,
    required this._pauseTransfer,
    required this._resumeTransfer,
    required this._cancelTransfer,
    required this._retryTransfer,
    required this._removeTransfer,
    required this._clearFinished,
    required this._openFile,
  }) : super(const TransferState()) {
    on<TransfersStarted>(_onStarted);
    on<TransfersResynced>(_onResynced);
    on<DownloadStarted>(_onDownloadStarted);
    on<TransferPaused>(
      (event, emit) => _run(emit, () => _pauseTransfer(event.id)),
    );
    on<TransferResumed>(_onResumed);
    on<TransferCanceled>(
      (event, emit) => _run(emit, () => _cancelTransfer(event.id)),
    );
    on<TransferRetried>(
      (event, emit) => _run(emit, () => _retryTransfer(event.id)),
    );
    on<TransferRemoved>(
      (event, emit) => _run(emit, () => _removeTransfer(event.id)),
    );
    on<FinishedTransfersCleared>(
      (event, emit) => _run(emit, _clearFinished.call),
    );
    on<TransferOpened>(_onOpened);
    on<TransferFailuresAcknowledged>(_onFailuresAcknowledged);
    on<ConnectionRestored>(_onConnectionRestored);
  }

  final GetTransfersUseCase _getTransfers;
  final WatchTransfersUseCase _watchTransfers;
  final ResyncTransfersUseCase _resyncTransfers;
  final StartDownloadUseCase _startDownload;
  final PauseTransferUseCase _pauseTransfer;
  final ResumeTransferUseCase _resumeTransfer;
  final CancelTransferUseCase _cancelTransfer;
  final RetryTransferUseCase _retryTransfer;
  final RemoveTransferUseCase _removeTransfer;
  final ClearFinishedTransfersUseCase _clearFinished;
  final OpenTransferFileUseCase _openFile;
  int _noticeId = 0;

  /// Transfers already retried automatically, so one dropped connection
  /// cannot put the app in a retry loop.
  final Set<String> _autoRetried = {};

  Future<void> _onStarted(
    TransfersStarted event,
    Emitter<TransferState> emit,
  ) async {
    if (state.status == TransferListStatus.loading ||
        state.status == TransferListStatus.ready) {
      return;
    }
    emit(state.copyWith(status: TransferListStatus.loading));
    final result = await _getTransfers();
    switch (result) {
      case Success(:final data):
        // Failures that happened in an earlier session are not news.
        final seen = data
            .where((transfer) => transfer.status == TransferStatus.failed)
            .map((transfer) => transfer.id);
        emit(
          state.copyWith(
            status: TransferListStatus.ready,
            transfers: _ordered(data),
            acknowledgedFailureIds: seen.toSet(),
          ),
        );
      case Error():
        emit(state.copyWith(status: TransferListStatus.failure));
    }

    final changes = _watchTransfers()
        .map<_Change>(_Updated.new)
        .merge(_watchTransfers.removed().map(_Removed.new));
    await emit.onEach<_Change>(
      changes,
      onData: (change) => switch (change) {
        _Updated(:final transfer) => _applyUpdate(transfer, emit),
        _Removed(:final id) => emit(
          state.copyWith(
            transfers: state.transfers
                .where((transfer) => transfer.id != id)
                .toList(),
          ),
        ),
      },
    );
  }

  Future<void> _onResynced(
    TransfersResynced event,
    Emitter<TransferState> emit,
  ) async {
    final result = await _resyncTransfers();
    if (result case Success(:final data)) {
      emit(
        state.copyWith(
          status: TransferListStatus.ready,
          transfers: _ordered(data),
        ),
      );
    }
  }

  Future<void> _onDownloadStarted(
    DownloadStarted event,
    Emitter<TransferState> emit,
  ) async {
    if (state.activeDownloadFor(event.file.name) != null) {
      emit(
        state.copyWith(
          notice: _notice(
            TransferNoticeKind.alreadyDownloading,
            subject: event.file.name,
          ),
        ),
      );
      return;
    }
    final result = await _startDownload(event.file);
    switch (result) {
      case Success():
        emit(
          state.copyWith(
            notice: _notice(
              TransferNoticeKind.downloadStarted,
              subject: event.file.name,
            ),
          ),
        );
      case Error(:final error) when error.kind == FailureKind.alreadyInProgress:
        emit(
          state.copyWith(
            notice: _notice(
              TransferNoticeKind.alreadyDownloading,
              subject: event.file.name,
            ),
          ),
        );
      case Error(:final error):
        emit(state.copyWith(notice: _failureNotice(error)));
    }
  }

  Future<void> _onResumed(
    TransferResumed event,
    Emitter<TransferState> emit,
  ) async {
    final result = await _resumeTransfer(event.id);
    switch (result) {
      case Success(:final data)
          when data.errorKind == TransferErrorKind.resumeFailed:
        emit(
          state.copyWith(
            notice: _notice(
              TransferNoticeKind.resumeRestarting,
              subject: data.fileName,
            ),
          ),
        );
      case Success():
        break;
      case Error(:final error):
        emit(state.copyWith(notice: _failureNotice(error)));
    }
  }

  Future<void> _onOpened(
    TransferOpened event,
    Emitter<TransferState> emit,
  ) async {
    final result = await _openFile(event.id);
    if (result case Error(:final error)) {
      final notice = error.kind == FailureKind.cannotOpen
          ? _notice(
              TransferNoticeKind.cannotOpen,
              subject: state.byId(event.id)?.savedPath ?? error.message,
            )
          : _failureNotice(error);
      emit(state.copyWith(notice: notice));
    }
  }

  Future<void> _onConnectionRestored(
    ConnectionRestored event,
    Emitter<TransferState> emit,
  ) async {
    final recoverable = state.transfers.where(
      (transfer) =>
          transfer.status == TransferStatus.failed &&
          transfer.errorKind == TransferErrorKind.network &&
          !_autoRetried.contains(transfer.id),
    );
    for (final transfer in recoverable.toList()) {
      _autoRetried.add(transfer.id);
      final result = await _retryTransfer(transfer.id);
      if (result case Success()) {
        emit(
          state.copyWith(
            notice: _notice(
              TransferNoticeKind.autoResumed,
              subject: transfer.fileName,
            ),
          ),
        );
      }
    }
  }

  void _onFailuresAcknowledged(
    TransferFailuresAcknowledged event,
    Emitter<TransferState> emit,
  ) {
    final failed = state.failedTransfers.map((transfer) => transfer.id).toSet();
    if (failed.difference(state.acknowledgedFailureIds).isEmpty) return;
    emit(
      state.copyWith(
        acknowledgedFailureIds: {...state.acknowledgedFailureIds, ...failed},
      ),
    );
  }

  void _applyUpdate(TransferEntity transfer, Emitter<TransferState> emit) {
    final previous = state.byId(transfer.id);
    // A transfer that runs again becomes eligible for a later auto-retry.
    if (transfer.status.isInProgress) _autoRetried.remove(transfer.id);
    final others = state.transfers.where((item) => item.id != transfer.id);
    final transfers = _ordered([...others, transfer]);
    final justCompleted =
        transfer.status == TransferStatus.completed &&
        previous?.status != TransferStatus.completed;
    final justFailed =
        transfer.status == TransferStatus.failed &&
        previous?.status != TransferStatus.failed;

    UiNotice<TransferNoticeKind>? notice;
    if (justCompleted && previous != null) {
      notice = _notice(
        transfer.isUpload
            ? TransferNoticeKind.uploadCompleted
            : TransferNoticeKind.downloadCompleted,
        subject: transfer.fileName,
      );
    } else if (justFailed &&
        transfer.errorKind == TransferErrorKind.unauthorized) {
      notice = _notice(TransferNoticeKind.unauthorized);
    }
    emit(state.copyWith(transfers: transfers, notice: notice));
  }

  Future<void> _run(
    Emitter<TransferState> emit,
    Future<Result<Object?, Failure>> Function() action,
  ) async {
    final result = await action();
    if (result case Error(:final error)) {
      emit(state.copyWith(notice: _failureNotice(error)));
    }
  }

  UiNotice<TransferNoticeKind> _failureNotice(Failure failure) {
    if (failure.kind == FailureKind.unauthorized) {
      return _notice(TransferNoticeKind.unauthorized);
    }
    return UiNotice(
      TransferNoticeKind.actionFailed,
      ++_noticeId,
      failure: failure.kind,
    );
  }

  UiNotice<TransferNoticeKind> _notice(
    TransferNoticeKind kind, {
    String? subject,
  }) => UiNotice(kind, ++_noticeId, subject: subject);

  static List<TransferEntity> _ordered(Iterable<TransferEntity> transfers) {
    return transfers.toList()..sort((a, b) {
      final activeOrder =
          (b.status.isInProgress ? 1 : 0) - (a.status.isInProgress ? 1 : 0);
      return activeOrder != 0
          ? activeOrder
          : b.createdAt.compareTo(a.createdAt);
    });
  }
}

sealed class _Change {
  const _Change();
}

final class _Updated extends _Change {
  const _Updated(this.transfer);

  final TransferEntity transfer;
}

final class _Removed extends _Change {
  const _Removed(this.id);

  final String id;
}
