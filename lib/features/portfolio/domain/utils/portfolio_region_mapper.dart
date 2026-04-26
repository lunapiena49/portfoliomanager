import '../entities/portfolio_entities.dart';

class PortfolioRegionMapper {
  PortfolioRegionMapper._();

  static const String auto = 'auto';
  static const String unitedStates = 'us';
  static const String europe = 'europe';
  static const String asia = 'asia';
  static const String restOfWorld = 'rest_world';
  static const String liquidity = 'liquidity';
  static const String commodities = 'commodities';
  static const String unassigned = 'unassigned';

  static const List<String> regionCodes = [
    unitedStates,
    europe,
    asia,
    restOfWorld,
    liquidity,
    commodities,
    unassigned,
  ];

  static const List<String> selectableCodes = [
    auto,
    unitedStates,
    europe,
    asia,
    restOfWorld,
    liquidity,
    commodities,
    unassigned,
  ];

  static String resolveRegionCode(Position position) {
    final override = _normalizeOverride(position.regionOverride);
    if (override != null) {
      return override;
    }

    final symbol = position.symbol.toLowerCase();
    final name = position.name.toLowerCase();
    final assetType = position.assetType.toLowerCase();
    final sector = position.sector.toLowerCase();
    final currency = position.currency.toUpperCase();
    final exchange = (position.exchange ?? '').toUpperCase();

    if (assetType.contains('cash') || symbol == 'cash') {
      return liquidity;
    }

    if (assetType.contains('commod')) {
      return commodities;
    }

    if (sector.contains('broad') ||
        _wordMatch(name, 'world') ||
        _wordMatch(name, 'global') ||
        name.contains('all world') ||
        name.contains('all-world') ||
        _wordMatch(name, 'acwi') ||
        name.contains('msci world')) {
      return unassigned;
    }

    if (currency == 'USD' ||
        exchange.contains('NYSE') ||
        exchange.contains('NASDAQ')) {
      return unitedStates;
    }

    if (_europeCurrencies.contains(currency) ||
        exchange.contains('LSE') ||
        exchange.contains('XETRA') ||
        exchange.contains('EURONEXT') ||
        exchange.contains('FWB')) {
      return europe;
    }

    if (_asiaCurrencies.contains(currency) ||
        exchange.contains('TSE') ||
        exchange.contains('HKEX') ||
        exchange.contains('SSE') ||
        exchange.contains('SZSE')) {
      return asia;
    }

    return restOfWorld;
  }

  static int colorForRegion(String regionCode) {
    switch (regionCode) {
      case unitedStates:
        return 0xFF2196F3;
      case europe:
        return 0xFF4CAF50;
      case asia:
        return 0xFFFF9800;
      case restOfWorld:
        return 0xFFE91E63;
      case liquidity:
        return 0xFF607D8B;
      case commodities:
        return 0xFFFF5722;
      case unassigned:
      default:
        return 0xFF9E9E9E;
    }
  }

  static bool _wordMatch(String haystack, String needle) {
    if (needle.isEmpty || haystack.isEmpty) return false;
    final pattern = RegExp(
      '\\b${RegExp.escape(needle)}\\b',
      caseSensitive: false,
    );
    return pattern.hasMatch(haystack);
  }

  static String? _normalizeOverride(String? override) {
    if (override == null) {
      return null;
    }
    final normalized = override.trim().toLowerCase();
    if (normalized.isEmpty || normalized == auto) {
      return null;
    }
    return regionCodes.contains(normalized) ? normalized : null;
  }

  static const Set<String> _europeCurrencies = {
    'EUR',
    'GBP',
    'CHF',
    'SEK',
    'NOK',
    'DKK',
    'PLN',
  };

  static const Set<String> _asiaCurrencies = {
    'JPY',
    'CNY',
    'CNH',
    'HKD',
    'SGD',
    'KRW',
    'INR',
    'TWD',
    'THB',
    'MYR',
    'IDR',
    'PHP',
    'VND',
  };
}
