import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../entities/notification_permission_status.dart';
import '../../repositories/transfer_repository.dart';

final class GetNotificationPermissionUseCase {
  GetNotificationPermissionUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<NotificationPermissionStatus, Failure>> call() =>
      repository.notificationPermissionStatus();
}
