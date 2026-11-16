import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/core/config/app_config.dart';
import 'package:pos_software/src/core/di/dependency_injection.dart';
import 'package:pos_software/src/domain/entities/auth_session_entity.dart';
import 'package:pos_software/src/domain/entities/notification_permission_status.dart';
import 'package:pos_software/src/domain/entities/remote_file_entity.dart';
import 'package:pos_software/src/domain/entities/remote_files_snapshot.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_notification_tap_entity.dart';
import 'package:pos_software/src/domain/services/connectivity_service.dart';
import 'package:pos_software/src/domain/usecases/auth/get_session_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/login_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/logout_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/open_registration_portal_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/watch_session_expired_use_case.dart';
import 'package:pos_software/src/domain/usecases/files/delete_remote_file_use_case.dart';
import 'package:pos_software/src/domain/usecases/files/get_cached_files_use_case.dart';
import 'package:pos_software/src/domain/usecases/files/refresh_remote_files_use_case.dart';
import 'package:pos_software/src/domain/usecases/files/validate_upload_file_use_case.dart';
import 'package:pos_software/src/domain/usecases/system/watch_connectivity_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/cancel_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/clear_finished_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/get_notification_permission_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/get_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/open_notification_settings_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/open_transfer_file_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/pause_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/remove_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/request_notification_permission_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/resume_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/resync_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/retry_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/start_download_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/start_upload_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/watch_transfer_notification_taps_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/watch_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/watch_upload_resume_support_use_case.dart';
import 'package:pos_software/src/presentation/blocs/auth/auth_bloc.dart';
import 'package:pos_software/src/presentation/blocs/connectivity/connectivity_cubit.dart';
import 'package:pos_software/src/presentation/blocs/files/files_bloc.dart';
import 'package:pos_software/src/presentation/blocs/notification_permission/notification_permission_cubit.dart';
import 'package:pos_software/src/presentation/blocs/transfer/transfer_bloc.dart';
import 'package:pos_software/src/presentation/blocs/upload/upload_bloc.dart';
import 'package:pos_software/src/presentation/router/app_navigation_service.dart';
import 'package:pos_software/src/presentation/router/router.dart';

import 'mocks.dart';

class MockConnectivityService extends Mock implements ConnectivityService {}

/// Wires the real blocs and router to mocked repositories, the way the DI
/// root does, so widget tests can pump the whole app.
class TestApp {
  final MockAuthenticationRepository auth = MockAuthenticationRepository();
  final MockRemoteFilesRepository files = MockRemoteFilesRepository();
  final MockTransferRepository transfers = MockTransferRepository();
  final MockFilePickerService picker = MockFilePickerService();
  final MockFileInspector inspector = MockFileInspector();
  final MockConnectivityService connectivity = MockConnectivityService();
  final StreamController<TransferEntity> updates =
      StreamController<TransferEntity>.broadcast();

  /// Stands in for the native side delivering a system-tray notification tap.
  final StreamController<TransferNotificationTapEntity> notificationTaps =
      StreamController<TransferNotificationTapEntity>.broadcast();

  /// Applied to each new [UploadBloc], to put the Upload tab in a given state.
  UploadState? uploadSeed;

  Future<void> register({
    AuthSessionEntity? session,
    List<TransferEntity> history = const [],
    List<RemoteFileEntity> remoteFiles = const [],
    bool online = true,
    NotificationPermissionStatus permission =
        NotificationPermissionStatus.granted,
  }) async {
    when(() => auth.getValidSession())
        .thenAnswer((_) async => Success(session));
    when(() => auth.watchSessionExpired())
        .thenAnswer((_) => const Stream.empty());
    when(() => auth.logout()).thenAnswer((_) async => const Success(null));
    when(() => auth.openRegistrationPortal())
        .thenAnswer((_) async => const Success(null));
    final snapshot = RemoteFilesSnapshot(
      files: remoteFiles,
      fromCache: false,
      syncedAt: DateTime(2026, 11, 14, 9),
    );
    when(() => files.getCachedFiles())
        .thenAnswer((_) async => Success(snapshot));
    when(() => files.refreshFiles()).thenAnswer((_) async => Success(snapshot));
    when(() => files.clearCache()).thenAnswer((_) async => const Success(null));
    when(() => transfers.getTransfers())
        .thenAnswer((_) async => Success(history));
    when(() => transfers.resync()).thenAnswer((_) async => Success(history));
    when(() => transfers.watchTransfers()).thenAnswer((_) => updates.stream);
    when(() => transfers.watchRemovedTransfers())
        .thenAnswer((_) => const Stream.empty());
    when(() => transfers.watchUploadResumeSupport())
        .thenAnswer((_) => const Stream.empty());
    when(() => transfers.uploadResumeSupport).thenReturn(null);
    when(() => transfers.watchNotificationTaps())
        .thenAnswer((_) => notificationTaps.stream);
    when(() => transfers.notificationPermissionStatus())
        .thenAnswer((_) async => Success(permission));
    when(() => transfers.cancelAllActive())
        .thenAnswer((_) async => const Success(null));
    when(() => transfers.clearFinished())
        .thenAnswer((_) async => const Success(null));
    when(() => connectivity.isOnline()).thenAnswer((_) async => online);
    when(() => connectivity.watchOnline())
        .thenAnswer((_) => const Stream.empty());

    await sl.reset(dispose: false);
    sl
      ..registerSingleton<AppConfig>(
        const AppConfig(serverAddress: 'http://server.test:90'),
      )
      ..registerLazySingleton<AuthBloc>(
        () => AuthBloc(
          GetSessionUseCase(auth),
          LoginUseCase(auth),
          LogoutUseCase(auth, transfers, files),
          OpenRegistrationPortalUseCase(auth),
          WatchSessionExpiredUseCase(auth),
        ),
        dispose: (bloc) => bloc.close(),
      )
      ..registerLazySingleton<TransferBloc>(
        () => TransferBloc(
          getTransfers: GetTransfersUseCase(transfers),
          watchTransfers: WatchTransfersUseCase(transfers),
          watchUploadResumeSupport: WatchUploadResumeSupportUseCase(transfers),
          resyncTransfers: ResyncTransfersUseCase(transfers),
          startDownload: StartDownloadUseCase(transfers),
          pauseTransfer: PauseTransferUseCase(transfers),
          resumeTransfer: ResumeTransferUseCase(transfers),
          cancelTransfer: CancelTransferUseCase(transfers),
          retryTransfer: RetryTransferUseCase(transfers),
          removeTransfer: RemoveTransferUseCase(transfers),
          clearFinished: ClearFinishedTransfersUseCase(transfers),
          openFile: OpenTransferFileUseCase(transfers),
        ),
        dispose: (bloc) => bloc.close(),
      )
      ..registerLazySingleton<ConnectivityCubit>(
        () => ConnectivityCubit(WatchConnectivityUseCase(connectivity)),
        dispose: (cubit) => cubit.close(),
      )
      ..registerLazySingleton<NotificationPermissionCubit>(
        () => NotificationPermissionCubit(
          GetNotificationPermissionUseCase(transfers),
          RequestNotificationPermissionUseCase(transfers),
          OpenNotificationSettingsUseCase(transfers),
        ),
        dispose: (cubit) => cubit.close(),
      )
      ..registerFactory<UploadBloc>(() {
        final bloc = UploadBloc(
          picker,
          ValidateUploadFileUseCase(inspector),
          StartUploadUseCase(transfers),
        );
        final seed = uploadSeed;
        if (seed != null) bloc.emit(seed);
        return bloc;
      })
      ..registerFactory<FilesBloc>(
        () => FilesBloc(
          GetCachedFilesUseCase(files),
          RefreshRemoteFilesUseCase(files),
          DeleteRemoteFileUseCase(files),
        ),
      )
      ..registerLazySingleton<AppRouter>(() => AppRouter(sl()))
      ..registerLazySingleton<AppNavigationService>(
        () => AppNavigationService(
          sl(),
          sl(),
          WatchTransferNotificationTapsUseCase(transfers),
        ),
      );
  }

  /// Mirrors what `main()` dispatches before `runApp`.
  Future<void> start() async {
    sl<AppNavigationService>().start();
    sl<AuthBloc>().add(const AppStarted());
    sl<TransferBloc>().add(const TransfersStarted());
    await sl<ConnectivityCubit>().start();
    await sl<NotificationPermissionCubit>().refresh();
  }

  /// Starts closing everything without awaiting it.
  ///
  /// Widget tests run on a fake clock: a bloc's `close()` future depends on
  /// work that only finishes when the test pumps, so awaiting it here would
  /// never return. The synchronous part of `close()` already cancels timers.
  void dispose() {
    unawaited(sl<AuthBloc>().close());
    unawaited(sl<TransferBloc>().close());
    unawaited(sl<ConnectivityCubit>().close());
    unawaited(sl<NotificationPermissionCubit>().close());
    unawaited(sl<AppNavigationService>().dispose());
    unawaited(sl.reset(dispose: false));
    unawaited(updates.close());
    unawaited(notificationTaps.close());
  }
}
