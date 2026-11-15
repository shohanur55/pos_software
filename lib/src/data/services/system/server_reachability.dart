import 'package:dio/dio.dart';

import '../network/endpoints.dart';

/// Answers one question: can this device actually reach the server right now?
///
/// `connectivity_plus` only reports whether a network *interface* is up. A
/// terminal joined to a cafe hotspot behind a captive portal, or to a shop
/// router whose uplink is down, reports Wi-Fi and is still unreachable. Acting
/// on that alone makes the app announce "back online" and burn its one
/// automatic retry against a dead route.
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

  /// Deliberately a bare client: no auth interceptor, so no token is ever
  /// attached to a probe.
  final Dio _dio;

  /// Any HTTP answer proves the route works, including `401` or `405` — this
  /// asks whether the server is *reachable*, not whether we may talk to it.
  /// Only a transport-level failure counts as offline.
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
