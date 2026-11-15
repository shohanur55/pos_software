import 'package:dio/dio.dart';

import '../cache/session_storage.dart';
import 'endpoints.dart';
import 'session_events.dart';

/// Attaches the bearer token and ends the session when the server answers 401.
///
/// The API has no refresh endpoint, so a 401 always means "log in again".
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._sessionStorage, this._sessionEvents);

  final SessionStorage _sessionStorage;
  final SessionEvents _sessionEvents;

  bool _isLogin(RequestOptions options) =>
      options.path.endsWith(Endpoints.token);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final session = _sessionStorage.read();
    if (!_isLogin(options) && session != null) {
      options.headers['Authorization'] = session.authorizationHeader;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isLogin(err.requestOptions)) {
      await _sessionStorage.clear();
      _sessionEvents.notifyExpired();
    }
    handler.next(err);
  }
}
