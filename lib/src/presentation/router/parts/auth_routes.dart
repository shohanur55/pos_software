part of '../router.dart';

List<RouteBase> _authRoutes() => [
  GoRoute(
    path: Routes.splash,
    name: Routes.splashName,
    builder: (context, state) => const SplashPage(),
  ),
  GoRoute(
    path: Routes.login,
    name: Routes.loginName,
    builder: (context, state) =>
        LoginPage(serverAddress: sl<AppConfig>().serverAddress),
  ),
];
