import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Generic parser for unknown/other broker CSV exports
/// 
/// This parser attempts to auto-detect the CSV structure by:
/// 1. Identifying header rows based on common column names
/// 2. Supporting both comma and semicolon delimiters
/// 3. Handling various date and number formats
/// 
/// Minimum required columns for detection:
/// - Symbol/Ticker (required)
/// - At least one of: Quantity, Value, Price
class GenericCSVParser extends BaseBrokerParser {
  @override
  String get brokerId => 'other';

  @override
  String get brokerName => 'Other / Generic';

  @override
  Portfolio parse(String csvContent) {
    // Try comma first, then semicolon
    var lines = BaseBrokerParser.parseCSV(csvContent);
    
    if (lines.isEmpty || (lines.isNotEmpty && lines[0].length <= 1)) {
      lines = BaseBrokerParser.parseCSV(csvContent, fieldDelimiter: ';');
    }

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positions = <Position>[];
    var headerIndices = <String, int>{};
    var detectedCurrency = 'USD';

    // Try to find header row in first 10 lines
    for (var i = 0; i < lines.length && i < 10; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final detected = _tryDetectHeader(line);
      if (detected.isNotEmpty && detected.containsKey('symbol')) {
        headerIndices = detected;

        // Parse remaining lines as data
        for (var j = i + 1; j < lines.length; j++) {
          final dataLine = lines[j];
          if (dataLine.isEmpty) continue;

          final position = _parsePositionLine(dataLine, headerIndices);
          if (position != null) {
            positions.add(position);
            // Try to detect currency from first valid position
            if (detectedCurrency == 'USD' && position.currency.isNotEmpty) {
              detectedCurrency = position.currency;
            }
          }
        }
        break;
      }
    }

    if (headerIndices.isEmpty) {
      throw FormatException(
        'Could not detect CSV structure. Ensure the file has a header row with '
        'columns like: Symbol/Ticker, Quantity/Shares, Price, Value. '
        'Supported delimiters: comma (,) and semicolon (;).',
      );
    }

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: 'IMPORT-${DateTime.now().millisecondsSinceEpoch}',
      accountName: 'Imported Portfolio',
      baseCurrency: detectedCurrency,
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  Map<String, int> _tryDetectHeader(List<dynamic> line) {
    final indices = <String, int>{};
    var matchCount = 0;

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '');

      // Symbol/Ticker detection (required)
      if (header.contains('symbol') || 
          header.contains('ticker') || 
          header == 'instrument' ||
          header == 'security') {
        indices['symbol'] = i;
        matchCount++;
      }

      // Name/Description
      if (header.contains('name') || 
          header.contains('description') || 
          header == 'security name') {
        indices['description'] = i;
        matchCount++;
      }

      // Quantity
      if (header.contains('quantity') || 
          header.contains('qty') || 
          header.contains('shares') ||
          header == 'units' ||
          header == 'amount') {
        if (!indices.containsKey('quantity')) {
          indices['quantity'] = i;
          matchCount++;
        }
      }

      // Price
      if (header.contains('price') && 
          !header.contains('cost') && 
          !header.contains('paid')) {
        if (!indices.containsKey('price')) {
          indices['price'] = i;
          matchCount++;
        }
      }

      // Value
      if (header.contains('value') || 
          header.contains('marketvalue') ||
          header == 'total' ||
          header == 'equity') {
        if (!indices.containsKey('value')) {
          indices['value'] = i;
          matchCount++;
        }
      }

      // Cost basis
      if (header.contains('cost') || 
          header.contains('basis') ||
          header.contains('invested') ||
          header.contains('avgprice')) {
        indices['costBasis'] = i;
        matchCount++;
      }

      // P&L
      if (header.contains('gain') || 
          header.contains('pnl') || 
          header.contains('profit') || 
          header.contains('return') ||
          header.contains('unrealized')) {
        indices['unrealizedPnL'] = i;
        matchCount++;
      }

      // Currency
      if (header == 'currency' || header == 'ccy') {
        indices['currency'] = i;
      }

      // Asset type
      if (header.contains('type') || 
          header.contains('assetclass') ||
          header == 'category') {
        indices['assetType'] = i;
      }

      // Sector
      if (header.contains('sector') || header.contains('industry')) {
        indices['sector'] = i;
      }

      // ISIN
      if (header == 'isin') {
        indices['isin'] = i;
      }
    }

    // Require at least symbol and one numeric column
    if (matchCount >= 2 && indices.containsKey('symbol')) {
      return indices;
    }

    return {};
  }

  Position? _parsePositionLine(List<dynamic> line, Map<String, int> indices) {
    try {
      final symbol = BaseBrokerParser.getValueSafe(line, indices['symbol']);
      final description = BaseBrokerParser.getValueSafe(line, indices['description']);

      // Skip invalid entries
      if (symbol.isEmpty || 
          symbol.toLowerCase().contains('total') ||
          symbol.toLowerCase() == 'n/a') {
        return null;
      }

      // Parse numeric values - try both US and European formats
      final quantityStr = BaseBrokerParser.getValueSafe(line, indices['quantity']);
      final priceStr = BaseBrokerParser.getValueSafe(line, indices['price']);
      final valueStr = BaseBrokerParser.getValueSafe(line, indices['value']);
      final costBasisStr = BaseBrokerParser.getValueSafe(line, indices['costBasis']);
      final pnlStr = BaseBrokerParser.getValueSafe(line, indices['unrealizedPnL']);

      final quantity = _parseFlexibleNumber(quantityStr);
      final price = _parseFlexibleNumber(priceStr);
      final value = _parseFlexibleNumber(valueStr);
      final costBasis = _parseFlexibleNumber(costBasisStr);
      final unrealizedPnL = _parseFlexibleNumber(pnlStr);

      final currency = BaseBrokerParser.getValueSafe(line, indices['currency']).toUpperCase();
      final assetTypeRaw = BaseBrokerParser.getValueSafe(line, indices['assetType']);
      final sectorRaw = BaseBrokerParser.getValueSafe(line, indices['sector']);
      final isin = BaseBrokerParser.getValueSafe(line, indices['isin']);

      // Skip zero positions
      if (quantity == 0 && value == 0) return null;

      // Calculate missing values
      final calculatedValue = value != 0 ? value : quantity * price;
      final calculatedPrice = price != 0
          ? price
          : (quantity != 0 ? calculatedValue / quantity : 0.0);
      final calculatedCostBasis = costBasis != 0 ? costBasis : calculatedValue;
      final calculatedPnL = unrealizedPnL != 0 ? unrealizedPnL : calculatedValue - calculatedCostBasis;

      return Position(
        id: BaseBrokerParser.generateId(),
        symbol: symbol.toUpperCase(),
        name: description.isNotEmpty ? description : symbol,
        assetType: assetTypeRaw.isNotEmpty
            ? BaseBrokerParser.normalizeAssetType(assetTypeRaw)
            : BaseBrokerParser.inferAssetTypeFromSymbol(symbol, description),
        sector: BaseBrokerParser.normalizeSector(sectorRaw),
        currency: currency.isNotEmpty ? currency : 'USD',
        quantity: quantity,
        closePrice: calculatedPrice,
        value: calculatedValue,
        costBasis: calculatedCostBasis,
        unrealizedPnL: calculatedPnL,
        isin: isin.isNotEmpty ? isin : null,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Parse number in either US or European format
  double _parseFlexibleNumber(String value) {
    if (value.isEmpty) return 0.0;

    // Detect format
    final hasComma = value.contains(',');
    final hasPeriod = value.contains('.');

    if (hasComma && hasPeriod) {
      // Mixed format - determine which is decimal separator
      final commaIndex = value.lastIndexOf(',');
      final periodIndex = value.lastIndexOf('.');

      if (commaIndex > periodIndex) {
        // European: 1.234,56
        return BaseBrokerParser.parseDoubleSafe(
          value.replaceAll('.', '').replaceAll(',', '.'),
        );
      }
    } else if (hasComma && !hasPeriod) {
      // Could be European decimal or US thousands
      final parts = value.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Likely European decimal: 123,45
        return BaseBrokerParser.parseDoubleSafe(value.replaceAll(',', '.'));
      }
    }

    // Default to US format
    return BaseBrokerParser.parseDoubleSafe(value);
  }
}