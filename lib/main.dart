import 'dart:async';

import 'package:flutter/widgets.dart';

import 'src/core/di/background_transfers.dart';
import 'src/core/di/dependency_injection.dart';
import 'src/core/utils/app_logger.dart';
import 'src/presentation/app.dart';
import 'src/presentation/blocs/auth/auth_bloc.dart';
import 'src/presentation/blocs/connectivity/connectivity_cubit.dart';
import 'src/presentation/blocs/notification_permission/notification_permission_cubit.dart';
import 'src/presentation/blocs/transfer/transfer_bloc.dart';
import 'src/presentation/router/app_navigation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupDependencies();

  // Before runApp: registers the notification-tap callback so a tap that
  // cold-started the app is captured, and replays background events.
  try {
    await initializeBackgroundTransfers();
  } on Object catch (error, stackTrace) {
    logger.e(
      'Background transfer setup failed',
      error: error,
      stackTrace: stackTrace,
    );
  }
  sl<AppNavigationService>().start();

  sl<AuthBloc>().add(const AppStarted());
  sl<TransferBloc>().add(const TransfersStarted());
  unawaited(sl<ConnectivityCubit>().start());
  unawaited(sl<NotificationPermissionCubit>().refresh());

  runApp(const PosApp());
}
