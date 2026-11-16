import '../../core/base/failure.dart';
import '../../core/base/repository.dart';
import '../../core/base/result.dart';
import '../entities/notification_permission_status.dart';
import '../entities/remote_file_entity.dart';
import '../entities/transfer_entity.dart';
import '../entities/transfer_notification_tap_entity.dart';
import '../entities/upload_request_entity.dart';

abstract class TransferRepository extends Repository {
  /// Persisted history, reconciled with the native task store.
  Future<Result<List<TransferEntity>, Failure>> getTransfers();

  /// Live updates; progress events are throttled, status changes never are.
  Stream<TransferEntity> watchTransfers();

  /// Emits ids of records that were deleted.
  Stream<String> watchRemovedTransfers();

  Future<Result<TransferEntity, Failure>> startUpload(
    UploadRequestEntity request,
  );

  Future<Result<TransferEntity, Failure>> startDownload(RemoteFileEntity file);

  Future<Result<void, Failure>> pause(String id);

  /// Returns the resumed transfer. A download whose server rejected the
  /// resume is restarted and reported with `errorKind == resumeFailed`.
  Future<Result<TransferEntity, Failure>> resume(String id);

  Future<Result<void, Failure>> cancel(String id);

  Future<Result<void, Failure>> cancelAllActive();

  Future<Result<TransferEntity, Failure>> retry(String id);

  Future<Result<void, Failure>> remove(String id);

  Future<Result<void, Failure>> clearFinished();

  Future<Result<void, Failure>> openFile(String id);

  /// Whether this server can continue an interrupted upload: `true` it can,
  /// `false` it cannot and a paused upload will be sent again from the start,
  /// `null` nobody has asked yet.
  ///
  /// The UI states this up front rather than letting an operator discover it
  /// after pausing a half-finished 300 MB file.
  Stream<bool?> watchUploadResumeSupport();

  /// The current answer to [watchUploadResumeSupport], for the first build.
  bool? get uploadResumeSupport;

  /// Re-reads background events and finalizes completed downloads.
  Future<Result<List<TransferEntity>, Failure>> resync();

  Stream<TransferNotificationTapEntity> watchNotificationTaps();

  Future<Result<NotificationPermissionStatus, Failure>>
  notificationPermissionStatus();

  Future<Result<NotificationPermissionStatus, Failure>>
  requestNotificationPermission();

  Future<Result<void, Failure>> openNotificationSettings();
}
