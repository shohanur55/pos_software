part of '../dependency_injection.dart';

void _registerServices() {
  sl
    ..registerLazySingleton<SessionStorage>(() => SessionStorage(sl()))
    ..registerLazySingleton<SessionEvents>(SessionEvents.new)
    ..registerLazySingleton<AuthInterceptor>(() => AuthInterceptor(sl(), sl()))
    ..registerLazySingleton(() => DioFactory.create(sl()))
    ..registerLazySingleton<RestClient>(() => RestClient(sl()))
    ..registerLazySingleton<BackgroundTransferService>(
      BackgroundTransferService.new,
    )
    ..registerLazySingleton<UploadResumeProbe>(
      () => UploadResumeProbe(sl(), sl()),
    )
    ..registerLazySingleton<ServerReachability>(ServerReachability.new)
    ..registerLazySingleton<AppDatabase>(AppDatabase.new)
    ..registerLazySingleton<TransferDao>(() => TransferDao(sl()))
    ..registerLazySingleton<RemoteFileDao>(() => RemoteFileDao(sl()))
    ..registerLazySingleton<SystemSettingsService>(SystemSettingsService.new)
    ..registerLazySingleton<FilePickerService>(FilePickerServiceImpl.new)
    ..registerLazySingleton<FileInspector>(FileInspectorImpl.new)
    ..registerLazySingleton<ConnectivityService>(
      () => ConnectivityServiceImpl(reachability: sl()),
    )
    ..registerLazySingleton<ExternalLinkService>(ExternalLinkServiceImpl.new);
}
