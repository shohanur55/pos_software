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
  GoRoute(
    path: Routes.signup,
    name: Routes.signupName,
    builder: (context, state) => SignupWebViewPage(
      url: sl<AppConfig>().serverAddress,
      // Pop back to the login screen rather than letting GoRouter fall into the
      // redirect — the user hasn't signed in yet, so the stack is just login.
      onClose: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.goNamed(Routes.loginName);
        }
      },
    ),
  ),
];
