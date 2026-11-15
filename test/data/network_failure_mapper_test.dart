import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/data/services/network/network_failure_mapper.dart';

void main() {
  final options = RequestOptions(path: '/get');

  DioException bad(int code) => DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<void>(requestOptions: options, statusCode: code),
  );

  test('maps connectivity problems to network', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.connectionError,
    ]) {
      expect(
        NetworkFailureMapper.map(
          DioException(requestOptions: options, type: type),
        ).kind,
        FailureKind.network,
      );
    }
    expect(
      NetworkFailureMapper.map(const SocketException('down')).kind,
      FailureKind.network,
    );
  });

  test('maps HTTP status codes', () {
    expect(NetworkFailureMapper.map(bad(401)).kind, FailureKind.unauthorized);
    expect(NetworkFailureMapper.map(bad(404)).kind, FailureKind.notFound);
    expect(NetworkFailureMapper.map(bad(413)).kind, FailureKind.fileTooLarge);
    expect(NetworkFailureMapper.map(bad(422)).kind, FailureKind.invalidFile);
    expect(NetworkFailureMapper.map(bad(500)).kind, FailureKind.server);
    expect(NetworkFailureMapper.map(bad(418)).kind, FailureKind.unknown);
  });

  test('maps local storage problems to storage', () {
    expect(
      NetworkFailureMapper.map(
        const FileSystemException('disk full', '/tmp/a.csv'),
      ).kind,
      FailureKind.storage,
    );
  });

  test('maps malformed payloads to invalidResponse', () {
    expect(
      NetworkFailureMapper.map(const FormatException('bad')).kind,
      FailureKind.invalidResponse,
    );
  });

  test('passes failures through', () {
    const failure = Failure(FailureKind.storage);
    expect(NetworkFailureMapper.map(failure), same(failure));
  });
}
