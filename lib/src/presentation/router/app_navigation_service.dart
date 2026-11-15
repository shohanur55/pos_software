import 'dart:async';

import '../../domain/entities/transfer_notification_tap_entity.dart';
import '../../domain/entities/transfer_type.dart';
import '../../domain/usecases/transfers/watch_transfer_notification_taps_use_case.dart';
import '../blocs/auth/auth_bloc.dart';
import 'router.dart';
import 'routes.dart';

/// Routes notification taps, including the one that cold-started the app.
class AppNavigationService {
  AppNavigationService(this._appRouter, this._authBloc, this._watchTaps);

  final AppRouter _appRouter;
  final AuthBloc _authBloc;
  final WatchTransferNotificationTapsUseCase _watchTaps;
  StreamSubscription<TransferNotificationTapEntity>? _subscription;
  int _tapCount = 0;

  void start() => _subscription ??= _watchTaps().listen(_onTap);

  static String destinationFor(
    TransferNotificationTapEntity tap, {
    int token = 0,
  }) {
    if (tap.type == TransferType.upload && tap.isCompleted) return Routes.files;
    return Routes.transfersFor(tap.transferId, token: token);
  }

  void _onTap(TransferNotificationTapEntity tap) {
    final location = destinationFor(tap, token: ++_tapCount);
    if (_authBloc.state.status == AuthStatus.authenticated) {
      _appRouter.router.go(location);
    } else {
      // Consumed by the router's redirect right after login succeeds.
      _appRouter.pendingLocation = location;
    }
  }

  Future<void> dispose() async => _subscription?.cancel();
}
