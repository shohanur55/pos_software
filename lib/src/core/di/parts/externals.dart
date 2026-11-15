part of '../dependency_injection.dart';

Future<void> _registerExternals() async {
  sl
    ..registerSingleton<AppConfig>(
      const AppConfig(serverAddress: Endpoints.baseUrl),
    )
    ..registerSingleton<CacheService>(await CacheService.create());
}
