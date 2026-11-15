import 'package:dio/dio.dart';

import '../../../core/utils/app_logger.dart';
import 'auth_interceptor.dart';
import 'endpoints.dart';

abstract final class DioFactory {
  static Dio create(AuthInterceptor authInterceptor) {
    final dio = Dio(
      BaseOptions(
        baseUrl: Endpoints.baseUrl,
        // Connecting is quick on any working network, so fail fast when
        // there is none: a counter operator should not wait 20 s to be told.
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
      ),
    );
    dio.interceptors.addAll([
      authInterceptor,
      // Logs method, path and status only: headers carry the token.
      InterceptorsWrapper(
        onResponse: (response, handler) {
          logger.d(
            '${response.requestOptions.method} ${response.requestOptions.path} -> ${response.statusCode}',
          );
          handler.next(response);
        },
        onError: (error, handler) {
          logger.w(
            '${error.requestOptions.method} ${error.requestOptions.path} failed: ${error.type.name} ${error.response?.statusCode ?? ''}',
          );
          handler.next(error);
        },
      ),
    ]);
    return dio;
  }
}
