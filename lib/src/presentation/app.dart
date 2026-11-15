import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../core/di/dependency_injection.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/connectivity/connectivity_cubit.dart';
import 'blocs/notification_permission/notification_permission_cubit.dart';
import 'blocs/transfer/transfer_bloc.dart';
import 'router/router.dart';
import 'theme/app_theme.dart';
import 'widgets/common/snackbars.dart';

class PosApp extends StatefulWidget {
  const PosApp({super.key});

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Background work may have finished, failed or been resumed while the app
  /// was away; the notification permission may have changed in settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    sl<TransferBloc>().add(const TransfersResynced());
    sl<NotificationPermissionCubit>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: sl<AuthBloc>()),
        BlocProvider<TransferBloc>.value(value: sl<TransferBloc>()),
        BlocProvider<ConnectivityCubit>.value(value: sl<ConnectivityCubit>()),
        BlocProvider<NotificationPermissionCubit>.value(
          value: sl<NotificationPermissionCubit>(),
        ),
      ],
      child: MaterialApp.router(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        scaffoldMessengerKey: _messengerKey,
        routerConfig: sl<AppRouter>().router,
        builder: (context, child) => BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              previous.notice != current.notice &&
              current.notice?.kind == AuthNoticeKind.sessionExpired,
          // Shown through the root messenger so it survives the jump to login.
          listener: (context, state) => _messengerKey.currentState
            ?..hideCurrentSnackBar()
            ..showSnackBar(
              buildAppSnackBar(
                context,
                AppStrings.sessionExpired,
                tone: SnackBarTone.error,
              ),
            ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
