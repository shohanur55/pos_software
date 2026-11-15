part of '../dependency_injection.dart';

void _registerNavigation() {
  sl
    ..registerLazySingleton<AppRouter>(() => AppRouter(sl()))
    ..registerLazySingleton<AppNavigationService>(
      () => AppNavigationService(sl(), sl(), sl()),
    );
}
