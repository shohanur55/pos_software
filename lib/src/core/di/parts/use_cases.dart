part of '../dependency_injection.dart';

void _registerUseCases() {
  sl
    ..registerFactory(() => LoginUseCase(sl()))
    ..registerFactory(() => LogoutUseCase(sl(), sl(), sl()))
    ..registerFactory(() => GetSessionUseCase(sl()))
    ..registerFactory(() => WatchSessionExpiredUseCase(sl()))
    ..registerFactory(() => OpenRegistrationPortalUseCase(sl()))
    ..registerFactory(() => GetCachedFilesUseCase(sl()))
    ..registerFactory(() => RefreshRemoteFilesUseCase(sl()))
    ..registerFactory(() => DeleteRemoteFileUseCase(sl()))
    ..registerFactory(() => ValidateUploadFileUseCase(sl()))
    ..registerFactory(() => StartUploadUseCase(sl()))
    ..registerFactory(() => StartDownloadUseCase(sl()))
    ..registerFactory(() => PauseTransferUseCase(sl()))
    ..registerFactory(() => ResumeTransferUseCase(sl()))
    ..registerFactory(() => CancelTransferUseCase(sl()))
    ..registerFactory(() => RetryTransferUseCase(sl()))
    ..registerFactory(() => RemoveTransferUseCase(sl()))
    ..registerFactory(() => ClearFinishedTransfersUseCase(sl()))
    ..registerFactory(() => GetTransfersUseCase(sl()))
    ..registerFactory(() => WatchTransfersUseCase(sl()))
    ..registerFactory(() => ResyncTransfersUseCase(sl()))
    ..registerFactory(() => OpenTransferFileUseCase(sl()))
    ..registerFactory(() => WatchTransferNotificationTapsUseCase(sl()))
    ..registerFactory(() => GetNotificationPermissionUseCase(sl()))
    ..registerFactory(() => RequestNotificationPermissionUseCase(sl()))
    ..registerFactory(() => OpenNotificationSettingsUseCase(sl()))
    ..registerFactory(() => WatchConnectivityUseCase(sl()));
}
