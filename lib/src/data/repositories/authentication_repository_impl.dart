import 'package:dio/dio.dart';

import '../../core/base/failure.dart';
import '../../core/base/result.dart';
import '../../domain/entities/auth_session_entity.dart';
import '../../domain/repositories/authentication_repository.dart';
import '../../domain/services/external_link_service.dart';
import '../models/login_response_model.dart';
import '../services/cache/session_storage.dart';
import '../services/network/endpoints.dart';
import '../services/network/network_failure_mapper.dart';
import '../services/network/rest_client.dart';
import '../services/network/session_events.dart';

class AuthenticationRepositoryImpl extends AuthenticationRepository {
  AuthenticationRepositoryImpl(
    this._client,
    this._sessionStorage,
    this._sessionEvents,
    this._links, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final RestClient _client;
  final SessionStorage _sessionStorage;
  final SessionEvents _sessionEvents;
  final ExternalLinkService _links;
  final DateTime Function() _clock;

  @override
  Future<Result<AuthSessionEntity, Failure>> login({
    required String username,
    required String password,
  }) {
    return asyncGuard(() async {
      final Object? body = await _client.login(username, password);
      if (body is! Map) {
        throw const Failure(
          FailureKind.invalidResponse,
          'Login body is not an object',
        );
      }
      final response = LoginResponseModel.fromMap(
        Map<String, dynamic>.from(body),
      );
      final session = response.toSession(_clock());
      if (session == null) {
        throw const Failure(
          FailureKind.invalidCredentials,
          'Login was not successful',
        );
      }
      await _sessionStorage.write(session);
      return session;
    });
  }

  @override
  Future<Result<AuthSessionEntity?, Failure>> getValidSession() {
    return asyncGuard(() async {
      final session = _sessionStorage.read();
      if (session == null) return null;
      if (session.isExpiredAt(_clock())) {
        await _sessionStorage.clear();
        return null;
      }
      return session;
    });
  }

  @override
  Future<Result<void, Failure>> logout() => asyncGuard(_sessionStorage.clear);

  @override
  Future<Result<void, Failure>> openRegistrationPortal() {
    return asyncGuard(() async {
      if (await _links.open(Endpoints.baseUrl)) return;
      throw const Failure(
        FailureKind.cannotOpen,
        'No browser accepted the portal URL',
      );
    });
  }

  @override
  Stream<void> watchSessionExpired() => _sessionEvents.expired;

  /// Only login talks to the network here, so any 4xx means bad credentials.
  @override
  Failure mapException(Object error, StackTrace stackTrace) {
    if (error is DioException) {
      final code = error.response?.statusCode;
      if (code != null && code >= 400 && code < 500) {
        return Failure(FailureKind.invalidCredentials, 'HTTP $code');
      }
    }
    return NetworkFailureMapper.map(error);
  }
}
