import 'package:dio/dio.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import '../cache/cache_service.dart';
import '../network/endpoints.dart';

/// Asks the upload endpoint how much of an interrupted upload it still holds.
///
/// Sends `Content-Range: bytes *​/<total>` with an empty body. A resumable
/// server replies `308` with a `Range: bytes=0-<last>` header; anything else
/// means there is nothing to resume. This endpoint takes a single multipart
/// `POST` and has no resumable variant, so the probe returns `null` and the
/// caller restarts the upload. Pointing the app at a tus/S3/Google-style
/// endpoint turns offset resume on with no other change.
class UploadResumeProbe {
  UploadResumeProbe(this._dio, this._cache);

  final Dio _dio;
  final CacheService _cache;

  // Below this, re-sending costs less than a round trip, so don't negotiate.
  static const int minimumBytesWorthResuming = 8 * 1024 * 1024;

  // Marks a request that only asks what the endpoint can do.
  static const String _capabilityCheckId = 'capability-check';

  // Known support for this endpoint: true/false, or null if nobody has asked.
  bool? get cachedSupport => _cachedVerdict();

  // Settles the question at the first upload, so the UI can warn before a pause
  // rather than apologise after. One small request per server per install.
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

  // Bytes the server confirms it holds for uploadId, or null if this endpoint
  // can't resume and the file must be sent again.
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
      // One answer settles it for this server; cache the verdict.
      await _remember(supported: offset != null);
      return offset;
    } on DioException catch (error) {
      // A probe that couldn't complete says nothing, so don't cache; the upload
      // restarts this time and the question is asked again next time.
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

  // Scoped to the configured server so a different host doesn't inherit the
  // previous one's answer.
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
