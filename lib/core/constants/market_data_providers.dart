/// Catalog of market-data providers the user can configure.
///
/// A provider is identified by its enum value (stable; do NOT renumber).
/// Display strings are not localized here -- they are i18n keys looked up at
/// the call site so the catalog stays a pure data structure.
///
/// Endpoint references verified Apr 2026 against the official provider docs.
/// When an endpoint changes upstream, update [ProviderConfig.baseUrl] and
/// [ProviderConfig.docsUrl]; this is the single source of truth for the app.
library;

/// Stable identifiers for the supported market-data providers.
///
/// The string [name] (lower-case, snake_case) is what we persist in storage
/// and use as a key in i18n. Adding a new provider: append at the end and
/// register a [ProviderConfig] in [ProviderCatalog.all].
enum MarketDataProvider {
  eodhd,
  fmp,
  alphaVantage,
  twelveData,
  finnhub,
  polygon,
  marketstack,
  tiingo,
  nasdaqDataLink,
  stooq,
}

/// How the provider's API key is passed on the wire.
enum ApiKeyParamStyle {
  /// `?<param>=<key>` query parameter (most common).
  queryParam,

  /// `Authorization: <prefix> <key>` HTTP header (Tiingo).
  authorizationHeader,

  /// No key needed -- public CSV download (Stooq).
  none,
}

/// Bucket used to suggest a default refresh cadence given the provider's free
/// tier. Pure UX hint: the actual cadence the user picks is independent.
enum ProviderRefreshTier {
  /// >= 60 calls/min -- realtime-friendly (Finnhub free).
  generous,

  /// 100-1000 calls/day -- comfortable for daily refresh of a small portfolio.
  comfortable,

  /// 25-100 calls/day -- daily refresh recommended.
  conservative,

  /// 100/month or stricter -- manual/weekly refresh.
  strict,

  /// No rate limit (public CSV).
  unlimited,
}

/// Static metadata for a single provider.
///
/// `freeQuotaKey` and `descriptionKey` resolve to entries under
/// `settings.providers.<id>.*` in the i18n bundles. The values returned by
/// [ProviderCatalog] are looked up at render time so changing translations
/// never requires touching this file.
class ProviderConfig {
  const ProviderConfig({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.signupUrl,
    required this.docsUrl,
    required this.keyParamName,
    required this.keyParamStyle,
    required this.refreshTier,
    required this.exampleEndpoint,
    required this.supportsHistoric,
    required this.supportsRealtime,
    required this.requiresKey,
  });

  final MarketDataProvider id;
  final String displayName;

  /// HTTPS base URL for REST calls. Trailing slash is omitted by convention.
  final String baseUrl;

  /// Where the user creates a free account / generates a key.
  final String signupUrl;

  /// Public docs landing page (deep link to the most-used endpoint when
  /// available, otherwise the docs root).
  final String docsUrl;

  /// Name of the auth parameter (e.g. `api_token`, `apikey`, `access_key`).
  /// Empty when [keyParamStyle] is [ApiKeyParamStyle.none].
  final String keyParamName;

  final ApiKeyParamStyle keyParamStyle;
  final ProviderRefreshTier refreshTier;

  /// Sample request the user can copy/paste to verify the key by hand.
  /// Uses `YOUR_KEY` as the placeholder and a well-known ticker.
  final String exampleEndpoint;

  final bool supportsHistoric;
  final bool supportsRealtime;

  /// True if the provider requires a key (false only for Stooq).
  final bool requiresKey;

  /// Stable persistence key for the user's API key in secure storage.
  ///
  /// Format: `provider_api_key_<id>`. Existing legacy keys
  /// (`gemini_api_key`, `fmp_api_key`, `eodhd_api_key`) are NOT renamed --
  /// see [ProviderCatalog.legacyStorageKeyFor] for the override map.
  String get storageKey => 'provider_api_key_${id.name}';

  /// I18n key root for this provider. The settings UI looks up
  /// `settings.providers.<id>.title|hint|free_quota|description`.
  String get i18nRoot => 'settings.providers.${id.name}';
}

/// Suggested staleness threshold for the user's quote cache.
///
/// The app does NOT poll on a timer -- this is the maximum age before a
/// quote is considered stale and refetched on the next user-facing access
/// (opening Home, refreshing Market tab, etc).
///
/// Numbers chosen to map cleanly onto the free-tier daily quotas so the user
/// can compute "calls = positions x refreshes_per_day" without a calculator.
enum MarketDataRefreshInterval {
  /// Never auto-refresh: the user pulls manually. Zero API calls until they
  /// tap the refresh button. Default for users who want full control.
  manual,

  /// Refresh once per hour. ~ 24 calls/symbol/day -- too aggressive for most
  /// free tiers but reasonable on Finnhub free (60/min).
  hourly,

  /// Refresh every 4 hours. ~ 6 calls/symbol/day -- comfortable headroom on
  /// Twelve Data (800/day) and Tiingo (50 symbols/hour) for portfolios up to
  /// ~50 positions.
  every4h,

  /// Refresh every 12 hours. ~ 2 calls/symbol/day -- safe for FMP free tier
  /// (250/day) on portfolios up to ~100 positions.
  every12h,

  /// Refresh once per day. 1 call/symbol/day -- safe for Alpha Vantage free
  /// (25/day) on tiny portfolios, and matches the public daily snapshot.
  daily,
}

extension MarketDataRefreshIntervalDuration on MarketDataRefreshInterval {
  Duration get duration {
    switch (this) {
      case MarketDataRefreshInterval.manual:
        return Duration.zero;
      case MarketDataRefreshInterval.hourly:
        return const Duration(hours: 1);
      case MarketDataRefreshInterval.every4h:
        return const Duration(hours: 4);
      case MarketDataRefreshInterval.every12h:
        return const Duration(hours: 12);
      case MarketDataRefreshInterval.daily:
        return const Duration(hours: 24);
    }
  }

  /// Stable storage value -- keeps Hive readable across schema-light edits.
  String get storageValue => name;

  static MarketDataRefreshInterval fromStorage(String? raw) {
    if (raw == null) return MarketDataRefreshInterval.daily;
    for (final v in MarketDataRefreshInterval.values) {
      if (v.name == raw) return v;
    }
    return MarketDataRefreshInterval.daily;
  }
}

/// Static catalog of all supported providers.
///
/// All endpoint values verified against provider docs in Apr 2026. Free-tier
/// numbers may drift over time -- the i18n string is what the user sees, so
/// keep it in sync with the official pricing page when you bump the catalog.
class ProviderCatalog {
  ProviderCatalog._();

  /// Storage key overrides for the three providers that pre-date the
  /// generic `provider_api_key_<id>` scheme. Keeps the existing key in place
  /// so users who already saved one don't lose it on upgrade.
  static const Map<MarketDataProvider, String> legacyStorageKeyOverrides = {
    MarketDataProvider.eodhd: 'eodhd_api_key',
    MarketDataProvider.fmp: 'fmp_api_key',
  };

  /// Effective storage key for the provider, honoring legacy overrides.
  static String storageKeyFor(MarketDataProvider id) {
    return legacyStorageKeyOverrides[id] ?? 'provider_api_key_${id.name}';
  }

  static const ProviderConfig _eodhd = ProviderConfig(
    id: MarketDataProvider.eodhd,
    displayName: 'EODHD',
    baseUrl: 'https://eodhd.com/api',
    signupUrl: 'https://eodhd.com/register',
    docsUrl: 'https://eodhd.com/financial-apis/api-for-historical-data-and-volumes',
    keyParamName: 'api_token',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.conservative,
    exampleEndpoint: 'https://eodhd.com/api/eod/AAPL.US?api_token=YOUR_KEY&fmt=json',
    supportsHistoric: true,
    supportsRealtime: true,
    requiresKey: true,
  );

  static const ProviderConfig _fmp = ProviderConfig(
    id: MarketDataProvider.fmp,
    displayName: 'Financial Modeling Prep',
    baseUrl: 'https://financialmodelingprep.com/stable',
    signupUrl: 'https://site.financialmodelingprep.com/developer/docs',
    docsUrl: 'https://site.financialmodelingprep.com/developer/docs',
    keyParamName: 'apikey',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.comfortable,
    exampleEndpoint:
        'https://financialmodelingprep.com/stable/quote?symbol=AAPL&apikey=YOUR_KEY',
    supportsHistoric: true,
    supportsRealtime: true,
    requiresKey: true,
  );

  static const ProviderConfig _alphaVantage = ProviderConfig(
    id: MarketDataProvider.alphaVantage,
    displayName: 'Alpha Vantage',
    baseUrl: 'https://www.alphavantage.co/query',
    signupUrl: 'https://www.alphavantage.co/support/#api-key',
    docsUrl: 'https://www.alphavantage.co/documentation/',
    keyParamName: 'apikey',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.conservative,
    exampleEndpoint:
        'https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=IBM&apikey=YOUR_KEY',
    supportsHistoric: true,
    supportsRealtime: false,
    requiresKey: true,
  );

  static const ProviderConfig _twelveData = ProviderConfig(
    id: MarketDataProvider.twelveData,
    displayName: 'Twelve Data',
    baseUrl: 'https://api.twelvedata.com',
    signupUrl: 'https://twelvedata.com/register',
    docsUrl: 'https://twelvedata.com/docs',
    keyParamName: 'apikey',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.comfortable,
    exampleEndpoint:
        'https://api.twelvedata.com/time_series?symbol=AAPL&interval=1day&apikey=YOUR_KEY',
    supportsHistoric: true,
    supportsRealtime: true,
    requiresKey: true,
  );

  static const ProviderConfig _finnhub = ProviderConfig(
    id: MarketDataProvider.finnhub,
    displayName: 'Finnhub',
    baseUrl: 'https://finnhub.io/api/v1',
    signupUrl: 'https://finnhub.io/register',
    docsUrl: 'https://finnhub.io/docs/api',
    keyParamName: 'token',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.generous,
    exampleEndpoint: 'https://finnhub.io/api/v1/quote?symbol=AAPL&token=YOUR_KEY',
    supportsHistoric: true,
    supportsRealtime: true,
    requiresKey: true,
  );

  static const ProviderConfig _polygon = ProviderConfig(
    id: MarketDataProvider.polygon,
    displayName: 'Polygon.io',
    baseUrl: 'https://api.polygon.io',
    signupUrl: 'https://polygon.io/dashboard/signup',
    docsUrl: 'https://polygon.io/docs/stocks',
    keyParamName: 'apiKey',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.conservative,
    exampleEndpoint:
        'https://api.polygon.io/v2/aggs/ticker/AAPL/prev?apiKey=YOUR_KEY',
    supportsHistoric: true,
    supportsRealtime: false,
    requiresKey: true,
  );

  static const ProviderConfig _marketstack = ProviderConfig(
    id: MarketDataProvider.marketstack,
    displayName: 'Marketstack',
    baseUrl: 'https://api.marketstack.com/v2',
    signupUrl: 'https://marketstack.com/signup/free',
    docsUrl: 'https://marketstack.com/documentation_v2',
    keyParamName: 'access_key',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.strict,
    exampleEndpoint:
        'https://api.marketstack.com/v2/eod?access_key=YOUR_KEY&symbols=AAPL',
    supportsHistoric: true,
    supportsRealtime: false,
    requiresKey: true,
  );

  static const ProviderConfig _tiingo = ProviderConfig(
    id: MarketDataProvider.tiingo,
    displayName: 'Tiingo',
    baseUrl: 'https://api.tiingo.com',
    signupUrl: 'https://www.tiingo.com/account/api/token',
    docsUrl: 'https://www.tiingo.com/documentation/end-of-day',
    keyParamName: 'token',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.comfortable,
    exampleEndpoint:
        'https://api.tiingo.com/tiingo/daily/AAPL/prices?token=YOUR_KEY',
    supportsHistoric: true,
    supportsRealtime: true,
    requiresKey: true,
  );

  static const ProviderConfig _nasdaqDataLink = ProviderConfig(
    id: MarketDataProvider.nasdaqDataLink,
    displayName: 'Nasdaq Data Link',
    baseUrl: 'https://data.nasdaq.com/api/v3',
    signupUrl: 'https://data.nasdaq.com/sign-up',
    docsUrl: 'https://docs.data.nasdaq.com/',
    keyParamName: 'api_key',
    keyParamStyle: ApiKeyParamStyle.queryParam,
    refreshTier: ProviderRefreshTier.comfortable,
    exampleEndpoint:
        'https://data.nasdaq.com/api/v3/datasets/WIKI/AAPL.json?api_key=YOUR_KEY',
    supportsHistoric: true,
    supportsRealtime: false,
    requiresKey: true,
  );

  static const ProviderConfig _stooq = ProviderConfig(
    id: MarketDataProvider.stooq,
    displayName: 'Stooq',
    baseUrl: 'https://stooq.com/q/d/l',
    signupUrl: 'https://stooq.com',
    docsUrl: 'https://stooq.com/db/h/',
    keyParamName: '',
    keyParamStyle: ApiKeyParamStyle.none,
    refreshTier: ProviderRefreshTier.unlimited,
    exampleEndpoint: 'https://stooq.com/q/d/l/?s=aapl.us&i=d',
    supportsHistoric: true,
    supportsRealtime: false,
    requiresKey: false,
  );

  /// All providers in display order.
  static const List<ProviderConfig> all = [
    _eodhd,
    _fmp,
    _alphaVantage,
    _twelveData,
    _finnhub,
    _polygon,
    _marketstack,
    _tiingo,
    _nasdaqDataLink,
    _stooq,
  ];

  static ProviderConfig byId(MarketDataProvider id) {
    return all.firstWhere((p) => p.id == id);
  }

  /// Subset that requires a key (excludes Stooq).
  static List<ProviderConfig> get keyed =>
      all.where((p) => p.requiresKey).toList(growable: false);
}
