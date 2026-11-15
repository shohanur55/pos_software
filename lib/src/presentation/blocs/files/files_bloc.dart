import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../../domain/entities/remote_file_entity.dart';
import '../../../domain/usecases/files/delete_remote_file_use_case.dart';
import '../../../domain/usecases/files/get_cached_files_use_case.dart';
import '../../../domain/usecases/files/refresh_remote_files_use_case.dart';
import '../common/ui_notice.dart';

part 'files_event.dart';
part 'files_state.dart';

/// Offline-first: the cached list appears immediately, then the server
/// confirms or replaces it.
class FilesBloc extends Bloc<FilesEvent, FilesState> {
  FilesBloc(this._getCached, this._refresh, this._deleteFile)
    : super(const FilesState()) {
    on<FilesLoaded>(_onLoaded);
    on<FilesRefreshed>(_onRefreshed);
    on<FileDeleteRequested>(_onDeleteRequested);
  }

  final GetCachedFilesUseCase _getCached;
  final RefreshRemoteFilesUseCase _refresh;
  final DeleteRemoteFileUseCase _deleteFile;
  int _noticeId = 0;

  Future<void> _onLoaded(FilesLoaded event, Emitter<FilesState> emit) async {
    if (state.status == FilesStatus.loading) return;
    emit(state.copyWith(status: FilesStatus.loading, clearFailure: true));

    final cached = await _getCached();
    if (cached case Success(:final data) when data.files.isNotEmpty) {
      emit(
        state.copyWith(
          status: FilesStatus.success,
          files: data.files,
          syncedAt: data.syncedAt,
          isStale: true,
          isRefreshing: true,
        ),
      );
    }
    await _fetch(emit);
  }

  Future<void> _onRefreshed(
    FilesRefreshed event,
    Emitter<FilesState> emit,
  ) async {
    if (state.status == FilesStatus.success) {
      emit(state.copyWith(isRefreshing: true));
      await _fetch(emit);
    } else {
      await _onLoaded(const FilesLoaded(), emit);
    }
    event.completer?.complete();
  }

  Future<void> _fetch(Emitter<FilesState> emit) async {
    final result = await _refresh();
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            status: FilesStatus.success,
            files: data.files,
            syncedAt: data.syncedAt,
            isStale: false,
            isRefreshing: false,
            clearFailure: true,
          ),
        );
      case Error(:final error) when state.status == FilesStatus.success:
        // Keep the list that is already on screen and mark it as stale.
        emit(
          state.copyWith(
            isRefreshing: false,
            isStale: true,
            notice: UiNotice(
              FilesNoticeKind.refreshFailed,
              ++_noticeId,
              failure: error.kind,
            ),
          ),
        );
      case Error(:final error):
        emit(
          state.copyWith(
            status: FilesStatus.failure,
            failure: error.kind,
            isRefreshing: false,
          ),
        );
    }
  }

  Future<void> _onDeleteRequested(
    FileDeleteRequested event,
    Emitter<FilesState> emit,
  ) async {
    if (state.deletingNames.contains(event.name)) return;
    final index = state.files.indexWhere((file) => file.name == event.name);
    if (index < 0) return;
    final removed = state.files[index];

    emit(
      state.copyWith(
        files: [...state.files]..removeAt(index),
        deletingNames: {...state.deletingNames, event.name},
      ),
    );
    final result = await _deleteFile(event.name);
    final deleting = {...state.deletingNames}..remove(event.name);
    switch (result) {
      case Success():
        emit(
          state.copyWith(
            deletingNames: deleting,
            notice: UiNotice(
              FilesNoticeKind.deleted,
              ++_noticeId,
              subject: event.name,
            ),
          ),
        );
      case Error(:final error):
        final restored = [...state.files]
          ..insert(index.clamp(0, state.files.length), removed);
        emit(
          state.copyWith(
            files: restored,
            deletingNames: deleting,
            notice: UiNotice(
              FilesNoticeKind.deleteFailed,
              ++_noticeId,
              failure: error.kind,
              subject: event.name,
            ),
          ),
        );
    }
  }
}
