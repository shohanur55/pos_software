import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/notification_permission_status.dart';
import '../../../domain/usecases/transfers/get_notification_permission_use_case.dart';
import '../../../domain/usecases/transfers/open_notification_settings_use_case.dart';
import '../../../domain/usecases/transfers/request_notification_permission_use_case.dart';

final class NotificationPermissionState extends Equatable {
  const NotificationPermissionState({
    this.status,
    this.bannerDismissed = false,
  });

  /// `null` until the first check finished.
  final NotificationPermissionStatus? status;
  final bool bannerDismissed;

  bool get needsRationale =>
      status == NotificationPermissionStatus.notRequested;

  bool get showDeniedBanner =>
      status == NotificationPermissionStatus.denied && !bannerDismissed;

  NotificationPermissionState copyWith({
    NotificationPermissionStatus? status,
    bool? bannerDismissed,
  }) {
    return NotificationPermissionState(
      status: status ?? this.status,
      bannerDismissed: bannerDismissed ?? this.bannerDismissed,
    );
  }

  @override
  List<Object?> get props => [status, bannerDismissed];
}

/// Notification permission is requested on the first transfer, not at launch.
class NotificationPermissionCubit extends Cubit<NotificationPermissionState> {
  NotificationPermissionCubit(
    this._getStatus,
    this._request,
    this._openSettings,
  ) : super(const NotificationPermissionState());

  final GetNotificationPermissionUseCase _getStatus;
  final RequestNotificationPermissionUseCase _request;
  final OpenNotificationSettingsUseCase _openSettings;

  Future<void> refresh() async {
    final result = await _getStatus();
    final status = result.dataOrNull;
    if (status != null && !isClosed) emit(state.copyWith(status: status));
  }

  Future<void> request() async {
    final result = await _request();
    final status = result.dataOrNull ?? NotificationPermissionStatus.denied;
    if (!isClosed) emit(state.copyWith(status: status));
  }

  /// Transfers work without notifications, so declining only shows the banner.
  void declined() =>
      emit(state.copyWith(status: NotificationPermissionStatus.denied));

  void dismissBanner() => emit(state.copyWith(bannerDismissed: true));

  Future<void> openSettings() => _openSettings();
}
