import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_manager/services/api/retry_interceptor.dart';

/// Lightweight in-memory HTTP adapter that scripts sequential responses.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._responses);

  final List<ResponseBody Function()> _responses;
  int callCount = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final idx = callCount < _responses.length ? callCount : _responses.length - 1;
    callCount++;
    return _responses[idx]();
  }
}

ResponseBody _ok() => ResponseBody.fromString(
      '{"ok":true}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

ResponseBody _serverError() => ResponseBody.fromString(
      '{"error":"internal"}',
      500,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

ResponseBody _badRequest() => ResponseBody.fromString(
      '{"error":"bad"}',
      400,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  group('RetryInterceptor', () {
    test('retries transient 5xx responses up to maxRetries', () async {
      final dio = Dio();
      final adapter = _ScriptedAdapter([
        _serverError,
        _serverError,
        _ok,
      ]);
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        maxRetries: 3,
        initialDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 2),
      ));

      final response = await dio.get<dynamic>('https://example.com/test');
      expect(response.statusCode, 200);
      expect(adapter.callCount, 3); // 1 initial + 2 retries
    });

    test('does not retry 4xx responses', () async {
      final dio = Dio();
      final adapter = _ScriptedAdapter([
        _badRequest,
      ]);
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        maxRetries: 3,
        initialDelay: const Duration(milliseconds: 1),
      ));

      await expectLater(
        dio.get<dynamic>('https://example.com/test'),
        throwsA(isA<DioException>()),
      );
      expect(adapter.callCount, 1);
    });

    test('gives up after exhausting retries on persistent 5xx', () async {
      final dio = Dio();
      final adapter = _ScriptedAdapter([
        _serverError,
        _serverError,
        _serverError,
        _serverError,
      ]);
      dio.httpClientAdapter = adapter;
      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        maxRetries: 2,
        initialDelay: const Duration(milliseconds: 1),
        maxDelay: const Duration(milliseconds: 2),
      ));

      await expectLater(
        dio.get<dynamic>('https://example.com/test'),
        throwsA(isA<DioException>()),
      );
      // 1 initial + 2 retries = 3
      expect(adapter.callCount, 3);
    });
  });
}
