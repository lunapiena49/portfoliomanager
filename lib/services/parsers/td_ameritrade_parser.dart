import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for TD Ameritrade CSV exports (now integrated with Schwab)
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: US format (1,234.56)
/// - Dates: MM/DD/YYYY
/// - Special marker: ***END OF FILE*** at end
/// - No quotes around fields
class TDAmeritradeParser extends BaseBrokerParser {
  @override
  String get brokerId => 'td_ameritrade';

  @override
  String get brokerName => 'TD Ameritrade';

  @override
  Portfolio parse(String csvContent) {
    // Remove END OF FILE marker
    var cleanContent = csvContent;
    if (cleanContent.contains('***END OF FILE***')) {
      cleanContent = cleanContent.split('***END OF FILE***')[0];
    }

    final lines = BaseBrokerParser.parseCSV(cleanContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positions = <Position>[];
    var headerIndices = <String, int>{};
    var accountId = '';
    var baseCurrency = 'USD';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().toLowerCase().trim();

      // Skip empty rows
      if (firstCell.isEmpty) continue;

      // Check for account info row
      if (firstCell.contains('account')) {
        if (line.length > 1) {
          accountId = line[1].toString().replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
        }
        continue;
      }

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        continue;
      }

      // Skip non-data rows
      if (firstCell.contains('total') || 
          firstCell.contains('***') ||
          firstCell.contains('cash alternatives')) {
        continue;
      }

      // Parse data row
      if (headerIndices.isNotEmpty) {
        final position = _parsePositionLine(line, headerIndices);
        if (position != null) {
          positions.add(position);
        }
      }
    }

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: accountId,
      accountName: 'TD Ameritrade Account',
      baseCurrency: baseCurrency,
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('symbol') && 
           (lineStr.contains('quantity') || 
            lineStr.contains('price') || 
            lineStr.contains('value'));
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '');

      if (header.contains('symbol')) indices['symbol'] = i;
      if (header.contains('description') || header.contains('security')) {
        indices['description'] = i;
      }
      if (header.contains('quantity') || header.contains('qty') || header.contains('shares')) {
        indices['quantity'] = i;
      }
      if (header.contains('price') || header.contains('last')) indices['price'] = i;
      if (header.contains('value') || header.contains('marketvalue')) indices['value'] = i;
      if (header.contains('costbasis') || header.contains('cost')) indices['costBasis'] = i;
      if (header.contains('gain') || 
          header.contains('unrealized') || 
          header.contains('p&l') || 
          header.contains('pnl')) {
        indices['unrealizedPnL'] = i;
      }
      if (header.contains('type') || header.contains('assetclass')) indices['assetType'] = i;
      if (header.contains('sector')) indices['sector'] = i;
      if (header.contains('currency')) indices['currency'] = i;
    }

    return indices;
  }

  Position? _parsePositionLine(List<dynamic> line, Map<String, int> indices) {
    try {
      final symbol = BaseBrokerParser.getValueSafe(line, indices['symbol']);
      final description = BaseBrokerParser.getValueSafe(line, indices['description']);

      // Skip invalid rows
      if (symbol.isEmpty || symbol.toLowerCase().contains('total')) {
        return null;
      }

      final quantity = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['quantity']),
      );
      final price = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['price']),
      );
      final value = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['value']),
      );
      final costBasis = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['costBasis']),
      );
      final unrealizedPnL = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['unrealizedPnL']),
      );

      final assetTypeRaw = BaseBrokerParser.getValueSafe(line, indices['assetType']);
      final sectorRaw = BaseBrokerParser.getValueSafe(line, indices['sector']);
      final currencyRaw = BaseBrokerParser.getValueSafe(line, indices['currency']);

      // Skip zero positions
      if (quantity == 0 && value == 0) return null;

      // Calculate missing values
      final calculatedValue = value != 0 ? value : quantity * price;
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
        currency: currencyRaw.isNotEmpty ? currencyRaw.toUpperCase() : 'USD',
        quantity: quantity,
        closePrice: price != 0 ? price : (quantity != 0 ? calculatedValue / quantity : 0),
        value: calculatedValue,
        costBasis: calculatedCostBasis,
        unrealizedPnL: calculatedPnL,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
}