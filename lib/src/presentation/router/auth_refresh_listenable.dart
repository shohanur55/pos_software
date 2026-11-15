import 'dart:async';

import 'package:flutter/foundation.dart';

import '../blocs/auth/auth_bloc.dart';

/// Lets GoRouter re-run its redirect whenever the auth status changes.
class AuthRefreshListenable extends ChangeNotifier {
  AuthRefreshListenable(AuthBloc bloc) {
    _subscription = bloc.stream
        .map((state) => state.status)
        .distinct()
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthStatus> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
