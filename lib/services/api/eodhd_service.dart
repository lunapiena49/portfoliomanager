import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';

/// Service for interacting with the EODHD API using the user's personal key.
///
/// Used for real-time portfolio position quotes (Hybrid Key logic).
/// Market movers always come from the serverless snapshot — no key needed.
class EodhdService {
  final Dio _dio;
  String? _apiKey;

  EodhdService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = AppConstants.eodhdBaseUrl;
    _dio.options.connectTimeout = AppConstants.apiTimeout;
    _dio.options.receiveTimeout = AppConstants.apiTimeout;
  }

  void setApiKey(String? apiKey) {
    _apiKey = apiKey?.trim();
  }

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Fetches real-time quote for a single ticker.
  ///
  /// [ticker] — bare symbol (e.g. "AAPL")
  /// [exchange] — EODHD exchange code (e.g. "US", "LSE", "XETRA")
  ///
  /// EODHD endpoint: GET /real-time/{TICKER}.{EXCHANGE}?api_token={KEY}&fmt=json
  Future<Map<String, dynamic>?> fetchRealTimeQuote(
    String ticker,
    String exchange,
  ) async {
    _ensureApiKey();
    final symbol = '${ticker.trim().toUpperCase()}.${exchange.trim().toUpperCase()}';
    final response = await _dio.get(
      '/real-time/$symbol',
      queryParameters: {'api_token': _apiKey, 'fmt': 'json'},
    );
    final data = response.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  /// Fetches the latest EOD (end-of-day) quote when real-time is unavailable.
  ///
  /// EODHD endpoint: GET /eod/{TICKER}.{EXCHANGE}?api_token={KEY}&fmt=json&period=d&order=d&limit=1
  Future<Map<String, dynamic>?> fetchEodQuote(
    String ticker,
    String exchange,
  ) async {
    _ensureApiKey();
    final symbol = '${ticker.trim().toUpperCase()}.${exchange.trim().toUpperCase()}';
    final response = await _dio.get(
      '/eod/$symbol',
      queryParameters: {
        'api_token': _apiKey,
        'fmt': 'json',
        'period': 'd',
        'order': 'd',
        'limit': 1,
      },
    );
    final data = response.data;
    if (data is List && data.isNotEmpty && data.first is Map) {
      return Map<String, dynamic>.from(data.first as Map);
    }
    return null;
  }

  /// Attempts real-time first, falls back to EOD.
  Future<Map<String, dynamic>?> fetchBestQuote(
    String ticker,
    String exchange,
  ) async {
    try {
      final rt = await fetchRealTimeQuote(ticker, exchange);
      final price = _parseDouble(rt?['close'] ?? rt?['last']);
      if (price != null && price > 0) {
        return rt;
      }
    } catch (_) {
      // fall through to EOD
    }
    return fetchEodQuote(ticker, exchange);
  }

  double? _parseDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(',', '.'));
    return null;
  }

  void _ensureApiKey() {
    if (!hasApiKey) {
      throw Exception('EODHD API key not configured');
    }
  }
}
