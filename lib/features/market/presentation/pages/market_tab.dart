import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../services/api/eodhd_service.dart';
import '../../../../services/api/fmp_market_service.dart';
import '../../../../services/api/market_snapshot_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../portfolio/domain/entities/portfolio_entities.dart';
import '../../../portfolio/presentation/bloc/portfolio_bloc.dart';

/// Market data model for top movers
class MarketMover {
  final String symbol;
  final String name;
  final double changePercent;
  final double price;
  final int volume;
  final String currency;
  final String? source;
  final String? asOf;
  final bool isPriceReliable;

  const MarketMover({
    required this.symbol,
    required this.name,
    required this.changePercent,
    required this.price,
    this.volume = 0,
    required this.currency,
    this.source,
    this.asOf,
    this.isPriceReliable = true,
  });

  bool get hasReliablePrice => isPriceReliable && price > 0;

  factory MarketMover.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    double parsedPrice = 0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice.replaceAll(',', '.')) ?? 0;
    }

    final rawChange = json['changePercent'];
    double parsedChange = 0;
    if (rawChange is num) {
      parsedChange = rawChange.toDouble();
    } else if (rawChange is String) {
      parsedChange = double.tryParse(rawChange.replaceAll(',', '.')) ?? 0;
    }

    final rawVolume = json['volume'];
    var parsedVolume = 0;
    if (rawVolume is num) {
      parsedVolume = rawVolume.toInt();
    } else if (rawVolume is String) {
      final sanitized = rawVolume.trim().replaceAll(',', '');
      parsedVolume = int.tryParse(sanitized) ??
          (double.tryParse(rawVolume.replaceAll(',', '.'))?.toInt() ?? 0);
    }
    if (parsedVolume < 0) {
      parsedVolume = 0;
    }

    final rawReliability =
        json['isReliable'] ?? json['reliable'] ?? json['priceReliable'];
    bool parsedReliability = parsedPrice > 0;
    if (rawReliability is bool) {
      parsedReliability = rawReliability;
    } else if (rawReliability is num) {
      parsedReliability = rawReliability > 0;
    } else if (rawReliability is String) {
      final normalized = rawReliability.trim().toLowerCase();
      parsedReliability =
          normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    final rawSource = (json['source'] as String?)?.trim();
    final rawAsOf =
        (json['asOf'] ?? json['asOfDate'] ?? json['date'])?.toString().trim();

    return MarketMover(
      symbol: (json['symbol']?.toString() ?? '').trim(),
      name: (json['name']?.toString() ?? '').trim(),
      changePercent: parsedChange,
      price: parsedPrice,
      volume: parsedVolume,
      currency: (json['currency']?.toString() ?? 'USD').trim().toUpperCase(),
      source: (rawSource == null || rawSource.isEmpty) ? null : rawSource,
      asOf: (rawAsOf == null || rawAsOf.isEmpty) ? null : rawAsOf,
      isPriceReliable: parsedReliability,
    );
  }
}

/// Latest market quote for a portfolio position
class PositionMarketPrice {
  final String symbol;
  final double price;
  final String currency;
  final String? source;
  final String? asOf;
  final bool isReliable;

  const PositionMarketPrice({
    required this.symbol,
    required this.price,
    required this.currency,
    this.source,
    this.asOf,
    this.isReliable = true,
  });

  bool get hasReliablePrice => isReliable && price > 0;

  factory PositionMarketPrice.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    double parsedPrice = 0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice.replaceAll(',', '.')) ?? 0;
    }

    final rawReliability =
        json['isReliable'] ?? json['reliable'] ?? json['priceReliable'];
    var parsedReliability = parsedPrice > 0;
    if (rawReliability is bool) {
      parsedReliability = rawReliability;
    } else if (rawReliability is num) {
      parsedReliability = rawReliability > 0;
    } else if (rawReliability is String) {
      final normalized = rawReliability.trim().toLowerCase();
      parsedReliability =
          normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    final rawSource = (json['source'] as String?)?.trim();
    final rawAsOf =
        (json['asOf'] ?? json['asOfDate'] ?? json['date'])?.toString().trim();

    return PositionMarketPrice(
      symbol: (json['symbol']?.toString() ?? '').trim(),
      price: parsedPrice,
      currency: (json['currency']?.toString() ?? '').trim().toUpperCase(),
      source: (rawSource == null || rawSource.isEmpty) ? null : rawSource,
      asOf: (rawAsOf == null || rawAsOf.isEmpty) ? null : rawAsOf,
      isReliable: parsedReliability,
    );
  }
}

class _MoverSnapshot {
  final String symbol;
  final String name;
  final double price;
  final int volume;
  final String currency;
  final String? source;

  const _MoverSnapshot({
    required this.symbol,
    required this.name,
    required this.price,
    required this.volume,
    required this.currency,
    this.source,
  });
}

class _TimeframeMovers {
  final List<MarketMover> gainers;
  final List<MarketMover> losers;

  const _TimeframeMovers({
    required this.gainers,
    required this.losers,
  });
}

enum _MarketMenuAction {
  refresh,
  analysis,
  importPortfolio,
  settings,
  help,
  managePortfolios,
}

/// Complete Market Tab implementation
class MarketTab extends StatefulWidget {
  const MarketTab({super.key});

  @override
  State<MarketTab> createState() => _MarketTabState();
}

class _MarketTabState extends State<MarketTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final EodhdService _eodhdService = EodhdService();
  final FmpMarketService _fmpService = FmpMarketService();
  final MarketSnapshotService _snapshotService = MarketSnapshotService();
  String _activeEodhdApiKey = '';
  String _activeFmpApiKey = '';
  Map<String, dynamic>? _snapshotPricesIndex;

  final Map<String, String> _marketDisplayNames = <String, String>{};
  final Map<String, List<MarketMover>> _dailyGainersByMarket =
      <String, List<MarketMover>>{};
  final Map<String, List<MarketMover>> _dailyLosersByMarket =
      <String, List<MarketMover>>{};
  final Map<String, List<MarketMover>> _weeklyGainersByMarket =
      <String, List<MarketMover>>{};
  final Map<String, List<MarketMover>> _weeklyLosersByMarket =
      <String, List<MarketMover>>{};
  final Map<String, List<MarketMover>> _monthlyGainersByMarket =
      <String, List<MarketMover>>{};
  final Map<String, List<MarketMover>> _monthlyLosersByMarket =
      <String, List<MarketMover>>{};
  final Map<String, List<MarketMover>> _yearlyGainersByMarket =
      <String, List<MarketMover>>{};
  final Map<String, List<MarketMover>> _yearlyLosersByMarket =
      <String, List<MarketMover>>{};
  List<String> _availableMarkets = <String>['US'];
  String _selectedMarket = 'US';
  bool _isUsingDistributedSnapshot = false;
  int _activeMoverMinVolume = _minimumMoverVolume;

  bool _isLoading = false;
  String? _errorMessage;
  final List<String> _fetchErrors = <String>[];

  // Market data
  List<MarketMover> _dailyGainers = [];
  List<MarketMover> _dailyLosers = [];
  List<MarketMover> _weeklyGainers = [];
  List<MarketMover> _weeklyLosers = [];
  List<MarketMover> _monthlyGainers = [];
  List<MarketMover> _monthlyLosers = [];
  List<MarketMover> _yearlyGainers = [];
  List<MarketMover> _yearlyLosers = [];

  DateTime? _lastUpdated;
  DateTime? _portfolioPricesUpdatedAt;
  int _updatedPortfolioPositionsCount = 0;
  Set<String> _unreliablePortfolioSymbols = <String>{};
  Set<String> _outlierBlockedPortfolioSymbols = <String>{};
  Map<String, String> _portfolioQuoteSources = <String, String>{};

  static const int _maxQuoteStalenessDays = 5;
  static const double _maxOutlierJumpRatio = 5.0;
  static const double _splitRatioTolerance = 0.12;
  static const int _moverUniverseSideLimit = 25;
  static const int _minimumMoverVolume = 1000000;
  static const List<String> _preferredMarketOrder = <String>[
    'US',
    'LSE',
    'XETRA',
    'PA',
    'MI',
    'TO',
    'TSE',
    'HK',
    'AU',
    'NSE',
  ];
  static const String _dailyTimeframeKey = '1D';
  static const String _weeklyTimeframeKey = '5D';
  static const String _monthlyTimeframeKey = '1M';
  static const String _yearlyTimeframeKey = '1Y';

  /// Maps common broker exchange names to EODHD market codes.
  static const Map<String, String> _exchangeToEodhdMarket = <String, String>{
    'NASDAQ': 'US',
    'NYSE': 'US',
    'AMEX': 'US',
    'BATS': 'US',
    'NYSE ARCA': 'US',
    'OTC': 'US',
    'OTCBB': 'US',
    'LSE': 'LSE',
    'LONDON': 'LSE',
    'XETRA': 'XETRA',
    'FRA': 'XETRA',
    'FSE': 'XETRA',
    'PA': 'PA',
    'EURONEXT': 'PA',
    'EPA': 'PA',
    'MI': 'MI',
    'MIL': 'MI',
    'BIT': 'MI',
    'TSX': 'TO',
    'TO': 'TO',
    'TSE': 'TSE',
    'TYO': 'TSE',
    'HKG': 'HK',
    'HK': 'HK',
    'ASX': 'AU',
    'AX': 'AU',
    'NSE': 'NSE',
    'BSE': 'NSE',
  };

  static const List<double> _commonSplitRatios = <double>[
    1.5,
    2,
    3,
    4,
    5,
    8,
    10,
    12,
    15,
    20,
    25,
    50,
    100,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _handleSettingsState(context.read<SettingsBloc>().state);
    _fetchMarketData();
  }

  double _parseFmpDouble(dynamic rawValue) {
    if (rawValue is num) {
      return rawValue.toDouble();
    }
    if (rawValue is String) {
      return double.tryParse(rawValue.replaceAll(',', '.')) ?? 0;
    }
    return 0;
  }

  int? _parseNullableInt(dynamic rawValue) {
    if (rawValue is num) {
      final value = rawValue.toInt();
      return value < 0 ? 0 : value;
    }

    if (rawValue is String) {
      final normalized = rawValue.trim();
      if (normalized.isEmpty) {
        return null;
      }

      final intCandidate = int.tryParse(normalized.replaceAll(',', ''));
      if (intCandidate != null) {
        return intCandidate < 0 ? 0 : intCandidate;
      }

      final doubleCandidate =
          double.tryParse(normalized.replaceAll(',', '.'))?.toInt();
      if (doubleCandidate != null) {
        return doubleCandidate < 0 ? 0 : doubleCandidate;
      }
    }

    return null;
  }

  String _formatVolume(int volume, {bool compact = false}) {
    final locale = context.locale.toString();
    final formatter = compact
        ? NumberFormat.compact(locale: locale)
        : NumberFormat.decimalPattern(locale);
    return formatter.format(volume);
  }

  String? _parseNullableText(dynamic rawValue) {
    final text = rawValue?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  String _fmpTimePeriodFor(String period) {
    switch (period) {
      case 'weekly':
        return _weeklyTimeframeKey;
      case 'monthly':
        return _monthlyTimeframeKey;
      case 'yearly':
        return _yearlyTimeframeKey;
      case 'daily':
      default:
        return _dailyTimeframeKey;
    }
  }

  List<MarketMover> _mapFmpMovers(
    List<Map<String, dynamic>> payload, {
    required String asOf,
    required bool isGainer,
  }) {
    final movers = <MarketMover>[];

    for (final item in payload) {
      final symbol = (item['symbol']?.toString() ?? '').trim().toUpperCase();
      if (symbol.isEmpty) {
        continue;
      }

      final volume =
          _parseNullableInt(item['volume'] ?? item['avgVolume']) ?? 0;
      if (volume < _minimumMoverVolume) {
        continue;
      }

      final rawPercent = _parseFmpDouble(
        item['changesPercentage'] ?? item['changePercent'],
      );
      final normalizedPercent = isGainer ? rawPercent.abs() : -rawPercent.abs();
      final price = _parseFmpDouble(item['price']);
      final source = _parseNullableText(item['exchange']);
      final rawName = (item['name']?.toString() ?? '').trim();

      movers.add(
        MarketMover(
          symbol: symbol,
          name: rawName.isEmpty ? symbol : rawName,
          changePercent: normalizedPercent,
          price: price,
          volume: volume,
          currency:
              ((item['currency']?.toString().trim().toUpperCase() ?? 'USD')),
          source: source,
          asOf: asOf,
          isPriceReliable: price > 0,
        ),
      );

      if (movers.length >= 20) {
        break;
      }
    }

    return movers;
  }

  String _normalizeMarketCode(String marketCode) {
    return marketCode.trim().toUpperCase();
  }

  List<String> _sortMarketCodes(Iterable<String> rawCodes) {
    final normalizedCodes = <String>{};
    for (final rawCode in rawCodes) {
      final normalized = _normalizeMarketCode(rawCode);
      if (normalized.isEmpty) {
        continue;
      }
      normalizedCodes.add(normalized);
    }

    final ordered = _preferredMarketOrder
        .where(normalizedCodes.contains)
        .toList(growable: true);

    final remaining = normalizedCodes
        .where((code) => !_preferredMarketOrder.contains(code))
        .toList(growable: true)
      ..sort();

    return <String>[...ordered, ...remaining];
  }

  void _applySelectedMarketMovers() {
    final selected = _normalizeMarketCode(_selectedMarket);
    _dailyGainers = List<MarketMover>.from(
      _dailyGainersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
    _dailyLosers = List<MarketMover>.from(
      _dailyLosersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
    _weeklyGainers = List<MarketMover>.from(
      _weeklyGainersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
    _weeklyLosers = List<MarketMover>.from(
      _weeklyLosersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
    _monthlyGainers = List<MarketMover>.from(
      _monthlyGainersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
    _monthlyLosers = List<MarketMover>.from(
      _monthlyLosersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
    _yearlyGainers = List<MarketMover>.from(
      _yearlyGainersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
    _yearlyLosers = List<MarketMover>.from(
      _yearlyLosersByMarket[selected] ?? const <MarketMover>[],
      growable: false,
    );
  }

  void _clearMarketMoverState() {
    _marketDisplayNames.clear();
    _dailyGainersByMarket.clear();
    _dailyLosersByMarket.clear();
    _weeklyGainersByMarket.clear();
    _weeklyLosersByMarket.clear();
    _monthlyGainersByMarket.clear();
    _monthlyLosersByMarket.clear();
    _yearlyGainersByMarket.clear();
    _yearlyLosersByMarket.clear();
    _availableMarkets = <String>['US'];
    _selectedMarket = 'US';
    _dailyGainers = const <MarketMover>[];
    _dailyLosers = const <MarketMover>[];
    _weeklyGainers = const <MarketMover>[];
    _weeklyLosers = const <MarketMover>[];
    _monthlyGainers = const <MarketMover>[];
    _monthlyLosers = const <MarketMover>[];
    _yearlyGainers = const <MarketMover>[];
    _yearlyLosers = const <MarketMover>[];
    _isUsingDistributedSnapshot = false;
    _activeMoverMinVolume = _minimumMoverVolume;
  }

  String _marketLabelFor(String marketCode) {
    final normalized = _normalizeMarketCode(marketCode);
    final displayName = _marketDisplayNames[normalized]?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final key = 'market.markets.${normalized.toLowerCase()}';
    final translated = key.tr();
    return translated == key ? normalized : translated;
  }

  List<MarketMover> _mapSnapshotMovers(
    dynamic payload, {
    required bool isGainer,
    required String marketCode,
    required int minVolume,
    required String fallbackAsOf,
    required String fallbackCurrency,
  }) {
    if (payload is! List) {
      return const <MarketMover>[];
    }

    final source = _marketLabelFor(marketCode);
    final movers = <MarketMover>[];
    for (final rawItem in payload.whereType<Map>()) {
      final item = Map<String, dynamic>.from(rawItem);
      final symbol = ((item['symbol'] ?? item['ticker'])?.toString() ?? '')
          .trim()
          .toUpperCase();
      if (symbol.isEmpty) {
        continue;
      }

      final rawChange = _parseFmpDouble(
        item['change_percent'] ??
            item['changePercent'] ??
            item['changesPercentage'],
      );
      final normalizedChange = isGainer ? rawChange.abs() : -rawChange.abs();
      final rawPrice = _parseFmpDouble(item['price'] ?? item['close']);
      final volume = _parseNullableInt(item['volume']) ?? 0;
      if (volume < minVolume) {
        continue;
      }
      final rawCurrency = (item['currency']?.toString().trim().toUpperCase() ??
              fallbackCurrency)
          .trim();
      final rawAsOf = _extractIsoDate(
            (item['as_of_date'] ?? item['asOfDate'] ?? item['date'])
                ?.toString(),
          ) ??
          fallbackAsOf;
      final rawName = (item['name']?.toString() ?? '').trim();

      movers.add(
        MarketMover(
          symbol: symbol,
          name: rawName.isEmpty ? symbol : rawName,
          changePercent: normalizedChange,
          price: rawPrice,
          volume: volume,
          currency: rawCurrency.isEmpty ? fallbackCurrency : rawCurrency,
          source: source,
          asOf: rawAsOf,
          isPriceReliable: rawPrice > 0,
        ),
      );
    }

    return movers.take(20).toList(growable: false);
  }

  _TimeframeMovers _parseSnapshotTimeframe(
    dynamic payload, {
    required String marketCode,
    required int minVolume,
    required String fallbackAsOf,
    required String fallbackCurrency,
  }) {
    if (payload is! Map) {
      return const _TimeframeMovers(
        gainers: <MarketMover>[],
        losers: <MarketMover>[],
      );
    }

    final timeframePayload = Map<String, dynamic>.from(payload);
    return _TimeframeMovers(
      gainers: _mapSnapshotMovers(
        timeframePayload['gainers'],
        isGainer: true,
        marketCode: marketCode,
        minVolume: minVolume,
        fallbackAsOf: fallbackAsOf,
        fallbackCurrency: fallbackCurrency,
      ),
      losers: _mapSnapshotMovers(
        timeframePayload['losers'],
        isGainer: false,
        marketCode: marketCode,
        minVolume: minVolume,
        fallbackAsOf: fallbackAsOf,
        fallbackCurrency: fallbackCurrency,
      ),
    );
  }

  Future<bool> _fetchTopMoversFromDistributedSnapshot({
    required String fallbackAsOf,
  }) async {
    if (!_snapshotService.isConfigured) {
      return false;
    }

    try {
      final payload = await _snapshotService.fetchTopMoversSnapshot();
      if (payload == null) {
        return false;
      }

      final rawFilters = payload['filters'];
      var snapshotMinVolume = _minimumMoverVolume;
      if (rawFilters is Map) {
        final filters = Map<String, dynamic>.from(rawFilters);
        snapshotMinVolume =
            _parseNullableInt(filters['min_volume'] ?? filters['minVolume']) ??
                _minimumMoverVolume;
      }

      final rawMarkets = payload['markets'];
      if (rawMarkets is! List) {
        return false;
      }

      final marketDisplayNames = <String, String>{};
      final dailyGainersByMarket = <String, List<MarketMover>>{};
      final dailyLosersByMarket = <String, List<MarketMover>>{};
      final weeklyGainersByMarket = <String, List<MarketMover>>{};
      final weeklyLosersByMarket = <String, List<MarketMover>>{};
      final monthlyGainersByMarket = <String, List<MarketMover>>{};
      final monthlyLosersByMarket = <String, List<MarketMover>>{};
      final yearlyGainersByMarket = <String, List<MarketMover>>{};
      final yearlyLosersByMarket = <String, List<MarketMover>>{};

      for (final rawMarket in rawMarkets.whereType<Map>()) {
        final market = Map<String, dynamic>.from(rawMarket);
        final marketCode = _normalizeMarketCode(
          market['code']?.toString() ?? '',
        );
        if (marketCode.isEmpty) {
          continue;
        }

        final displayName = (market['name']?.toString() ?? '').trim();
        if (displayName.isNotEmpty) {
          marketDisplayNames[marketCode] = displayName;
        }

        final fallbackCurrency =
            (market['currency']?.toString().trim().toUpperCase() ?? 'USD')
                .trim();
        final asOf = _extractIsoDate(
              (market['as_of_date'] ?? market['asOfDate'])?.toString(),
            ) ??
            fallbackAsOf;

        final rawTimeframes = market['timeframes'];
        if (rawTimeframes is! Map) {
          continue;
        }

        final timeframes = Map<String, dynamic>.from(rawTimeframes);
        final dailyMovers = _parseSnapshotTimeframe(
          timeframes[_dailyTimeframeKey],
          marketCode: marketCode,
          minVolume: snapshotMinVolume,
          fallbackAsOf: asOf,
          fallbackCurrency: fallbackCurrency,
        );
        final weeklyMovers = _parseSnapshotTimeframe(
          timeframes[_weeklyTimeframeKey],
          marketCode: marketCode,
          minVolume: snapshotMinVolume,
          fallbackAsOf: asOf,
          fallbackCurrency: fallbackCurrency,
        );
        final monthlyMovers = _parseSnapshotTimeframe(
          timeframes[_monthlyTimeframeKey],
          marketCode: marketCode,
          minVolume: snapshotMinVolume,
          fallbackAsOf: asOf,
          fallbackCurrency: fallbackCurrency,
        );
        final yearlyMovers = _parseSnapshotTimeframe(
          timeframes[_yearlyTimeframeKey],
          marketCode: marketCode,
          minVolume: snapshotMinVolume,
          fallbackAsOf: asOf,
          fallbackCurrency: fallbackCurrency,
        );

        final hasAnyMovers = dailyMovers.gainers.isNotEmpty ||
            dailyMovers.losers.isNotEmpty ||
            weeklyMovers.gainers.isNotEmpty ||
            weeklyMovers.losers.isNotEmpty ||
            monthlyMovers.gainers.isNotEmpty ||
            monthlyMovers.losers.isNotEmpty ||
            yearlyMovers.gainers.isNotEmpty ||
            yearlyMovers.losers.isNotEmpty;
        if (!hasAnyMovers) {
          continue;
        }

        dailyGainersByMarket[marketCode] = dailyMovers.gainers;
        dailyLosersByMarket[marketCode] = dailyMovers.losers;
        weeklyGainersByMarket[marketCode] = weeklyMovers.gainers;
        weeklyLosersByMarket[marketCode] = weeklyMovers.losers;
        monthlyGainersByMarket[marketCode] = monthlyMovers.gainers;
        monthlyLosersByMarket[marketCode] = monthlyMovers.losers;
        yearlyGainersByMarket[marketCode] = yearlyMovers.gainers;
        yearlyLosersByMarket[marketCode] = yearlyMovers.losers;
      }

      final discoveredMarkets = _sortMarketCodes(<String>{
        ...dailyGainersByMarket.keys,
        ...dailyLosersByMarket.keys,
        ...weeklyGainersByMarket.keys,
        ...weeklyLosersByMarket.keys,
        ...monthlyGainersByMarket.keys,
        ...monthlyLosersByMarket.keys,
        ...yearlyGainersByMarket.keys,
        ...yearlyLosersByMarket.keys,
      });
      if (discoveredMarkets.isEmpty) {
        return false;
      }

      if (!mounted) {
        return true;
      }

      setState(() {
        _isUsingDistributedSnapshot = true;
        _activeMoverMinVolume = snapshotMinVolume;
        _marketDisplayNames
          ..clear()
          ..addAll(marketDisplayNames);
        _dailyGainersByMarket
          ..clear()
          ..addAll(dailyGainersByMarket);
        _dailyLosersByMarket
          ..clear()
          ..addAll(dailyLosersByMarket);
        _weeklyGainersByMarket
          ..clear()
          ..addAll(weeklyGainersByMarket);
        _weeklyLosersByMarket
          ..clear()
          ..addAll(weeklyLosersByMarket);
        _monthlyGainersByMarket
          ..clear()
          ..addAll(monthlyGainersByMarket);
        _monthlyLosersByMarket
          ..clear()
          ..addAll(monthlyLosersByMarket);
        _yearlyGainersByMarket
          ..clear()
          ..addAll(yearlyGainersByMarket);
        _yearlyLosersByMarket
          ..clear()
          ..addAll(yearlyLosersByMarket);
        _availableMarkets = discoveredMarkets;
        if (!_availableMarkets.contains(_selectedMarket)) {
          _selectedMarket = _availableMarkets.first;
        }
        _applySelectedMarketMovers();
      });

      return true;
    } catch (e) {
      _recordFetchError('distributed snapshot movers', e);
      return false;
    }
  }

  void _recordFetchError(String scope, Object error) {
    final message = '$scope: $error';
    _fetchErrors.add(message);
    debugPrint('Market fetch error [$scope]: $error');
  }

  bool _hasAnyFetchedMarketContent() {
    return _dailyGainers.isNotEmpty ||
        _dailyLosers.isNotEmpty ||
        _weeklyGainers.isNotEmpty ||
        _weeklyLosers.isNotEmpty ||
        _monthlyGainers.isNotEmpty ||
        _monthlyLosers.isNotEmpty ||
        _yearlyGainers.isNotEmpty ||
        _yearlyLosers.isNotEmpty ||
        _updatedPortfolioPositionsCount > 0;
  }

  DateTime _referenceUtcFromIsoDate(String isoDate) {
    final parsed = DateTime.tryParse('${isoDate}T00:00:00Z');
    return (parsed ?? DateTime.now().toUtc()).toUtc();
  }

  bool _isRecentMarketDate(String? rawDate, {required DateTime referenceUtc}) {
    final isoDate = _extractIsoDate(rawDate);
    if (isoDate == null) {
      return false;
    }

    final parsedDate = DateTime.tryParse('${isoDate}T00:00:00Z');
    if (parsedDate == null) {
      return false;
    }

    final normalizedReference = DateTime.utc(
      referenceUtc.year,
      referenceUtc.month,
      referenceUtc.day,
    );
    final normalizedParsed = DateTime.utc(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );

    final diffDays = normalizedReference.difference(normalizedParsed).inDays;
    return diffDays >= -1 && diffDays <= _maxQuoteStalenessDays;
  }

  bool _isLikelySplitAdjustment(double previousPrice, double currentPrice) {
    if (previousPrice <= 0 || currentPrice <= 0) {
      return false;
    }

    final upRatio = currentPrice / previousPrice;
    final downRatio = previousPrice / currentPrice;

    for (final splitRatio in _commonSplitRatios) {
      final upDelta = (upRatio - splitRatio).abs() / splitRatio;
      if (upDelta <= _splitRatioTolerance) {
        return true;
      }

      final downDelta = (downRatio - splitRatio).abs() / splitRatio;
      if (downDelta <= _splitRatioTolerance) {
        return true;
      }
    }

    return false;
  }

  bool _isSuspiciousOutlierQuote(Position position, PositionMarketPrice quote) {
    final previousPrice = position.closePrice;
    final candidatePrice = quote.price;
    if (previousPrice <= 0 || candidatePrice <= 0) {
      return false;
    }

    final ratio = candidatePrice / previousPrice;
    final hasExtremeJump =
        ratio >= _maxOutlierJumpRatio || ratio <= (1 / _maxOutlierJumpRatio);
    if (!hasExtremeJump) {
      return false;
    }

    if (_isLikelySplitAdjustment(previousPrice, candidatePrice)) {
      return false;
    }

    return true;
  }

  PositionMarketPrice? _extractReliableQuote(
    Position position,
    List<PositionMarketPrice>? quotes, {
    String? expectedAsOfDate,
  }) {
    if (quotes == null || quotes.isEmpty) {
      return null;
    }

    final positionCurrency = position.currency.trim().toUpperCase();
    PositionMarketPrice? fallback;
    for (final quote in quotes) {
      if (!quote.hasReliablePrice) {
        continue;
      }

      if (expectedAsOfDate != null) {
        final referenceUtc = _referenceUtcFromIsoDate(expectedAsOfDate);
        final quoteAsOf = quote.asOf?.trim();
        if (quoteAsOf != null &&
            quoteAsOf.isNotEmpty &&
            !_isRecentMarketDate(quoteAsOf, referenceUtc: referenceUtc)) {
          continue;
        }
      }

      final quoteCurrency = quote.currency.trim().toUpperCase();
      if (quoteCurrency.isEmpty || quoteCurrency == positionCurrency) {
        return quote;
      }
      fallback ??= quote;
    }

    if (fallback == null) {
      return null;
    }

    if (fallback.currency.isNotEmpty &&
        fallback.currency.trim().toUpperCase() != positionCurrency) {
      return null;
    }

    return fallback;
  }

  /// Returns a composite key string used to detect changes in any market API key.
  String _extractApiKeyFromState(SettingsState state) {
    if (state is! SettingsLoaded) return '';
    final eodhd = state.settings.eodhdApiKey?.trim() ?? '';
    final fmp = state.settings.fmpApiKey?.trim() ?? '';
    return '$eodhd|$fmp';
  }

  bool _handleSettingsState(SettingsState state) {
    final composite = _extractApiKeyFromState(state);
    final prevComposite = '$_activeEodhdApiKey|$_activeFmpApiKey';
    if (composite == prevComposite) {
      return _eodhdService.hasApiKey || _fmpService.hasApiKey;
    }

    if (state is SettingsLoaded) {
      final eodhd = state.settings.eodhdApiKey?.trim() ?? '';
      final fmp = state.settings.fmpApiKey?.trim() ?? '';
      _activeEodhdApiKey = eodhd;
      _activeFmpApiKey = fmp;
      _eodhdService.setApiKey(eodhd.isEmpty ? null : eodhd);
      _fmpService.setApiKey(fmp.isEmpty ? null : fmp);
    }
    return _eodhdService.hasApiKey || _fmpService.hasApiKey;
  }

  /// Returns the EODHD market code for a position's exchange string (best-effort).
  String? _eodhdMarketForExchange(String? exchange) {
    if (exchange == null || exchange.trim().isEmpty) return null;
    return _exchangeToEodhdMarket[exchange.trim().toUpperCase()];
  }

  Future<void> _fetchMarketData() async {
    if (_isLoading) {
      return;
    }

    final hasApiKey = _handleSettingsState(context.read<SettingsBloc>().state);

    _fetchErrors.clear();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch market requests in sequence to avoid burst failures/rate limits
      await _fetchTopMoversAcrossTimeframes();

      // When no personal API key, pre-load snapshot prices index for portfolio lookup
      if (!hasApiKey && _snapshotService.isConfigured) {
        _snapshotPricesIndex = await _snapshotService.fetchPricesIndex();
      }

      await _fetchPortfolioPositionPrices();

      if (!mounted) return;
      setState(() {
        _lastUpdated = DateTime.now();
        _isLoading = false;
        if (!_hasAnyFetchedMarketContent() && _fetchErrors.isNotEmpty) {
          _errorMessage = _fetchErrors.join('\n');
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTopMoversAcrossTimeframes() async {
    final nowUtc = DateTime.now().toUtc();
    final asOf = _formatIsoDate(nowUtc);

    final loadedSnapshot = await _fetchTopMoversFromDistributedSnapshot(
      fallbackAsOf: asOf,
    );
    if (loadedSnapshot) {
      return;
    }

    if (!_fmpService.hasApiKey) {
      _recordFetchError(
        'movers',
        'Distributed market snapshot unavailable and FMP API key not configured.',
      );
      if (!mounted) return;
      setState(() {
        _clearMarketMoverState();
      });
      return;
    }

    try {
      final dailyGainersPayload = await _fmpService.fetchTopMovers(
        gainers: true,
        timePeriod: _dailyTimeframeKey,
        limit: _moverUniverseSideLimit,
      );
      final dailyLosersPayload = await _fmpService.fetchTopMovers(
        gainers: false,
        timePeriod: _dailyTimeframeKey,
        limit: _moverUniverseSideLimit,
      );

      final dailyGainers = _mapFmpMovers(
        dailyGainersPayload,
        asOf: asOf,
        isGainer: true,
      );
      final dailyLosers = _mapFmpMovers(
        dailyLosersPayload,
        asOf: asOf,
        isGainer: false,
      );

      final moverUniverse = _buildMoverUniverse(
        dailyGainersPayload,
        dailyLosersPayload,
      );
      final changesBySymbol = await _fetchChangesByTimeframe(
        moverUniverse.keys.toList(growable: false),
      );

      final weeklyMovers = await _resolveTimeframeMovers(
        universe: moverUniverse,
        changesBySymbol: changesBySymbol,
        timeframeKey: _weeklyTimeframeKey,
        legacyPeriod: 'weekly',
        asOf: asOf,
      );
      final monthlyMovers = await _resolveTimeframeMovers(
        universe: moverUniverse,
        changesBySymbol: changesBySymbol,
        timeframeKey: _monthlyTimeframeKey,
        legacyPeriod: 'monthly',
        asOf: asOf,
      );
      final yearlyMovers = await _resolveTimeframeMovers(
        universe: moverUniverse,
        changesBySymbol: changesBySymbol,
        timeframeKey: _yearlyTimeframeKey,
        legacyPeriod: 'yearly',
        asOf: asOf,
      );

      if (!mounted) return;
      setState(() {
        _isUsingDistributedSnapshot = false;
        _activeMoverMinVolume = _minimumMoverVolume;
        _marketDisplayNames
          ..clear()
          ..['US'] = _marketLabelFor('US');
        _dailyGainersByMarket
          ..clear()
          ..['US'] = dailyGainers;
        _dailyLosersByMarket
          ..clear()
          ..['US'] = dailyLosers;
        _weeklyGainersByMarket
          ..clear()
          ..['US'] = weeklyMovers.gainers;
        _weeklyLosersByMarket
          ..clear()
          ..['US'] = weeklyMovers.losers;
        _monthlyGainersByMarket
          ..clear()
          ..['US'] = monthlyMovers.gainers;
        _monthlyLosersByMarket
          ..clear()
          ..['US'] = monthlyMovers.losers;
        _yearlyGainersByMarket
          ..clear()
          ..['US'] = yearlyMovers.gainers;
        _yearlyLosersByMarket
          ..clear()
          ..['US'] = yearlyMovers.losers;
        _availableMarkets = const <String>['US'];
        _selectedMarket = 'US';
        _applySelectedMarketMovers();
      });
    } catch (e) {
      _recordFetchError('movers', e);
    }
  }

  Map<String, _MoverSnapshot> _buildMoverUniverse(
    List<Map<String, dynamic>> gainersPayload,
    List<Map<String, dynamic>> losersPayload,
  ) {
    final universe = <String, _MoverSnapshot>{};

    void upsert(Map<String, dynamic> item) {
      final symbol = (item['symbol']?.toString() ?? '').trim().toUpperCase();
      if (symbol.isEmpty) {
        return;
      }

      final volume =
          _parseNullableInt(item['volume'] ?? item['avgVolume']) ?? 0;
      if (volume < _minimumMoverVolume) {
        return;
      }

      final candidate = _MoverSnapshot(
        symbol: symbol,
        name: (item['name']?.toString() ?? '').trim().isEmpty
            ? symbol
            : (item['name']?.toString() ?? '').trim(),
        price: _parseFmpDouble(item['price']),
        volume: volume,
        currency: (item['currency']?.toString().trim().toUpperCase() ?? 'USD'),
        source: _parseNullableText(item['exchange']),
      );

      final existing = universe[symbol];
      if (existing == null) {
        universe[symbol] = candidate;
        return;
      }

      final resolvedName =
          existing.name.isEmpty ? candidate.name : existing.name;
      final resolvedPrice =
          existing.price > 0 ? existing.price : candidate.price;
      final resolvedVolume =
          existing.volume > 0 ? existing.volume : candidate.volume;
      final resolvedCurrency =
          existing.currency.isNotEmpty ? existing.currency : candidate.currency;
      final resolvedSource = existing.source ?? candidate.source;

      universe[symbol] = _MoverSnapshot(
        symbol: symbol,
        name: resolvedName,
        price: resolvedPrice,
        volume: resolvedVolume,
        currency: resolvedCurrency,
        source: resolvedSource,
      );
    }

    for (final item in gainersPayload.take(_moverUniverseSideLimit)) {
      upsert(item);
    }
    for (final item in losersPayload.take(_moverUniverseSideLimit)) {
      upsert(item);
    }

    return universe;
  }

  Future<Map<String, Map<String, double>>> _fetchChangesByTimeframe(
    List<String> symbols,
  ) async {
    final result = <String, Map<String, double>>{};
    var endpointUnavailable = false;

    for (var index = 0; index < symbols.length; index++) {
      if (endpointUnavailable) {
        break;
      }

      final symbol = symbols[index];

      try {
        final payload = await _fmpService.fetchStockPriceChange(symbol);
        if (payload == null) {
          continue;
        }

        final symbolChanges = <String, double>{};
        for (final timeframeKey in <String>[
          _dailyTimeframeKey,
          _weeklyTimeframeKey,
          _monthlyTimeframeKey,
          _yearlyTimeframeKey,
        ]) {
          if (!payload.containsKey(timeframeKey)) {
            continue;
          }
          symbolChanges[timeframeKey] = _parseFmpDouble(payload[timeframeKey]);
        }

        if (symbolChanges.isNotEmpty) {
          result[symbol] = symbolChanges;
        }
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 402 || statusCode == 403) {
          endpointUnavailable = true;
          debugPrint(
            'stock-price-change endpoint unavailable for current FMP plan '
            '(status: $statusCode).',
          );
          continue;
        }
        debugPrint('Unable to fetch stock-price-change for $symbol: $e');
      } catch (e) {
        debugPrint('Unable to fetch stock-price-change for $symbol: $e');
      }

      if (index < symbols.length - 1) {
        await Future<void>.delayed(const Duration(milliseconds: 90));
      }
    }

    return result;
  }

  Future<_TimeframeMovers> _resolveTimeframeMovers({
    required Map<String, _MoverSnapshot> universe,
    required Map<String, Map<String, double>> changesBySymbol,
    required String timeframeKey,
    required String legacyPeriod,
    required String asOf,
  }) async {
    final computed = _buildTimeframeMovers(
      universe: universe,
      changesBySymbol: changesBySymbol,
      timeframeKey: timeframeKey,
      asOf: asOf,
    );

    if (computed.gainers.isNotEmpty && computed.losers.isNotEmpty) {
      return computed;
    }

    final fallback = await _fetchTopMoversForPeriodFallback(
      period: legacyPeriod,
      asOf: asOf,
    );

    return _TimeframeMovers(
      gainers:
          computed.gainers.isNotEmpty ? computed.gainers : fallback.gainers,
      losers: computed.losers.isNotEmpty ? computed.losers : fallback.losers,
    );
  }

  _TimeframeMovers _buildTimeframeMovers({
    required Map<String, _MoverSnapshot> universe,
    required Map<String, Map<String, double>> changesBySymbol,
    required String timeframeKey,
    required String asOf,
  }) {
    final gainers = <MarketMover>[];
    final losers = <MarketMover>[];

    for (final entry in universe.entries) {
      final symbol = entry.key;
      final snapshot = entry.value;
      final symbolChanges = changesBySymbol[symbol];
      if (symbolChanges == null || !symbolChanges.containsKey(timeframeKey)) {
        continue;
      }

      final changePercent = symbolChanges[timeframeKey] ?? 0;
      final mover = MarketMover(
        symbol: symbol,
        name: snapshot.name,
        changePercent: changePercent,
        price: snapshot.price,
        volume: snapshot.volume,
        currency: snapshot.currency,
        source: snapshot.source,
        asOf: asOf,
        isPriceReliable: snapshot.price > 0,
      );

      if (changePercent >= 0) {
        gainers.add(mover);
      } else {
        losers.add(mover);
      }
    }

    gainers.sort((a, b) => b.changePercent.compareTo(a.changePercent));
    losers.sort((a, b) => a.changePercent.compareTo(b.changePercent));

    return _TimeframeMovers(
      gainers: gainers.take(20).toList(growable: false),
      losers: losers.take(20).toList(growable: false),
    );
  }

  Future<_TimeframeMovers> _fetchTopMoversForPeriodFallback({
    required String period,
    required String asOf,
  }) async {
    final timePeriod = _fmpTimePeriodFor(period);

    try {
      final gainersPayload = await _fmpService.fetchTopMovers(
        gainers: true,
        timePeriod: timePeriod,
        limit: 20,
      );
      final losersPayload = await _fmpService.fetchTopMovers(
        gainers: false,
        timePeriod: timePeriod,
        limit: 20,
      );

      return _TimeframeMovers(
        gainers: _mapFmpMovers(
          gainersPayload,
          asOf: asOf,
          isGainer: true,
        ),
        losers: _mapFmpMovers(
          losersPayload,
          asOf: asOf,
          isGainer: false,
        ),
      );
    } catch (e) {
      _recordFetchError('$period movers fallback', e);
      return const _TimeframeMovers(
        gainers: <MarketMover>[],
        losers: <MarketMover>[],
      );
    }
  }

  Future<void> _fetchPortfolioPositionPrices() async {
    final portfolioBloc = context.read<PortfolioBloc>();
    final portfolioState = portfolioBloc.state;
    if (portfolioState is! PortfolioLoaded) {
      return;
    }

    final portfolio = portfolioState.portfolio;
    if (portfolio.positions.isEmpty) {
      if (!mounted) return;
      setState(() {
        _portfolioPricesUpdatedAt = DateTime.now();
        _updatedPortfolioPositionsCount = 0;
        _unreliablePortfolioSymbols = <String>{};
        _outlierBlockedPortfolioSymbols = <String>{};
        _portfolioQuoteSources = <String, String>{};
      });
      return;
    }

    final positionsToUpdate = portfolio.positions
        .where((position) => !_isLiquidityPosition(position))
        .toList();

    if (positionsToUpdate.isEmpty) {
      if (!mounted) return;
      setState(() {
        _portfolioPricesUpdatedAt = DateTime.now();
        _updatedPortfolioPositionsCount = 0;
        _unreliablePortfolioSymbols = <String>{};
        _outlierBlockedPortfolioSymbols = <String>{};
        _portfolioQuoteSources = <String, String>{};
      });
      return;
    }

    try {
      final quotes = await _fetchCurrentPricesForPositions(positionsToUpdate);

      final now = DateTime.now();
      final expectedQuoteDate = _formatIsoDate(now.toUtc());
      final requestedSymbols = positionsToUpdate
          .map((position) => position.symbol.trim().toUpperCase())
          .where((symbol) => symbol.isNotEmpty)
          .toSet();

      if (quotes.isEmpty) {
        if (!mounted) return;
        setState(() {
          _portfolioPricesUpdatedAt = now;
          _updatedPortfolioPositionsCount = 0;
          _unreliablePortfolioSymbols = requestedSymbols;
          _outlierBlockedPortfolioSymbols = <String>{};
          _portfolioQuoteSources = <String, String>{};
        });
        return;
      }

      final quotesBySymbol = <String, List<PositionMarketPrice>>{};
      for (final quote in quotes) {
        final symbol = quote.symbol.trim().toUpperCase();
        if (symbol.isEmpty) continue;
        quotesBySymbol.putIfAbsent(symbol, () => []).add(quote);
      }

      final unreliableSymbols = <String>{};
      final blockedOutlierSymbols = <String>{};
      final quoteSources = <String, String>{};
      for (final position in positionsToUpdate) {
        final symbol = position.symbol.trim().toUpperCase();
        if (symbol.isEmpty) continue;

        final selectedQuote = _extractReliableQuote(
          position,
          quotesBySymbol[symbol],
          expectedAsOfDate: expectedQuoteDate,
        );
        if (selectedQuote == null) {
          unreliableSymbols.add(symbol);
          continue;
        }

        if (_isSuspiciousOutlierQuote(position, selectedQuote)) {
          unreliableSymbols.add(symbol);
          blockedOutlierSymbols.add(symbol);
          debugPrint(
            'Blocked suspicious quote for $symbol: '
            'old=${position.closePrice.toStringAsFixed(4)}, '
            'new=${selectedQuote.price.toStringAsFixed(4)}, '
            'source=${selectedQuote.source ?? 'n/a'}',
          );
          continue;
        }

        final source = selectedQuote.source?.trim();
        if (source != null && source.isNotEmpty) {
          quoteSources[symbol] = source;
        }
      }

      var updatedCount = 0;
      final updatedPositions = portfolio.positions.map((position) {
        if (_isLiquidityPosition(position)) {
          return position;
        }

        final symbol = position.symbol.trim().toUpperCase();
        final selectedQuote = _extractReliableQuote(
          position,
          quotesBySymbol[symbol],
          expectedAsOfDate: expectedQuoteDate,
        );
        if (selectedQuote == null) {
          return position;
        }

        if (_isSuspiciousOutlierQuote(position, selectedQuote)) {
          return position;
        }

        final updatedValue = position.quantity * selectedQuote.price;
        final updatedPnL = updatedValue - position.costBasis;
        final priceChanged =
            (position.closePrice - selectedQuote.price).abs() > 0.0001;
        final valueChanged = (position.value - updatedValue).abs() > 0.0001;

        if (!priceChanged && !valueChanged) {
          return position;
        }

        updatedCount += 1;
        return position.copyWith(
          closePrice: selectedQuote.price,
          value: updatedValue,
          unrealizedPnL: updatedPnL,
          lastUpdated: now,
        );
      }).toList();

      if (updatedCount == 0) {
        if (!mounted) return;
        setState(() {
          _portfolioPricesUpdatedAt = now;
          _updatedPortfolioPositionsCount = 0;
          _unreliablePortfolioSymbols = unreliableSymbols;
          _outlierBlockedPortfolioSymbols = blockedOutlierSymbols;
          _portfolioQuoteSources = quoteSources;
        });
        return;
      }

      final updatedPortfolio = portfolio.copyWith(
        positions: updatedPositions,
        lastUpdated: now,
      );

      portfolioBloc.add(UpdatePortfolioEvent(updatedPortfolio));

      if (!mounted) return;
      setState(() {
        _portfolioPricesUpdatedAt = now;
        _updatedPortfolioPositionsCount = updatedCount;
        _unreliablePortfolioSymbols = unreliableSymbols;
        _outlierBlockedPortfolioSymbols = blockedOutlierSymbols;
        _portfolioQuoteSources = quoteSources;
      });
    } catch (e) {
      _recordFetchError('portfolio prices', e);
    }
  }

  Future<List<PositionMarketPrice>> _fetchCurrentPricesForPositions(
    List<Position> positions,
  ) async {
    final deduplicatedPositions = <String, Position>{};
    for (final position in positions) {
      final symbol = position.symbol.trim().toUpperCase();
      if (symbol.isEmpty) continue;
      deduplicatedPositions[symbol] = position;
    }

    final entries = deduplicatedPositions.entries.toList(growable: false);
    final quotes = <PositionMarketPrice>[];
    final isoDate = _formatIsoDate(DateTime.now().toUtc());

    // ── Hybrid Key logic ──────────────────────────────────────────────────────
    // Priority: EODHD personal key > FMP personal key > snapshot prices_index
    // ─────────────────────────────────────────────────────────────────────────

    if (_eodhdService.hasApiKey) {
      // Path A: direct EODHD real-time quotes
      for (var index = 0; index < entries.length; index++) {
        final symbol = entries[index].key;
        final position = entries[index].value;
        final eodhdMarket = _eodhdMarketForExchange(position.exchange) ?? 'US';
        try {
          final data = await _eodhdService.fetchBestQuote(symbol, eodhdMarket);
          final rawPrice =
              data?['close'] ?? data?['last'] ?? data?['adjusted_close'];
          final price = _parseFmpDouble(rawPrice);
          quotes.add(PositionMarketPrice(
            symbol: symbol,
            price: price,
            currency: position.currency.trim().toUpperCase(),
            source: 'EODHD',
            asOf: isoDate,
            isReliable: price > 0,
          ));
        } catch (e) {
          _recordFetchError('EODHD quote $symbol', e);
          quotes.add(PositionMarketPrice(
            symbol: symbol,
            price: 0,
            currency: position.currency.trim().toUpperCase(),
            source: 'EODHD',
            asOf: isoDate,
            isReliable: false,
          ));
        }
        if (index < entries.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      }
      return quotes;
    }

    if (_fmpService.hasApiKey) {
      // Path B: FMP quote-short
      for (var index = 0; index < entries.length; index++) {
        final symbol = entries[index].key;
        final position = entries[index].value;
        try {
          final quotePayload = await _fmpService.fetchQuoteShort(symbol);
          final price = _parseFmpDouble(quotePayload?['price']);
          quotes.add(PositionMarketPrice(
            symbol: symbol,
            price: price,
            currency: position.currency.trim().toUpperCase(),
            source: 'FMP',
            asOf: isoDate,
            isReliable: price > 0,
          ));
        } catch (e) {
          _recordFetchError('FMP quote $symbol', e);
          quotes.add(PositionMarketPrice(
            symbol: symbol,
            price: 0,
            currency: position.currency.trim().toUpperCase(),
            source: 'FMP',
            asOf: isoDate,
            isReliable: false,
          ));
        }
        if (index < entries.length - 1) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
      }
      return quotes;
    }

    // Path C: snapshot prices_index (no personal API key required)
    final pricesIndex = _snapshotPricesIndex;
    if (pricesIndex != null && pricesIndex.isNotEmpty) {
      for (final entry in entries) {
        final symbol = entry.key;
        final position = entry.value;
        final eodhdMarket = _eodhdMarketForExchange(position.exchange);
        final snapshotEntry = _snapshotService.lookupPrice(
          pricesIndex,
          ticker: symbol,
          marketCode: eodhdMarket,
        );
        double price = 0;
        String snapshotDate = isoDate;
        if (snapshotEntry != null) {
          price = _parseFmpDouble(snapshotEntry['c']);
          snapshotDate = (snapshotEntry['d'] as String?) ?? isoDate;
        }
        quotes.add(PositionMarketPrice(
          symbol: symbol,
          price: price,
          currency: position.currency.trim().toUpperCase(),
          source: 'snapshot',
          asOf: snapshotDate,
          isReliable: price > 0,
        ));
      }
      return quotes;
    }

    return quotes;
  }

  bool _isLiquidityPosition(Position position) {
    final assetType = position.assetType.toLowerCase();
    final symbol = position.symbol.toLowerCase();
    final name = position.name.toLowerCase();

    return assetType.contains('cash') ||
        assetType.contains('forex') ||
        symbol == 'cash' ||
        name.contains('cash') ||
        name.contains('liquid');
  }

  String? _extractIsoDate(String? rawDate) {
    if (rawDate == null) {
      return null;
    }

    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final match = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(trimmed);
    return match?.group(1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final portfolioState = context.watch<PortfolioBloc>().state;

    return BlocListener<SettingsBloc, SettingsState>(
      listenWhen: (previous, current) =>
          _extractApiKeyFromState(previous) != _extractApiKeyFromState(current),
      listener: (context, state) {
        _handleSettingsState(state);
        _fetchMarketData();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('market.title'.tr()),
          actions: _buildAppBarActions(context, portfolioState),
        ),
        body: _buildBody(portfolioState: portfolioState),
      ),
    );
  }

  List<Widget> _buildAppBarActions(
      BuildContext context, PortfolioState portfolioState) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    if (!isCompact) {
      return [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isLoading ? null : _fetchMarketData,
          tooltip: 'market.refresh'.tr(),
        ),
        IconButton(
          icon: const Icon(Icons.auto_awesome),
          tooltip: 'navigation.analysis'.tr(),
          onPressed: () => context.push(RouteNames.analysis),
        ),
        IconButton(
          icon: const Icon(Icons.upload_file),
          tooltip: 'portfolio.import_portfolio'.tr(),
          onPressed: () => context.push('${RouteNames.home}/import'),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'navigation.settings'.tr(),
          onPressed: () => context.push(RouteNames.settings),
        ),
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: 'common.help'.tr(),
          onPressed: () => context.push(RouteNames.guide),
        ),
        if (portfolioState is PortfolioLoaded)
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'portfolio.manage_portfolios'.tr(),
            onPressed: () => _showPortfolioManager(context, portfolioState),
          ),
      ];
    }

    return [
      PopupMenuButton<_MarketMenuAction>(
        icon: const Icon(Icons.menu),
        onSelected: (action) {
          switch (action) {
            case _MarketMenuAction.refresh:
              if (!_isLoading) {
                _fetchMarketData();
              }
              break;
            case _MarketMenuAction.analysis:
              context.push(RouteNames.analysis);
              break;
            case _MarketMenuAction.importPortfolio:
              context.push('${RouteNames.home}/import');
              break;
            case _MarketMenuAction.settings:
              context.push(RouteNames.settings);
              break;
            case _MarketMenuAction.help:
              context.push(RouteNames.guide);
              break;
            case _MarketMenuAction.managePortfolios:
              if (portfolioState is PortfolioLoaded) {
                _showPortfolioManager(context, portfolioState);
              }
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: _MarketMenuAction.refresh,
            enabled: !_isLoading,
            child: _buildMenuItem(
              context,
              Icons.refresh,
              'market.refresh'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _MarketMenuAction.analysis,
            child: _buildMenuItem(
              context,
              Icons.auto_awesome,
              'navigation.analysis'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _MarketMenuAction.importPortfolio,
            child: _buildMenuItem(
              context,
              Icons.upload_file,
              'portfolio.import_portfolio'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _MarketMenuAction.settings,
            child: _buildMenuItem(
              context,
              Icons.settings,
              'navigation.settings'.tr(),
            ),
          ),
          PopupMenuItem(
            value: _MarketMenuAction.help,
            child: _buildMenuItem(
              context,
              Icons.help_outline,
              'common.help'.tr(),
            ),
          ),
          if (portfolioState is PortfolioLoaded)
            PopupMenuItem(
              value: _MarketMenuAction.managePortfolios,
              child: _buildMenuItem(
                context,
                Icons.folder_open,
                'portfolio.manage_portfolios'.tr(),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 20.w),
        SizedBox(width: 12.w),
        Text(label),
      ],
    );
  }

  Widget _buildMarketSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: _availableMarkets.map((marketCode) {
          final isSelected = marketCode == _selectedMarket;
          return ChoiceChip(
            label: Text(_marketLabelFor(marketCode)),
            selected: isSelected,
            onSelected: (_) {
              if (isSelected) {
                return;
              }
              setState(() {
                _selectedMarket = marketCode;
                _applySelectedMarketMovers();
              });
            },
          );
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildBody({
    required PortfolioState portfolioState,
  }) {
    final hasPortfolioPositions = portfolioState is PortfolioLoaded &&
        portfolioState.portfolio.positions.isNotEmpty;

    if (_isLoading &&
        _dailyGainers.isEmpty &&
        _dailyLosers.isEmpty &&
        !hasPortfolioPositions) {
      return _buildCenteredScrollView(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null &&
        _dailyGainers.isEmpty &&
        _dailyLosers.isEmpty &&
        !hasPortfolioPositions) {
      return _buildError();
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          elevation: 1,
          child: Padding(
            padding: EdgeInsets.only(top: 6.h, bottom: 8.h),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.label,
              dividerHeight: 1,
              labelStyle: theme.textTheme.titleSmall?.copyWith(height: 1.2),
              unselectedLabelStyle:
                  theme.textTheme.titleSmall?.copyWith(height: 1.2),
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              tabs: [
                Tab(text: 'market.timeframes.today'.tr()),
                Tab(text: 'market.timeframes.week'.tr()),
                Tab(text: 'market.timeframes.month'.tr()),
                Tab(text: 'market.timeframes.year'.tr()),
              ],
            ),
          ),
        ),
        if (_lastUpdated != null)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14.w,
                  color: theme.textTheme.bodySmall?.color,
                ),
                SizedBox(width: 4.w),
                Text(
                  'market.updated'.tr(
                    namedArgs: {'time': _formatDateTime(_lastUpdated!)},
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                if (_isUsingDistributedSnapshot) ...[
                  SizedBox(width: 8.w),
                  Flexible(
                    child: Text(
                      'market.snapshot_source'.tr(),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (_isLoading) ...[
                  SizedBox(width: 8.w),
                  SizedBox(
                    width: 12.w,
                    height: 12.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
        if (_availableMarkets.length > 1)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            child: _buildMarketSelector(),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTodayTab(portfolioState),
              _buildMoversTab(_weeklyGainers, _weeklyLosers),
              _buildMoversTab(_monthlyGainers, _monthlyLosers),
              _buildMoversTab(_yearlyGainers, _yearlyLosers),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayTab(PortfolioState portfolioState) {
    final hasMovers = _dailyGainers.isNotEmpty || _dailyLosers.isNotEmpty;
    return RefreshIndicator(
      onRefresh: _fetchMarketData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPortfolioLiveSection(portfolioState),
            SizedBox(height: 24.h),
            if (hasMovers) ...[
              _buildMoverSection(
                title: 'market.top_gainers'.tr(),
                movers: _dailyGainers,
                isGainer: true,
              ),
              SizedBox(height: 24.h),
              _buildMoverSection(
                title: 'market.top_losers'.tr(),
                movers: _dailyLosers,
                isGainer: false,
              ),
            ] else
              Card(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 20.w,
                        color: Theme.of(context).disabledColor,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'market.no_data'.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredScrollView({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }

  Widget _buildPortfolioLiveSection(PortfolioState portfolioState) {
    if (portfolioState is! PortfolioLoaded) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            'market.portfolio_not_loaded'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final portfolio = portfolioState.portfolio;
    if (portfolio.positions.isEmpty) {
      return Card(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Text(
            'market.no_positions'.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final positions = List<Position>.from(portfolio.positions)
      ..sort((a, b) => b.valueInBaseCurrency.compareTo(a.valueInBaseCurrency));
    final syncTime = _portfolioPricesUpdatedAt ?? portfolio.lastUpdated;
    final bool hasAnyApiKey = _eodhdService.hasApiKey || _fmpService.hasApiKey;
    final String portfolioSubtitleKey;
    if (hasAnyApiKey) {
      portfolioSubtitleKey = 'market.portfolio_live_subtitle';
    } else if (_snapshotPricesIndex != null &&
        _snapshotPricesIndex!.isNotEmpty) {
      portfolioSubtitleKey = 'market.portfolio_live_subtitle_snapshot';
    } else {
      portfolioSubtitleKey = 'market.portfolio_live_subtitle_no_key';
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'market.portfolio_live_title'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 4.h),
            Text(
              portfolioSubtitleKey.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!hasAnyApiKey) ...[
              SizedBox(height: 8.h),
              Text(
                'market.portfolio_live_optional_key_hint'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SizedBox(height: 4.h),
              TextButton.icon(
                onPressed: () => context.push(RouteNames.settings),
                icon: const Icon(Icons.settings_outlined),
                label: Text('common.settings'.tr()),
              ),
            ],
            SizedBox(height: 12.h),
            Text(
              'portfolio.total_value'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 4.h),
            Text(
              '${portfolio.baseCurrency} ${portfolio.totalValue.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 4.h),
            Text(
              'market.cash_included'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (syncTime != null) ...[
              SizedBox(height: 8.h),
              Text(
                'market.updated'.tr(
                  namedArgs: {'time': _formatDateTime(syncTime)},
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_updatedPortfolioPositionsCount > 0) ...[
              SizedBox(height: 4.h),
              Text(
                'market.updated_positions'.tr(
                  namedArgs: {
                    'count': _updatedPortfolioPositionsCount.toString(),
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            SizedBox(height: 12.h),
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: positions.length <= 6,
                title: Text(
                  'market.live_positions'.tr(),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                subtitle: Text(
                  (positions.length == 1
                          ? 'portfolio.position_count_one'
                          : 'portfolio.position_count_other')
                      .tr(namedArgs: {'count': positions.length.toString()}),
                ),
                children: positions
                    .map((position) => _buildPortfolioPositionTile(
                          portfolio.baseCurrency,
                          position,
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioPositionTile(String baseCurrency, Position position) {
    final symbolKey = position.symbol.trim().toUpperCase();
    final isOutlierBlocked =
        _outlierBlockedPortfolioSymbols.contains(symbolKey);
    final isPriceUnreliable = _unreliablePortfolioSymbols.contains(symbolKey);
    final source = _portfolioQuoteSources[symbolKey];

    final normalizedBaseCurrency = baseCurrency.trim().toUpperCase();
    final normalizedPositionCurrency = position.currency.trim().toUpperCase();
    final isDuplicatedValueLine =
        normalizedBaseCurrency == normalizedPositionCurrency &&
            (position.valueInBaseCurrency - position.closePrice).abs() < 0.01;

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${position.name} - ${'portfolio.position.quantity'.tr()}: ${position.quantity.toStringAsFixed(4)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (isOutlierBlocked) ...[
          const SizedBox(height: 4),
          _buildStatusBadge(
            'market.badges.outlier_blocked'.tr(),
            AppTheme.warningColor,
          ),
        ] else if (isPriceUnreliable) ...[
          const SizedBox(height: 4),
          _buildStatusBadge(
            'market.badges.source_price_not_found'.tr(),
            AppTheme.warningColor,
          ),
        ] else if (source != null && source.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'market.badges.source'.tr(namedArgs: {'source': source}),
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    final prices = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildAdaptivePriceText(
          '${position.currency} ${position.closePrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (!isDuplicatedValueLine) ...[
          const SizedBox(height: 2),
          _buildAdaptivePriceText(
            '$baseCurrency ${position.valueInBaseCurrency.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  position.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                details,
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: prices,
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    details,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 120, maxWidth: 220),
                child: prices,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return _buildCenteredScrollView(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64.w,
              color: AppTheme.errorColor,
            ),
            SizedBox(height: 16.h),
            Text(
              'common.error'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8.h),
            Text(
              _errorMessage ?? 'errors.generic'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: _fetchMarketData,
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoversTab(List<MarketMover> gainers, List<MarketMover> losers) {
    if (gainers.isEmpty && losers.isEmpty) {
      return _buildCenteredScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.show_chart,
              size: 48.w,
              color: Theme.of(context).disabledColor,
            ),
            SizedBox(height: 8.h),
            Text(
              'market.no_data'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: _fetchMarketData,
              child: Text('common.retry'.tr()),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchMarketData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'market.mover_volume_filter'.tr(
                namedArgs: {
                  'volume': _formatVolume(_activeMoverMinVolume),
                },
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 12.h),
            _buildMoverSection(
              title: 'market.top_gainers'.tr(),
              movers: gainers,
              isGainer: true,
            ),
            SizedBox(height: 24.h),
            _buildMoverSection(
              title: 'market.top_losers'.tr(),
              movers: losers,
              isGainer: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoverSection({
    required String title,
    required List<MarketMover> movers,
    required bool isGainer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isGainer ? Icons.trending_up : Icons.trending_down,
              color: isGainer ? AppTheme.profitColor : AppTheme.lossColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isGainer ? AppTheme.profitColor : AppTheme.lossColor,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...movers.map((mover) => _buildMoverCard(mover, isGainer)),
      ],
    );
  }

  Widget _buildMoverCard(MarketMover mover, bool isGainer) {
    final toneColor = isGainer ? AppTheme.profitColor : AppTheme.lossColor;
    final hasReliablePrice = mover.hasReliablePrice;
    final symbolInitial = mover.symbol.trim().isNotEmpty
        ? mover.symbol.trim().substring(0, 1).toUpperCase()
        : '?';

    final priceLabel = hasReliablePrice
        ? '${mover.currency} ${mover.price.toStringAsFixed(2)}'
        : 'market.price_unavailable'.tr();
    final volumeLabel = 'market.mover_volume'.tr(
      namedArgs: {'volume': _formatVolume(mover.volume, compact: true)},
    );

    final changeLabel =
        '${mover.changePercent >= 0 ? '+' : ''}${mover.changePercent.toStringAsFixed(2)}%';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;

            final avatar = Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  symbolInitial,
                  style: TextStyle(
                    color: toneColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    height: 1,
                  ),
                ),
              ),
            );

            final details = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mover.symbol,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  mover.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  volumeLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!hasReliablePrice) ...[
                  const SizedBox(height: 4),
                  _buildStatusBadge(
                    'market.badges.source_price_not_found'.tr(),
                    AppTheme.warningColor,
                  ),
                ],
              ],
            );

            final changeChip = Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                changeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: toneColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.1,
                ),
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      avatar,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _buildAdaptivePriceText(
                          priceLabel,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      changeChip,
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(child: details),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints:
                      const BoxConstraints(minWidth: 120, maxWidth: 220),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildAdaptivePriceText(
                        priceLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      changeChip,
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAdaptivePriceText(String text, {TextStyle? style}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidget = Text(
          text,
          style: style,
          textAlign: TextAlign.right,
          maxLines: 1,
          softWrap: false,
        );

        if (!constraints.hasBoundedWidth) {
          return textWidget;
        }

        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: textWidget,
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  void _showPortfolioManager(BuildContext context, PortfolioLoaded state) {
    final portfolios = [...state.allPortfolios];
    final currentId = state.portfolio.id;
    if (portfolios.every((p) => p.id != currentId)) {
      portfolios.add(state.portfolio);
    }
    portfolios.sort((a, b) {
      if (a.id == currentId) return -1;
      if (b.id == currentId) return 1;
      return a.accountName.compareTo(b.accountName);
    });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'portfolio.manage_portfolios'.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 12.h),
                    ...portfolios.map((portfolio) {
                      final isCurrent = portfolio.id == currentId;
                      final displayName = portfolio.accountName.isNotEmpty
                          ? portfolio.accountName
                          : portfolio.accountId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(displayName),
                        leading: Icon(
                          isCurrent
                              ? Icons.check_circle
                              : Icons.account_balance_wallet,
                          color:
                              isCurrent ? Theme.of(context).primaryColor : null,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'portfolio.rename_portfolio'.tr(),
                          onPressed: () =>
                              _showRenameDialog(context, portfolio),
                        ),
                        onTap: () {
                          context.read<PortfolioBloc>().add(
                                SelectPortfolioEvent(portfolio.id),
                              );
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    }),
                    SizedBox(height: 12.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          context.push('${RouteNames.home}/create-portfolio');
                        },
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: Text('portfolio.create_portfolio'.tr()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(BuildContext context, Portfolio portfolio) {
    final controller = TextEditingController(
      text: portfolio.accountName.isNotEmpty
          ? portfolio.accountName
          : portfolio.accountId,
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('portfolio.rename_portfolio'.tr()),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'portfolio.portfolio_name'.tr(),
              hintText: 'portfolio.portfolio_name_hint'.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                context.read<PortfolioBloc>().add(
                      RenamePortfolioEvent(
                        portfolioId: portfolio.id,
                        name: name,
                      ),
                    );
                Navigator.of(dialogContext).pop();
              },
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    );
  }

  String _formatIsoDate(DateTime date) {
    final utcDate = date.toUtc();
    return '${utcDate.year}-${utcDate.month.toString().padLeft(2, '0')}-${utcDate.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'market.time.just_now'.tr();
    } else if (difference.inMinutes < 60) {
      return 'market.time.minutes_ago'.tr(
        namedArgs: {'count': difference.inMinutes.toString()},
      );
    } else if (difference.inHours < 24) {
      return 'market.time.hours_ago'.tr(
        namedArgs: {'count': difference.inHours.toString()},
      );
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
