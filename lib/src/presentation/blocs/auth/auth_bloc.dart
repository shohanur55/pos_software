import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/base/result.dart';
import '../../../domain/entities/auth_session_entity.dart';
import '../../../domain/usecases/auth/get_session_use_case.dart';
import '../../../domain/usecases/auth/login_use_case.dart';
import '../../../domain/usecases/auth/logout_use_case.dart';
import '../../../domain/usecases/auth/open_registration_portal_use_case.dart';
import '../../../domain/usecases/auth/watch_session_expired_use_case.dart';
import '../common/ui_notice.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._getSession,
    this._login,
    this._logout,
    this._openRegistrationPortal,
    WatchSessionExpiredUseCase watchSessionExpired, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       super(const AuthState()) {
    on<AppStarted>(_onAppStarted);
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LogoutRequested>(_onLogoutRequested);
    on<SessionExpired>(_onSessionExpired);
    on<RegistrationPortalRequested>(_onRegistrationPortalRequested);
    _expiredSubscription = watchSessionExpired().listen(
      (_) => add(const SessionExpired()),
    );
  }

  final GetSessionUseCase _getSession;
  final LoginUseCase _login;
  final LogoutUseCase _logout;
  final OpenRegistrationPortalUseCase _openRegistrationPortal;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _expiredSubscription;
  Timer? _expiryTimer;
  int _noticeId = 0;

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final result = await _getSession();
    // A broken session store must never trap the user on the splash screen.
    final session = result.dataOrNull;
    if (session == null) {
      emit(
        state.copyWith(status: AuthStatus.unauthenticated, clearSession: true),
      );
      return;
    }
    _scheduleExpiry(session);
    emit(state.copyWith(status: AuthStatus.authenticated, session: session));
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    final result = await _login(
      username: event.username,
      password: event.password,
    );
    switch (result) {
      case Success(:final data):
        _scheduleExpiry(data);
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            session: data,
            isSubmitting: false,
          ),
        );
      case Error(:final error):
        emit(
          state.copyWith(
            isSubmitting: false,
            notice: UiNotice(
              AuthNoticeKind.loginFailed,
              ++_noticeId,
              failure: error.kind,
            ),
          ),
        );
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    _expiryTimer?.cancel();
    await _logout();
    emit(
      state.copyWith(status: AuthStatus.unauthenticated, clearSession: true),
    );
  }

  Future<void> _onSessionExpired(
    SessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    if (state.status != AuthStatus.authenticated) return;
    _expiryTimer?.cancel();
    await _logout(cancelTransfers: false);
    emit(
      state.copyWith(
        status: AuthStatus.unauthenticated,
        clearSession: true,
        notice: UiNotice(AuthNoticeKind.sessionExpired, ++_noticeId),
      ),
    );
  }

  Future<void> _onRegistrationPortalRequested(
    RegistrationPortalRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _openRegistrationPortal();
    if (result case Error()) {
      emit(
        state.copyWith(
          notice: UiNotice(AuthNoticeKind.portalOpenFailed, ++_noticeId),
        ),
      );
    }
  }

  /// The token has a fixed lifetime and no refresh, so log out when it ends.
  void _scheduleExpiry(AuthSessionEntity session) {
    _expiryTimer?.cancel();
    final remaining = session.expiresAt.difference(_clock());
    _expiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => add(const SessionExpired()),
    );
  }

  @override
  Future<void> close() async {
    _expiryTimer?.cancel();
    await _expiredSubscription.cancel();
    return super.close();
  }
}
