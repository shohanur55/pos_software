import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/domain/usecases/auth/get_session_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/login_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/logout_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/open_registration_portal_use_case.dart';
import 'package:pos_software/src/domain/usecases/auth/watch_session_expired_use_case.dart';
import 'package:pos_software/src/presentation/blocs/auth/auth_bloc.dart';
import 'package:pos_software/src/presentation/blocs/common/ui_notice.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockAuthenticationRepository auth;
  late MockTransferRepository transfers;
  late MockRemoteFilesRepository files;
  late StreamController<void> expired;

  setUp(() {
    auth = MockAuthenticationRepository();
    transfers = MockTransferRepository();
    files = MockRemoteFilesRepository();
    expired = StreamController<void>.broadcast();
    when(() => auth.watchSessionExpired()).thenAnswer((_) => expired.stream);
    when(() => auth.logout()).thenAnswer((_) async => const Success(null));
    when(() => transfers.cancelAllActive())
        .thenAnswer((_) async => const Success(null));
    when(() => transfers.clearFinished())
        .thenAnswer((_) async => const Success(null));
    when(() => files.clearCache()).thenAnswer((_) async => const Success(null));
  });

  tearDown(() => expired.close());

  AuthBloc build() => AuthBloc(
    GetSessionUseCase(auth),
    LoginUseCase(auth),
    LogoutUseCase(auth, transfers, files),
    OpenRegistrationPortalUseCase(auth),
    WatchSessionExpiredUseCase(auth),
    clock: () => fixedNow,
  );

  group('AppStarted', () {
    blocTest<AuthBloc, AuthState>(
      'authenticates with a stored session',
      setUp: () =>
          when(() => auth.getValidSession())
              .thenAnswer((_) async => Success(session())),
      build: build,
      act: (bloc) => bloc.add(const AppStarted()),
      expect: () => [
        AuthState(status: AuthStatus.authenticated, session: session()),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'is unauthenticated without a session (expired sessions are dropped by the repository)',
      setUp: () =>
          when(() => auth.getValidSession())
              .thenAnswer((_) async => const Success(null)),
      build: build,
      act: (bloc) => bloc.add(const AppStarted()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    );

    blocTest<AuthBloc, AuthState>(
      'never gets stuck when reading the session fails',
      setUp: () => when(() => auth.getValidSession())
          .thenAnswer((_) async => const Error(Failure(FailureKind.unknown))),
      build: build,
      act: (bloc) => bloc.add(const AppStarted()),
      expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    );
  });

  group('LoginSubmitted', () {
    blocTest<AuthBloc, AuthState>(
      'trims the username and authenticates on success',
      setUp: () =>
          when(() => auth.login(username: 'cashier', password: 'secret'))
              .thenAnswer((_) async => Success(session())),
      build: build,
      act: (bloc) => bloc.add(
        const LoginSubmitted(username: ' cashier ', password: 'secret'),
      ),
      expect: () => [
        const AuthState(isSubmitting: true),
        AuthState(status: AuthStatus.authenticated, session: session()),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits a login failure notice',
      setUp: () =>
          when(
            () => auth.login(
              username: any(named: 'username'),
              password: any(named: 'password'),
            ),
          ).thenAnswer(
            (_) async => const Error(Failure(FailureKind.invalidCredentials)),
          ),
      build: build,
      act: (bloc) =>
          bloc.add(const LoginSubmitted(username: 'a', password: 'b')),
      expect: () => [
        const AuthState(isSubmitting: true),
        const AuthState(
          notice: UiNotice(
            AuthNoticeKind.loginFailed,
            1,
            failure: FailureKind.invalidCredentials,
          ),
        ),
      ],
    );
  });

  blocTest<AuthBloc, AuthState>(
    'logout cancels transfers, wipes history and clears the session',
    build: build,
    seed: () => AuthState(status: AuthStatus.authenticated, session: session()),
    act: (bloc) => bloc.add(const LogoutRequested()),
    expect: () => [const AuthState(status: AuthStatus.unauthenticated)],
    verify: (_) {
      verify(() => transfers.cancelAllActive()).called(1);
      verify(() => transfers.clearFinished()).called(1);
      verify(() => files.clearCache()).called(1);
      verify(() => auth.logout()).called(1);
    },
  );

  blocTest<AuthBloc, AuthState>(
    'a 401 elsewhere expires the session but keeps transfers for retry',
    build: build,
    seed: () => AuthState(status: AuthStatus.authenticated, session: session()),
    act: (_) => expired.add(null),
    expect: () => [
      const AuthState(
        status: AuthStatus.unauthenticated,
        notice: UiNotice(AuthNoticeKind.sessionExpired, 1),
      ),
    ],
    verify: (_) {
      verifyNever(() => transfers.cancelAllActive());
      verifyNever(() => transfers.clearFinished());
      verifyNever(() => files.clearCache());
    },
  );

  blocTest<AuthBloc, AuthState>(
    'session expiry is ignored when already logged out',
    build: build,
    seed: () => const AuthState(status: AuthStatus.unauthenticated),
    act: (bloc) => bloc.add(const SessionExpired()),
    expect: () => <AuthState>[],
  );

  blocTest<AuthBloc, AuthState>(
    'logs out when the token lifetime ends',
    setUp: () => when(() => auth.getValidSession()).thenAnswer(
      (_) async => Success(
        session(expiresAt: fixedNow.add(const Duration(milliseconds: 10))),
      ),
    ),
    build: build,
    act: (bloc) => bloc.add(const AppStarted()),
    wait: const Duration(milliseconds: 50),
    expect: () => [
      isA<AuthState>().having(
        (state) => state.status,
        'status',
        AuthStatus.authenticated,
      ),
      isA<AuthState>()
          .having((state) => state.status, 'status', AuthStatus.unauthenticated)
          .having(
            (state) => state.notice?.kind,
            'notice',
            AuthNoticeKind.sessionExpired,
          ),
    ],
  );

  group('registration portal', () {
    blocTest<AuthBloc, AuthState>(
      'stays silent when the browser opens',
      setUp: () =>
          when(() => auth.openRegistrationPortal())
              .thenAnswer((_) async => const Success(null)),
      build: build,
      act: (bloc) => bloc.add(const RegistrationPortalRequested()),
      expect: () => <AuthState>[],
      verify: (_) => verify(() => auth.openRegistrationPortal()).called(1),
    );

    blocTest<AuthBloc, AuthState>(
      'notices the user when no browser can open the address',
      setUp: () => when(
        () => auth.openRegistrationPortal(),
      ).thenAnswer((_) async => const Error(Failure(FailureKind.cannotOpen))),
      build: build,
      act: (bloc) => bloc.add(const RegistrationPortalRequested()),
      expect: () => [
        isA<AuthState>().having(
          (state) => state.notice?.kind,
          'notice',
          AuthNoticeKind.portalOpenFailed,
        ),
      ],
    );
  });
}
