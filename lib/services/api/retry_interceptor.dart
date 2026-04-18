import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Dio interceptor that retries transient failures with exponential backoff.
///
/// Retries on: connection timeout, receive timeout, send timeout, connection
/// errors, and HTTP 5xx responses. Does NOT retry 4xx (client errors),
/// including 429 (caller should handle rate-limit UX).
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this.dio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 8),
    this.retryStatusCodes = const {500, 502, 503, 504},
  });

  final Dio dio;
  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final Set<int> retryStatusCodes;

  static const String _retryCountKey = 'retry_count';

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final retryCount = (requestOptions.extra[_retryCountKey] as int?) ?? 0;

    if (!_shouldRetry(err) || retryCount >= maxRetries) {
      return handler.next(err);
    }

    final delay = _computeDelay(retryCount);
    await Future.delayed(delay);

    final newOptions = requestOptions.copyWith(
      extra: {
        ...requestOptions.extra,
        _retryCountKey: retryCount + 1,
      },
    );

    try {
      final response = await dio.fetch<dynamic>(newOptions);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }

  bool _shouldRetry(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode;
        return status != null && retryStatusCodes.contains(status);
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }

  Duration _computeDelay(int retryCount) {
    final exponentMs = initialDelay.inMilliseconds * pow(2, retryCount).toInt();
    final cappedMs = min(exponentMs, maxDelay.inMilliseconds);
    return Duration(milliseconds: cappedMs);
  }
}
