import '../../core/base/failure.dart';
import '../../core/base/repository.dart';
import '../../core/base/result.dart';
import '../entities/remote_files_snapshot.dart';

abstract class RemoteFilesRepository extends Repository {
  /// The list stored on the device. Works offline and never fails on network.
  Future<Result<RemoteFilesSnapshot, Failure>> getCachedFiles();

  /// Fetches from the server and refreshes the cache.
  Future<Result<RemoteFilesSnapshot, Failure>> refreshFiles();

  Future<Result<void, Failure>> deleteFile(String name);

  /// Drops the cached list, e.g. when the user logs out.
  Future<Result<void, Failure>> clearCache();
}
