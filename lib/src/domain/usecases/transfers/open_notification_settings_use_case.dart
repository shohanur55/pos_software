import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../repositories/transfer_repository.dart';

final class OpenNotificationSettingsUseCase {
  OpenNotificationSettingsUseCase(this.repository);

  final TransferRepository repository;

  Future<Result<void, Failure>> call() => repository.openNotificationSettings();
}
