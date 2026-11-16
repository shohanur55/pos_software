import 'package:dio/dio.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../cache/cache_service.dart';
import '../network/endpoints.dart';

/// Asks the upload endpoint how much of an interrupted upload it still holds.
///
/// Every resumable-upload protocol in common use answers the same question the
/// same way: send the upload's identity with `Content-Range: bytes *​/<total>`
/// and an empty body, and a server that supports resuming replies `308` with a
/// `Range: bytes=0-<last>` header naming the last byte it has. A server that
/// does not support it answers something else, and there is nothing to resume.
///
/// The endpoint this app ships against takes a single multipart `POST` and has
/// no resumable variant, so the probe returns `null` there and the caller
/// restarts the upload instead. Keeping the negotiation in one small class is
/// what makes that a configuration fact rather than a rewrite: point the app at
/// an endpoint that speaks the convention — tus, S3 multipart, Google's
/// resumable protocol — and uploads continue from their offset with no other
/// change.
class UploadResumeProbe {
  UploadResumeProbe(this._dio, this._cache);

  final Dio _dio;
  final CacheService _cache;

  /// Below this there is nothing worth negotiating for: re-sending a few
  /// megabytes costs less than a round trip, and a server that does not
  /// support resuming never sees a probe at all for ordinary uploads.
  static const int minimumBytesWorthResuming = 8 * 1024 * 1024;

  /// Marks a request that is only asking what the endpoint can do, rather
  /// than about a particular upload.
  static const String _capabilityCheckId = 'capability-check';

  /// What is already known about this endpoint: `true` it can continue an
  /// interrupted upload, `false` it cannot, `null` nobody has asked yet.
  bool? get cachedSupport => _cachedVerdict();

  /// Settles the question at the start of the first upload instead of waiting
  /// until someone pauses one.
  ///
  /// Knowing early is what lets the app say "this server can't continue an
  /// interrupted upload" *before* the operator pauses a 300 MB file, rather
  /// than apologising afterwards. One small request per server per install.
  Future<bool?> ensureChecked({
    required int totalBytes,
    required String authorization,
  }) async {
    final known = _cachedVerdict();
    if (known != null || totalBytes <= 0) return known;
    await _ask(
      uploadId: _capabilityCheckId,
      totalBytes: totalBytes,
      authorization: authorization,
    );
    return _cachedVerdict();
  }

  /// Bytes the server confirms it already holds for [uploadId], or `null` when
  /// this endpoint cannot resume uploads and the file has to be sent again.
  Future<int?> confirmedBytes({
    required String uploadId,
    required int totalBytes,
    required int transferredBytes,
    required String authorization,
  }) async {
    if (transferredBytes < minimumBytesWorthResuming || totalBytes <= 0) {
      return null;
    }
    if (_cachedVerdict() == false) return null;
    return _ask(
      uploadId: uploadId,
      totalBytes: totalBytes,
      authorization: authorization,
    );
  }

  Future<int?> _ask({
    required String uploadId,
    required int totalBytes,
    required String authorization,
  }) async {
    try {
      final response = await _dio.post<void>(
        Endpoints.upload,
        options: Options(
          headers: {
            'Authorization': authorization,
            'Content-Range': 'bytes */$totalBytes',
            'Content-Length': 0,
            Endpoints.uploadIdHeader: uploadId,
          },
          validateStatus: (_) => true,
          receiveDataWhenStatusError: false,
        ),
      );
      final offset = _offsetFrom(response, totalBytes);
      // One unsupported answer settles it for this server; the app never
      // probes that endpoint again.
      await _remember(supported: offset != null);
      return offset;
    } on DioException catch (error) {
      // A probe that could not complete says nothing about the server, so the
      // verdict is not cached. The upload restarts this time and the question
      // is asked again next time.
      logger.d('Upload resume probe failed: ${error.type.name}');
      return null;
    }
  }

  static int? _offsetFrom(Response<void> response, int totalBytes) {
    final status = response.statusCode;
    // The whole file arrived before the connection dropped.
    if (status == 200 || status == 201 || status == 204) return totalBytes;
    if (status != 308) return null;
    final range =
        response.headers.value('range') ??
        response.headers.value('x-upload-offset');
    if (range == null) return null;
    final last = RegExp(r'bytes[= ]0-(\d+)').firstMatch(range);
    if (last != null) {
      final offset = int.parse(last.group(1)!) + 1;
      return offset >= 0 && offset <= totalBytes ? offset : null;
    }
    // tus-style: a bare byte count rather than a range.
    final bare = int.tryParse(range.trim());
    return bare != null && bare >= 0 && bare <= totalBytes ? bare : null;
  }

  /// Scoped to the configured server: pointing the app at a different host
  /// must not inherit the previous one's answer.
  bool? _cachedVerdict() {
    final stored = _cache.readJson(StorageKeys.uploadResumeSupport);
    if (stored == null || stored['host'] != Endpoints.baseUrl) return null;
    return stored['supported'] as bool?;
  }

  Future<void> _remember({required bool supported}) => _cache.writeJson(
    StorageKeys.uploadResumeSupport,
    {'host': Endpoints.baseUrl, 'supported': supported},
  );
}
