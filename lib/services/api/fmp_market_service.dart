import 'package:dio/dio.dart';

import '../../core/constants/app_constants.dart';

/// Service for interacting with Financial Modeling Prep market endpoints.
class FmpMarketService {
  final Dio _dio;
  String? _apiKey;

  FmpMarketService({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = AppConstants.fmpBaseUrl;
    _dio.options.connectTimeout = AppConstants.apiTimeout;
    _dio.options.receiveTimeout = AppConstants.apiTimeout;
  }

  void setApiKey(String? apiKey) {
    _apiKey = apiKey?.trim();
  }

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<List<Map<String, dynamic>>> fetchTopMovers({
    required bool gainers,
    String timePeriod = '1D',
    int limit = 20,
  }) async {
    _ensureApiKey();

    final endpoint = gainers ? '/biggest-gainers' : '/biggest-losers';
    final response = await _dio.get(
      endpoint,
      queryParameters: {
        'apikey': _apiKey,
        'timePeriod': timePeriod,
        'limit': limit,
      },
    );

    final data = response.data;
    if (data is! List) {
      return <Map<String, dynamic>>[];
    }

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>?> fetchStockPriceChange(String symbol) async {
    _ensureApiKey();

    final normalizedSymbol = symbol.trim().toUpperCase();
    if (normalizedSymbol.isEmpty) {
      return null;
    }

    final response = await _dio.get(
      '/stock-price-change',
      queryParameters: {
        'symbol': normalizedSymbol,
        'apikey': _apiKey,
      },
    );

    final data = response.data;
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
      return null;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return null;
  }

  Future<Map<String, dynamic>?> fetchQuoteShort(String symbol) async {
    _ensureApiKey();

    final normalizedSymbol = symbol.trim().toUpperCase();
    if (normalizedSymbol.isEmpty) {
      return null;
    }

    final response = await _dio.get(
      '/quote-short',
      queryParameters: {
        'symbol': normalizedSymbol,
        'apikey': _apiKey,
      },
    );

    final data = response.data;
    if (data is! List || data.isEmpty) {
      return null;
    }

    final first = data.first;
    if (first is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(first);
  }

  Future<List<Map<String, dynamic>>> fetchEconomicCalendar({
    required String from,
    required String to,
    int limit = 20,
  }) async {
    _ensureApiKey();

    final response = await _dio.get(
      '/economic-calendar',
      queryParameters: {
        'from': from,
        'to': to,
        'limit': limit,
        'apikey': _apiKey,
      },
    );

    final data = response.data;
    if (data is! List) {
      return <Map<String, dynamic>>[];
    }

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  void _ensureApiKey() {
    if (!hasApiKey) {
      throw Exception('FMP API key not configured');
    }
  }
}
