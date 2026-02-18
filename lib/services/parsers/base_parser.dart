import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

import '../../features/portfolio/domain/entities/portfolio_entities.dart';

/// Base abstract class for all broker CSV parsers
/// Provides common utilities and defines the interface
abstract class BaseBrokerParser {
  static const uuid = Uuid();

  /// Parse CSV content and return a Portfolio object
  Portfolio parse(String csvContent);

  /// Broker identifier (lowercase, underscore-separated)
  String get brokerId;

  /// Broker display name for UI
  String get brokerName;

  /// Supported file extensions
  List<String> get supportedExtensions => ['csv'];

  /// Base currency for this broker (default)
  String get defaultCurrency => 'USD';

  // ==================== PARSING UTILITIES ====================

  /// Convert CSV content to list of lists with comma delimiter
  static List<List<dynamic>> parseCSV(
    String content, {
    String fieldDelimiter = ',',
    String eol = '\n',
  }) {
    // Remove BOM if present (Fidelity uses UTF-8 BOM)
    var cleanContent = content;
    if (cleanContent.startsWith('\uFEFF')) {
      cleanContent = cleanContent.substring(1);
    }

    // Normalize line endings
    cleanContent = cleanContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    return CsvToListConverter(
      eol: eol,
      fieldDelimiter: fieldDelimiter,
      shouldParseNumbers: false,
    ).convert(cleanContent);
  }

  /// Safely parse double from various formats
  static double parseDoubleSafe(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;

    var str = value.toString().trim();
    if (str.isEmpty || str == '-' || str == 'N/A' || str == '--' || str == 'n/a') {
      return defaultValue;
    }

    // Handle parentheses for negative numbers: ($43.64) -> -43.64
    final isNegativeParens = str.startsWith('(') && str.endsWith(')');
    if (isNegativeParens) {
      str = '-${str.substring(1, str.length - 1)}';
    }

    // Remove currency symbols, formatting chars
    final cleaned = str
        .replaceAll(RegExp(r'[,\s]'), '')
        .replaceAll('\$', '')
        .replaceAll('EUR', '')
        .replaceAll('USD', '')
        .replaceAll('GBP', '')
        .replaceAll('%', '')
        .replaceAll('+', '')
        .trim();

    return double.tryParse(cleaned) ?? defaultValue;
  }

  /// Parse European number format (comma as decimal separator)
  static double parseEuropeanDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;

    var str = value.toString().trim();
    if (str.isEmpty || str == '-' || str == 'N/A') {
      return defaultValue;
    }

    // European format: 1.234,56 -> 1234.56
    str = str.replaceAll('.', '').replaceAll(',', '.');

    return double.tryParse(str) ?? defaultValue;
  }

  /// Safely parse int
  static int? parseIntSafe(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return null;
    }
    return int.tryParse(value.replaceAll(',', '').trim());
  }

  /// Safely get value from list at index
  static String getValueSafe(List<dynamic> line, int? index) {
    if (index == null || index < 0 || index >= line.length) {
      return '';
    }
    return line[index].toString().trim();
  }

  /// Generate unique ID
  static String generateId() => uuid.v4();

  // ==================== NORMALIZATION ====================

  /// Normalize asset type to standard format
  static String normalizeAssetType(String assetType) {
    final lower = assetType.toLowerCase().trim();

    if (lower.isEmpty) return 'Other';
    if (lower.contains('etf')) return 'ETFs';
    if (lower.contains('stock') || lower.contains('equity') || lower.contains('shares')) {
      return 'Stocks';
    }
    if (lower.contains('bond') || lower.contains('fixed income')) return 'Bonds';
    if (lower.contains('option')) return 'Options';
    if (lower.contains('future')) return 'Futures';
    if (lower.contains('forex') || lower.contains('fx') || lower.contains('cash')) {
      return 'Cash';
    }
    if (lower.contains('crypto') || lower.contains('bitcoin') || lower.contains('coin')) {
      return 'Crypto';
    }
    if (lower.contains('fund') || lower.contains('mutual')) return 'Funds';
    if (lower.contains('commodity')) return 'Commodities';
    if (lower.contains('cfd')) return 'CFDs';

    // Return original with first letter capitalized
    return assetType.isEmpty
        ? 'Other'
        : assetType[0].toUpperCase() + assetType.substring(1).toLowerCase();
  }

  /// Normalize sector to standard format
  static String normalizeSector(String sector) {
    final lower = sector.toLowerCase().trim();

    if (lower.isEmpty) return 'Other';
    if (lower.contains('tech')) return 'Technology';
    if (lower.contains('financ') || lower.contains('bank')) return 'Financials';
    if (lower.contains('health') || lower.contains('pharma') || lower.contains('biotech')) {
      return 'Healthcare';
    }
    if (lower.contains('consumer') && lower.contains('cycl')) return 'Consumer Cyclicals';
    if (lower.contains('consumer') && (lower.contains('non') || lower.contains('staple'))) {
      return 'Consumer Non-Cyclicals';
    }
    if (lower.contains('industrial') || lower.contains('manufact')) return 'Industrials';
    if (lower.contains('material') || lower.contains('basic')) return 'Basic Materials';
    if (lower.contains('energy') || lower.contains('oil') || lower.contains('gas')) {
      return 'Energy';
    }
    if (lower.contains('utilit')) return 'Utilities';
    if (lower.contains('real') || lower.contains('estate') || lower.contains('reit')) {
      return 'Real Estate';
    }
    if (lower.contains('communic') || lower.contains('telecom')) return 'Communications';
    if (lower.contains('broad') || lower.contains('diversif')) return 'Broad';

    return sector.isEmpty
        ? 'Other'
        : sector[0].toUpperCase() + sector.substring(1).toLowerCase();
  }

  // [UPDATED] Symbol normalization + dedup helpers for imports
  /// Normalize ticker symbols (e.g., AAPL.US -> AAPL)
  static String normalizeSymbol(String symbol) {
    var trimmed = symbol.trim().toUpperCase();
    if (trimmed.isEmpty) return trimmed;

    trimmed = trimmed.replaceAll(RegExp(r'\s+'), '');

    if (_isIsin(trimmed)) {
      return trimmed;
    }

    final separators = ['.', ':', '/', '-'];
    for (final separator in separators) {
      if (trimmed.contains(separator)) {
        final parts = trimmed.split(separator);
        if (parts.isNotEmpty) {
          final suffix = parts.length > 1 ? parts.last : '';
          if (_isExchangeSuffix(suffix)) {
            return parts.first;
          }
        }
      }
    }

    return trimmed;
  }

  static bool _isIsin(String value) {
    return RegExp(r'^[A-Z]{2}[A-Z0-9]{10}$').hasMatch(value);
  }

  static bool _isExchangeSuffix(String suffix) {
    if (suffix.isEmpty) return false;
    const exchangeSuffixes = {
      'US', 'USA', 'NYSE', 'NASDAQ', 'NASDAQGS', 'NASDAQGM', 'NASDAQCM',
      'LSE', 'LON', 'AMS', 'AS', 'BRU', 'BR', 'PA', 'F', 'DE', 'MI', 'MIL',
      'BIT', 'SW', 'SIX', 'HK', 'TO', 'TSX', 'TSXV', 'AX', 'ASX', 'SG',
    };
    return exchangeSuffixes.contains(suffix);
  }

  /// Normalize, clean, and deduplicate positions
  static List<Position> normalizeAndDeduplicatePositions(List<Position> positions) {
    final normalized = positions.map((position) {
      final normalizedSymbol = normalizeSymbol(position.symbol);
      return position.copyWith(
        symbol: normalizedSymbol,
        name: position.name.isNotEmpty ? position.name : normalizedSymbol,
        assetType: normalizeAssetType(position.assetType),
        sector: normalizeSector(position.sector),
        currency: position.currency.toUpperCase(),
      );
    }).toList();

    return deduplicatePositions(normalized);
  }

  /// Merge duplicate positions by ISIN or normalized symbol + currency
  static List<Position> deduplicatePositions(List<Position> positions) {
    final merged = <String, Position>{};

    for (final position in positions) {
      final key = _buildPositionKey(position);
      if (key.isEmpty) {
        merged[generateId()] = position;
        continue;
      }

      final existing = merged[key];
      if (existing == null) {
        merged[key] = position;
      } else {
        merged[key] = _mergePositions(existing, position);
      }
    }

    return merged.values.toList();
  }

  static String _buildPositionKey(Position position) {
    final isin = position.isin?.trim().toUpperCase();
    if (isin != null && isin.isNotEmpty) {
      return 'ISIN:$isin';
    }

    final symbol = normalizeSymbol(position.symbol);
    if (symbol.isEmpty) {
      final name = position.name.trim().toUpperCase();
      if (name.isEmpty) return '';
      return 'NAME:$name:${position.currency.toUpperCase()}';
    }

    return 'SYM:$symbol:${position.currency.toUpperCase()}';
  }

  static Position _mergePositions(Position base, Position incoming) {
    final combinedQuantity = base.quantity + incoming.quantity;
    final combinedValue = base.value + incoming.value;
    final combinedCostBasis = base.costBasis + incoming.costBasis;
    final combinedPnL = base.unrealizedPnL + incoming.unrealizedPnL;
    final combinedPrice = combinedQuantity == 0
        ? base.closePrice
        : combinedValue / combinedQuantity;

    final preferredFx = base.fxRateToBase != 1.0
        ? base.fxRateToBase
        : incoming.fxRateToBase;

    final latestUpdate = _pickLatestDate(base.lastUpdated, incoming.lastUpdated);

    return base.copyWith(
      symbol: base.symbol.isNotEmpty ? base.symbol : incoming.symbol,
      name: base.name.isNotEmpty ? base.name : incoming.name,
      assetType: base.assetType.isNotEmpty ? base.assetType : incoming.assetType,
      sector: base.sector.isNotEmpty ? base.sector : incoming.sector,
      currency: base.currency.isNotEmpty ? base.currency : incoming.currency,
      exchange: base.exchange ?? incoming.exchange,
      isin: base.isin ?? incoming.isin,
      quantity: combinedQuantity,
      closePrice: combinedPrice,
      value: combinedValue,
      costBasis: combinedCostBasis,
      unrealizedPnL: combinedPnL,
      fxRateToBase: preferredFx,
      lastUpdated: latestUpdate,
    );
  }

  static DateTime? _pickLatestDate(DateTime? first, DateTime? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first.isAfter(second) ? first : second;
  }

  /// Infer asset type from symbol pattern
  static String inferAssetTypeFromSymbol(String symbol, String description) {
    final symLower = symbol.toLowerCase();
    final descLower = description.toLowerCase();

    // Crypto patterns
    const cryptoSymbols = [
      'btc', 'eth', 'doge', 'ltc', 'bch', 'etc', 'bsv', 'shib', 
      'avax', 'sol', 'ada', 'xrp', 'dot', 'link', 'matic'
    ];
    if (cryptoSymbols.any((c) => symLower == c || symLower.startsWith('$c'))) {
      return 'Crypto';
    }

    // ETF patterns
    if (descLower.contains('etf') || 
        symLower.endsWith('x') || 
        descLower.contains('index fund')) {
      return 'ETFs';
    }

    // Bond patterns
    if (descLower.contains('bond') || 
        symLower.startsWith('us') && symLower.length > 8) {
      return 'Bonds';
    }

    return 'Stocks';
  }

  // ==================== DATE PARSING ====================

  /// Parse various date formats
  static DateTime? parseDate(String dateStr) {
    if (dateStr.isEmpty || dateStr == '-') return null;

    try {
      // ISO 8601: 2024-01-15 or 2024-01-15T10:30:00Z
      if (dateStr.contains('-') && dateStr.length >= 10) {
        final parts = dateStr.split('T')[0].split('-');
        if (parts.length == 3 && parts[0].length == 4) {
          return DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        }
      }

      // US format: MM/DD/YYYY or M/DD/YYYY
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final year = int.parse(parts[2].split(' ')[0]);
          return DateTime(
            year < 100 ? 2000 + year : year,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      }

      // European format: DD-MM-YYYY or DD.MM.YYYY
      if (dateStr.contains('.') || 
          (dateStr.contains('-') && !dateStr.startsWith('20'))) {
        final separator = dateStr.contains('.') ? '.' : '-';
        final parts = dateStr.split(separator);
        if (parts.length >= 3 && parts[0].length <= 2) {
          return DateTime(
            int.parse(parts[2].split(' ')[0]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      }

      return DateTime.tryParse(dateStr);
    } catch (e) {
      return null;
    }
  }
}