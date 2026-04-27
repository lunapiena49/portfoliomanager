import 'dart:async';

import 'package:dio/dio.dart';

/// Provider that hit a quota or rate limit.
///
/// `gemini` is bucketed alongside the market-data providers because the same
/// alert UI handles both. Add a new value when a new keyed integration is
/// wired up; never reuse one (it is part of the i18n key).
enum ApiQuotaProvider {
  gemini,
  eodhd,
  fmp,
  alphaVantage,
  twelveData,
  finnhub,
  polygon,
  marketstack,
  tiingo,
  nasdaqDataLink,
}

extension ApiQuotaProviderName on ApiQuotaProvider {
  /// Used as i18n suffix and telemetry tag. Stable.
  String get id => name;

  /// Human-readable label used as fallback when the i18n bundle is missing.
  String get displayName {
    switch (this) {
      case ApiQuotaProvider.gemini:
        return 'Gemini';
      case ApiQuotaProvider.eodhd:
        return 'EODHD';
      case ApiQuotaProvider.fmp:
        return 'Financial Modeling Prep';
      case ApiQuotaProvider.alphaVantage:
        return 'Alpha Vantage';
      case ApiQuotaProvider.twelveData:
        return 'Twelve Data';
      case ApiQuotaProvider.finnhub:
        return 'Finnhub';
      case ApiQuotaProvider.polygon:
        return 'Polygon.io';
      case ApiQuotaProvider.marketstack:
        return 'Marketstack';
      case ApiQuotaProvider.tiingo:
        return 'Tiingo';
      case ApiQuotaProvider.nasdaqDataLink:
        return 'Nasdaq Data Link';
    }
  }
}

/// Why the call was rejected.
enum ApiQuotaReason {
  /// HTTP 429 -- too many requests in the time window.
  rateLimit,

  /// Daily / monthly quota exhausted (provider-specific HTTP 403/429 + body).
  quotaExceeded,

  /// HTTP 401/403 caused by an invalid or revoked key.
  invalidKey,
}

/// One quota-style failure surfaced to the UI layer.
class ApiQuotaEvent {
  ApiQuotaEvent({
    required this.provider,
    required this.reason,
    this.detail,
    DateTime? at,
  }) : at = at ?? DateTime.now();

  final ApiQuotaProvider provider;
  final ApiQuotaReason reason;

  /// Optional short explanation from the API response (already redacted of
  /// any sensitive parameters by the caller).
  final String? detail;

  final DateTime at;
}

/// Singleton broadcast stream used by API services to notify the UI when a
/// provider returns a quota/rate-limit/invalid-key error.
///
/// Why a stream and not a Bloc: the alert is purely transient ("show a
/// snackbar"); persisting it as state would force every screen to re-emit
/// it. A broadcast Stream lets the root listener forward events to whatever
/// Scaffold is currently mounted without coupling the API layer to BLoC.
///
/// Why a singleton: every service (Gemini, EODHD, FMP, ...) emits onto the
/// same channel; there is no useful per-instance scope.
class ApiQuotaAlertService {
  ApiQuotaAlertService._();

  static final ApiQuotaAlertService instance = ApiQuotaAlertService._();

  final StreamController<ApiQuotaEvent> _controller =
      StreamController<ApiQuotaEvent>.broadcast();

  /// Subscribe from the root widget once; events fire only while the app is
  /// running. No replay -- if the UI was not listening yet, the event is
  /// dropped on the floor (acceptable for transient snackbars).
  Stream<ApiQuotaEvent> get stream => _controller.stream;

  /// Emit a new event. Safe to call from any isolate / async context.
  void emit(ApiQuotaEvent event) {
    if (_controller.isClosed) return;
    _controller.add(event);
  }

  /// Convenience: classify a provider error and emit if it matches.
  ///
  /// Returns true if an event was emitted (caller can decide to suppress its
  /// own user-facing message in that case).
  bool reportHttpFailure({
    required ApiQuotaProvider provider,
    required int? statusCode,
    String? bodyHint,
  }) {
    final reason = classify(statusCode: statusCode, bodyHint: bodyHint);
    if (reason == null) return false;
    emit(ApiQuotaEvent(
      provider: provider,
      reason: reason,
      detail: _safeDetail(bodyHint),
    ));
    return true;
  }

  /// Map a status code + body snippet to a quota reason. Null when the
  /// failure is something else (network, 5xx, malformed JSON ...).
  static ApiQuotaReason? classify({
    required int? statusCode,
    String? bodyHint,
  }) {
    if (statusCode == 429) {
      // Body usually distinguishes "rate" vs "quota" -- when in doubt,
      // pick the stricter wording so the user knows the daily budget may
      // be done, not just a transient burst.
      final body = (bodyHint ?? '').toLowerCase();
      if (body.contains('quota') || body.contains('exhausted') ||
          body.contains('daily') || body.contains('monthly') ||
          body.contains('credit') || body.contains('usage limit')) {
        return ApiQuotaReason.quotaExceeded;
      }
      return ApiQuotaReason.rateLimit;
    }
    if (statusCode == 401 || statusCode == 403) {
      final body = (bodyHint ?? '').toLowerCase();
      // Some providers return 403 when the daily quota is hit (Polygon,
      // Marketstack). Detect those before falling back to "invalid key".
      if (body.contains('quota') ||
          body.contains('limit') ||
          body.contains('exceeded') ||
          body.contains('usage')) {
        return ApiQuotaReason.quotaExceeded;
      }
      return ApiQuotaReason.invalidKey;
    }
    return null;
  }

  /// Trim the body hint so we never leak credentials or huge payloads into
  /// the snackbar / logs.
  static String? _safeDetail(String? body) {
    if (body == null) return null;
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length <= 160) return trimmed;
    return '${trimmed.substring(0, 157)}...';
  }
}

/// Inspect a [DioException] and emit a quota event if it matches.
///
/// Call from every provider service inside its `on DioException` block.
/// Returns true when an alert was raised so the caller can choose to keep
/// its own error wrapping but suppress duplicate snackbars.
bool reportProviderDioException(
  ApiQuotaProvider provider,
  DioException error,
) {
  final status = error.response?.statusCode;
  final data = error.response?.data;
  String? bodyHint;
  if (data is String) {
    bodyHint = data;
  } else if (data != null) {
    // Stringify JSON bodies cheaply -- enough for keyword matching.
    bodyHint = data.toString();
  }
  return ApiQuotaAlertService.instance.reportHttpFailure(
    provider: provider,
    statusCode: status,
    bodyHint: bodyHint,
  );
}
