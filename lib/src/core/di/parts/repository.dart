part of '../dependency_injection.dart';

void _registerRepositories() {
  sl
    ..registerLazySingleton<AuthenticationRepository>(
      () => AuthenticationRepositoryImpl(sl(), sl(), sl(), sl()),
    )
    ..registerLazySingleton<RemoteFilesRepository>(
      () => RemoteFilesRepositoryImpl(sl(), sl()),
    )
    ..registerLazySingleton<TransferRepository>(
      () => TransferRepositoryImpl(
        sl(),
        sl(),
        sl(),
        sl(),
        sl(),
        sl(),
        sl(),
        sl(),
      ),
    );
}
