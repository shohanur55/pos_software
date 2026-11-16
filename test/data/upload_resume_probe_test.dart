import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/constants/storage_keys.dart';
import 'package:pos_software/src/data/services/cache/cache_service.dart';
import 'package:pos_software/src/data/services/network/endpoints.dart';
import 'package:pos_software/src/data/services/transfer/upload_resume_probe.dart';

class MockDio extends Mock implements Dio {}

class MockCacheService extends Mock implements CacheService {}

void main() {
  const total = 160 * 1024 * 1024;
  const sent = 80 * 1024 * 1024;

  late MockDio dio;
  late MockCacheService cache;
  late UploadResumeProbe probe;

  Response<void> answer(int status, {Map<String, List<String>>? headers}) =>
      Response<void>(
        requestOptions: RequestOptions(path: Endpoints.upload),
        statusCode: status,
        headers: Headers.fromMap(headers ?? const {}),
      );

  void serverAnswers(Response<void> response) {
    when(() => dio.post<void>(any(), options: any(named: 'options')))
        .thenAnswer((_) async => response);
  }

  Future<int?> ask() => probe.confirmedBytes(
    uploadId: 'transfer-1',
    totalBytes: total,
    transferredBytes: sent,
    authorization: 'Bearer token',
  );

  setUp(() {
    dio = MockDio();
    cache = MockCacheService();
    // A tiny real store, so a verdict the probe writes is a verdict it can
    // read back — which is the whole point of caching it.
    final stored = <String, Map<String, dynamic>>{};
    when(() => cache.readJson(any())).thenAnswer(
      (invocation) => stored[invocation.positionalArguments.first as String],
    );
    when(() => cache.writeJson(any(), any())).thenAnswer((invocation) async {
      stored[invocation.positionalArguments.first as String] =
          invocation.positionalArguments[1] as Map<String, dynamic>;
    });
    probe = UploadResumeProbe(dio, cache);
  });

  test('reads the offset a 308 names in its Range header', () async {
    serverAnswers(
      answer(
        308,
        headers: {
          'range': ['bytes=0-${sent - 1}'],
        },
      ),
    );

    // The header names the last byte held, the offset is the next one.
    expect(await ask(), sent);
  });

  test('accepts a bare byte count, as tus reports it', () async {
    serverAnswers(
      answer(
        308,
        headers: {
          'x-upload-offset': ['$sent'],
        },
      ),
    );

    expect(await ask(), sent);
  });

  test('reports the whole file when the server already has it', () async {
    serverAnswers(answer(200));

    expect(await ask(), total);
  });

  test('treats an offset beyond the file as no answer at all', () async {
    serverAnswers(
      answer(
        308,
        headers: {
          'range': ['bytes=0-${total + 1024}'],
        },
      ),
    );

    expect(await ask(), isNull);
  });

  test(
    'an endpoint without resumable uploads answers once and is remembered',
    () async {
      serverAnswers(answer(400));

      expect(await ask(), isNull);
      verify(
        () => cache.writeJson(StorageKeys.uploadResumeSupport, {
          'host': Endpoints.baseUrl,
          'supported': false,
        }),
      ).called(1);

      when(() => cache.readJson(StorageKeys.uploadResumeSupport))
          .thenReturn({'host': Endpoints.baseUrl, 'supported': false});

      expect(await ask(), isNull);
      // Still one request: the verdict is cached, so ordinary uploads never pay
      // for a question this server has already answered.
      verify(() => dio.post<void>(any(), options: any(named: 'options')))
          .called(1);
    },
  );

  test('a verdict recorded for a different server is ignored', () async {
    await cache.writeJson(StorageKeys.uploadResumeSupport, {
      'host': 'http://elsewhere',
      'supported': false,
    });
    serverAnswers(
      answer(
        308,
        headers: {
          'range': ['bytes=0-${sent - 1}'],
        },
      ),
    );

    expect(await ask(), sent);
  });

  test('an upload too small to be worth resuming is never probed', () async {
    expect(
      await probe.confirmedBytes(
        uploadId: 'transfer-1',
        totalBytes: total,
        transferredBytes: 1024,
        authorization: 'Bearer token',
      ),
      isNull,
    );
    verifyNever(() => dio.post<void>(any(), options: any(named: 'options')));
  });

  test(
    'a probe that cannot reach the server is not cached as a verdict',
    () async {
      when(() => dio.post<void>(any(), options: any(named: 'options')))
          .thenThrow(
            DioException.connectionError(
              requestOptions: RequestOptions(path: Endpoints.upload),
              reason: 'no route',
            ),
          );

      expect(await ask(), isNull);
      verifyNever(() => cache.writeJson(any(), any()));
    },
  );

  group('settling the question before anyone pauses', () {
    test('nothing is known until the endpoint has been asked', () {
      expect(probe.cachedSupport, isNull);
    });

    test('the first upload settles it, and it is remembered', () async {
      serverAnswers(answer(400));

      expect(
        await probe.ensureChecked(
          totalBytes: total,
          authorization: 'Bearer token',
        ),
        isFalse,
      );
      verify(
        () => cache.writeJson(StorageKeys.uploadResumeSupport, {
          'host': Endpoints.baseUrl,
          'supported': false,
        }),
      ).called(1);
    });

    test('a settled question is not asked again', () async {
      await cache.writeJson(StorageKeys.uploadResumeSupport, {
        'host': Endpoints.baseUrl,
        'supported': false,
      });

      expect(
        await probe.ensureChecked(
          totalBytes: total,
          authorization: 'Bearer token',
        ),
        isFalse,
      );
      verifyNever(() => dio.post<void>(any(), options: any(named: 'options')));
    });

    test('an unreachable server leaves the question open', () async {
      when(() => dio.post<void>(any(), options: any(named: 'options')))
          .thenThrow(
            DioException.connectionError(
              requestOptions: RequestOptions(path: Endpoints.upload),
              reason: 'no route',
            ),
          );

      // Not "false": the app must not tell an operator this endpoint cannot
      // resume when all that happened was a dropped connection.
      expect(
        await probe.ensureChecked(
          totalBytes: total,
          authorization: 'Bearer token',
        ),
        isNull,
      );
    });
  });
}
