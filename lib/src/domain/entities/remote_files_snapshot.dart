import 'package:equatable/equatable.dart';

import 'remote_file_entity.dart';

/// The file list together with how fresh it is.
///
/// The app shows the cached list immediately and marks it stale until the
/// server confirms it, so the Files tab is usable offline.
class RemoteFilesSnapshot extends Equatable {
  const RemoteFilesSnapshot({
    required this.files,
    required this.fromCache,
    this.syncedAt,
  });

  const RemoteFilesSnapshot.empty()
    : files = const [],
      fromCache = true,
      syncedAt = null;

  final List<RemoteFileEntity> files;

  /// True when the list came from the device, not from the server.
  final bool fromCache;

  /// When the server last confirmed this list.
  final DateTime? syncedAt;

  bool get hasNeverSynced => syncedAt == null;

  @override
  List<Object?> get props => [files, fromCache, syncedAt];
}
