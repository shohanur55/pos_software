import '../../core/base/failure.dart';
import '../../core/base/result.dart';
import '../../domain/entities/remote_files_snapshot.dart';
import '../../domain/repositories/remote_files_repository.dart';
import '../models/remote_file_model.dart';
import '../models/remote_files_parser.dart';
import '../services/database/remote_file_dao.dart';
import '../services/network/network_failure_mapper.dart';
import '../services/network/rest_client.dart';

class RemoteFilesRepositoryImpl extends RemoteFilesRepository {
  RemoteFilesRepositoryImpl(
    this._client,
    this._dao, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RestClient _client;
  final RemoteFileDao _dao;
  final DateTime Function() _clock;

  @override
  Future<Result<RemoteFilesSnapshot, Failure>> getCachedFiles() {
    return asyncGuard(() async {
      final files = await _dao.all();
      return RemoteFilesSnapshot(
        files: files,
        fromCache: true,
        syncedAt: files.isEmpty ? null : await _dao.cachedAt(),
      );
    });
  }

  @override
  Future<Result<RemoteFilesSnapshot, Failure>> refreshFiles() {
    return asyncGuard(() async {
      final files = _sorted(
        RemoteFilesParser.parseList(await _client.getFiles()),
      );
      final syncedAt = _clock();
      await _dao.replaceAll(files, syncedAt);
      return RemoteFilesSnapshot(
        files: files,
        fromCache: false,
        syncedAt: syncedAt,
      );
    });
  }

  @override
  Future<Result<void, Failure>> deleteFile(String name) {
    return asyncGuard(() async {
      await _client.deleteFile(name);
      await _dao.delete(name);
    });
  }

  @override
  Future<Result<void, Failure>> clearCache() => asyncGuard(_dao.clear);

  @override
  Failure mapException(Object error, StackTrace stackTrace) =>
      NetworkFailureMapper.map(error);

  /// Newest first; files the server gave no date for keep its order, at the end.
  static List<RemoteFileModel> _sorted(List<RemoteFileModel> files) {
    final dated = files.where((file) => file.uploadedAt != null).toList()
      ..sort((a, b) => b.uploadedAt!.compareTo(a.uploadedAt!));
    return [...dated, ...files.where((file) => file.uploadedAt == null)];
  }
}
