import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for E*TRADE (Morgan Stanley) CSV exports
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: US format (1,234.56)
/// - Dates: MM/DD/YYYY
/// - Formats available: CSV and XLSX
/// 
/// Positions Header: Symbol,Price Paid $,Qty #,Description,Last Price,Market Value,
///                   Day Change,Total Gain/Loss
/// 
/// Transactions Header: TransactionDate,Symbol,SecurityType,Description,
///                      TransactionType,Quantity,Price,Amount,Commission,Fee
class ETradeParser extends BaseBrokerParser {
  @override
  String get brokerId => 'etrade';

  @override
  String get brokerName => 'E*TRADE';

  @override
  Portfolio parse(String csvContent) {
    final lines = BaseBrokerParser.parseCSV(csvContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positions = <Position>[];
    var headerIndices = <String, int>{};
    var accountId = '';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().trim();
      final firstCellLower = firstCell.toLowerCase();

      // Extract account info
      if (firstCellLower.contains('account') && line.length > 1) {
        accountId = line[1].toString().replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
        continue;
      }

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        continue;
      }

      // Skip total and empty rows
      if (firstCellLower.contains('total') || firstCell.isEmpty) {
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
      accountName: 'E*TRADE Account',
      baseCurrency: 'USD',
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('symbol') && 
           (lineStr.contains('price') || lineStr.contains('qty') || lineStr.contains('quantity'));
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '');

      if (header.contains('symbol')) indices['symbol'] = i;
      if (header.contains('description')) indices['description'] = i;
      if (header.contains('qty') || header.contains('quantity')) indices['quantity'] = i;
      if (header == 'lastprice' || header.contains('price') && !header.contains('paid')) {
        indices['price'] = i;
      }
      if (header.contains('pricepaid') || header.contains('avgprice')) {
        indices['avgPrice'] = i;
      }
      if (header.contains('marketvalue') || header == 'value') indices['value'] = i;
      if (header.contains('costbasis') || header.contains('totalcost')) indices['costBasis'] = i;
      if (header.contains('gain') || header.contains('totalgain') || header.contains('pnl')) {
        indices['unrealizedPnL'] = i;
      }
      if (header.contains('securitytype') || header == 'type') indices['assetType'] = i;
    }

    return indices;
  }

  Position? _parsePositionLine(List<dynamic> line, Map<String, int> indices) {
    try {
      final symbol = BaseBrokerParser.getValueSafe(line, indices['symbol']);
      final description = BaseBrokerParser.getValueSafe(line, indices['description']);

      if (symbol.isEmpty) return null;

      final quantity = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['quantity']),
      );
      final price = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['price']),
      );
      final avgPrice = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['avgPrice']),
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

      // Skip zero positions
      if (quantity == 0 && value == 0) return null;

      // Calculate values
      final calculatedValue = value != 0 ? value : quantity * price;
      final calculatedCostBasis = costBasis != 0 
          ? costBasis 
          : (avgPrice != 0 ? quantity * avgPrice : calculatedValue);
      final calculatedPnL = unrealizedPnL != 0 
          ? unrealizedPnL 
          : calculatedValue - calculatedCostBasis;

      return Position(
        id: BaseBrokerParser.generateId(),
        symbol: symbol.toUpperCase(),
        name: description.isNotEmpty ? description : symbol,
        assetType: assetTypeRaw.isNotEmpty
            ? BaseBrokerParser.normalizeAssetType(assetTypeRaw)
            : BaseBrokerParser.inferAssetTypeFromSymbol(symbol, description),
        sector: 'Other',
        currency: 'USD',
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