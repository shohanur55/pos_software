part of 'files_bloc.dart';

enum FilesStatus { initial, loading, success, failure }

enum FilesNoticeKind { deleted, deleteFailed, refreshFailed }

final class FilesState extends Equatable {
  const FilesState({
    this.status = FilesStatus.initial,
    this.files = const [],
    this.failure,
    this.deletingNames = const {},
    this.notice,
    this.isRefreshing = false,
    this.isStale = false,
    this.syncedAt,
  });

  final FilesStatus status;
  final List<RemoteFileEntity> files;

  /// Why the list could not be shown at all.
  final FailureKind? failure;
  final Set<String> deletingNames;
  final UiNotice<FilesNoticeKind>? notice;

  /// A refresh is running while a list is already on screen.
  final bool isRefreshing;

  /// The list comes from the device because the server could not be reached.
  final bool isStale;

  /// When the server last confirmed this list.
  final DateTime? syncedAt;

  bool get isEmpty => files.isEmpty;

  FilesState copyWith({
    FilesStatus? status,
    List<RemoteFileEntity>? files,
    FailureKind? failure,
    bool clearFailure = false,
    Set<String>? deletingNames,
    UiNotice<FilesNoticeKind>? notice,
    bool? isRefreshing,
    bool? isStale,
    DateTime? syncedAt,
  }) {
    return FilesState(
      status: status ?? this.status,
      files: files ?? this.files,
      failure: clearFailure ? null : (failure ?? this.failure),
      deletingNames: deletingNames ?? this.deletingNames,
      notice: notice ?? this.notice,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isStale: isStale ?? this.isStale,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  @override
  List<Object?> get props => [
    status,
    files,
    failure,
    deletingNames,
    notice,
    isRefreshing,
    isStale,
    syncedAt,
  ];
}
