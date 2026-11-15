import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/di/dependency_injection.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/files/files_bloc.dart';
import '../blocs/upload/upload_bloc.dart';
import '../pages/files/files_page.dart';
import '../pages/login/login_page.dart';
import '../pages/shell/main_shell_page.dart';
import '../pages/signup/signup_webview_page.dart';
import '../pages/splash/splash_page.dart';
import '../pages/transfers/transfers_page.dart';
import '../pages/upload/upload_page.dart';
import 'auth_refresh_listenable.dart';
import 'routes.dart';

part 'parts/auth_routes.dart';
part 'parts/home_routes.dart';

/// Owns the app's [GoRouter] so it can be used outside the widget tree.
class AppRouter {
  AppRouter(this._authBloc) {
    router = GoRouter(
      initialLocation: Routes.splash,
      refreshListenable: AuthRefreshListenable(_authBloc),
      redirect: _redirect,
      routes: [
        ..._authRoutes(),
        GoRoute(path: Routes.home, redirect: (context, state) => Routes.upload),
        _homeRoutes(),
      ],
    );
  }

  final AuthBloc _authBloc;
  late final GoRouter router;

  /// Destination requested before the user was authenticated, e.g. by a
  /// notification tap that cold-started the app.
  String? pendingLocation;

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;
    switch (_authBloc.state.status) {
      case AuthStatus.unknown:
        return location == Routes.splash ? null : Routes.splash;
      case AuthStatus.unauthenticated:
        if (location == Routes.login || location == Routes.signup) return null;
        return Routes.login;
      case AuthStatus.authenticated:
        if (location != Routes.splash && location != Routes.login) return null;
        final pending = pendingLocation;
        pendingLocation = null;
        return pending ?? Routes.upload;
    }
  }
}
