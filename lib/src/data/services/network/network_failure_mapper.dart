import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/base/failure.dart';

/// Maps Dio and I/O errors to [Failure]s for the REST repositories.
abstract final class NetworkFailureMapper {
  static Failure map(Object error) {
    if (error is Failure) return error;
    if (error is DioException) return _fromDio(error);
    if (error is SocketException || error is HttpException) {
      return Failure(FailureKind.network, error.toString());
    }
    if (error is DatabaseException || error is FileSystemException) {
      return Failure(FailureKind.storage, error.toString());
    }
    if (error is FormatException || error is TypeError) {
      return Failure(FailureKind.invalidResponse, error.toString());
    }
    return Failure(FailureKind.unknown, error.toString());
  }

  static Failure fromStatusCode(int? code, [String? message]) {
    final kind = switch (code) {
      401 => FailureKind.unauthorized,
      403 => FailureKind.notAllowed,
      404 => FailureKind.notFound,
      413 => FailureKind.fileTooLarge,
      400 || 415 || 422 => FailureKind.invalidFile,
      final int c when c >= 500 => FailureKind.server,
      _ => FailureKind.unknown,
    };
    return Failure(kind, message ?? 'HTTP $code');
  }

  static Failure _fromDio(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => Failure(
        FailureKind.network,
        error.type.name,
      ),
      DioExceptionType.badResponse => fromStatusCode(
        error.response?.statusCode,
      ),
      DioExceptionType.unknown when error.error is SocketException => Failure(
        FailureKind.network,
        error.message,
      ),
      _ => Failure(FailureKind.unknown, error.message),
    };
  }
}
