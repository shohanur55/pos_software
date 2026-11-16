import 'package:dio/dio.dart';

import '../network/endpoints.dart';

/// Checks whether the device can actually reach the server right now.
///
/// connectivity_plus only reports whether an interface is up. A device behind a
/// captive portal, or on a router with a dead uplink, shows Wi-Fi but can't
/// reach the server; acting on that alone wastes the one automatic retry.
class ServerReachability {
  ServerReachability({Dio? dio, Duration timeout = const Duration(seconds: 6)})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: Endpoints.baseUrl,
              connectTimeout: timeout,
              receiveTimeout: timeout,
              sendTimeout: timeout,
            ),
          );

  // Bare client: no auth interceptor, so no token is attached to a probe.
  final Dio _dio;

  // Any HTTP answer (including 401 or 405) proves the route works; only a
  // transport-level failure counts as offline.
  Future<bool> canReachServer() async {
    try {
      await _dio.request<void>(
        Endpoints.upload,
        options: Options(
          method: 'OPTIONS',
          validateStatus: (_) => true,
          receiveDataWhenStatusError: false,
        ),
      );
      return true;
    } on DioException {
      return false;
    }
  }
}
