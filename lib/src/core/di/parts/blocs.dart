part of '../dependency_injection.dart';

/// Global blocs are singletons so the router and notification callbacks can
/// reach them outside the widget tree. Page blocs are created per shell.
void _registerBlocs() {
  sl
    ..registerLazySingleton<AuthBloc>(
      () => AuthBloc(sl(), sl(), sl(), sl(), sl()),
      dispose: (bloc) => bloc.close(),
    )
    ..registerLazySingleton<TransferBloc>(
      () => TransferBloc(
        getTransfers: sl(),
        watchTransfers: sl(),
        watchUploadResumeSupport: sl(),
        resyncTransfers: sl(),
        startDownload: sl(),
        pauseTransfer: sl(),
        resumeTransfer: sl(),
        cancelTransfer: sl(),
        retryTransfer: sl(),
        removeTransfer: sl(),
        clearFinished: sl(),
        openFile: sl(),
      ),
      dispose: (bloc) => bloc.close(),
    )
    ..registerLazySingleton<ConnectivityCubit>(
      () => ConnectivityCubit(sl()),
      dispose: (cubit) => cubit.close(),
    )
    ..registerLazySingleton<NotificationPermissionCubit>(
      () => NotificationPermissionCubit(sl(), sl(), sl()),
      dispose: (cubit) => cubit.close(),
    )
    ..registerFactory<UploadBloc>(() => UploadBloc(sl(), sl(), sl()))
    ..registerFactory<FilesBloc>(() => FilesBloc(sl(), sl(), sl()));
}
