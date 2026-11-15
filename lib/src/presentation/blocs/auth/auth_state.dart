part of 'auth_bloc.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

enum AuthNoticeKind { loginFailed, sessionExpired, portalOpenFailed }

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.session,
    this.isSubmitting = false,
    this.notice,
  });

  final AuthStatus status;
  final AuthSessionEntity? session;
  final bool isSubmitting;
  final UiNotice<AuthNoticeKind>? notice;

  AuthState copyWith({
    AuthStatus? status,
    AuthSessionEntity? session,
    bool clearSession = false,
    bool? isSubmitting,
    UiNotice<AuthNoticeKind>? notice,
  }) {
    return AuthState(
      status: status ?? this.status,
      session: clearSession ? null : (session ?? this.session),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [status, session, isSubmitting, notice];
}
