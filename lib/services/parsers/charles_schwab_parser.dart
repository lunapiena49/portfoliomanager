import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Charles Schwab CSV exports
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: US format with $ in quotes ("$26.37")
/// - Dates: MM/DD/YYYY
/// - All fields in double quotes
/// - 2-3 metadata rows before column headers
/// 
/// Metadata example:
///   Transactions for account XXXX-9999 as of 06/17/2018 14:50:44 ET
///   From 01/01/2018 to 06/17/2018
/// 
/// Header: "Date","Action","Symbol","Description","Quantity","Price","Fees & Comm","Amount"
class CharlesSchwabParser extends BaseBrokerParser {
  @override
  String get brokerId => 'charles_schwab';

  @override
  String get brokerName => 'Charles Schwab';

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

      // Extract account from metadata line
      if (firstCellLower.contains('account') && firstCellLower.contains('as of')) {
        final match = RegExp(r'account\s+(\S+)').firstMatch(firstCellLower);
        if (match != null) {
          accountId = match.group(1)?.replaceAll(RegExp(r'[^0-9A-Za-z]'), '') ?? '';
        }
        continue;
      }

      // Skip date range metadata
      if (firstCellLower.startsWith('from ') && firstCellLower.contains(' to ')) {
        continue;
      }

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        continue;
      }

      // Skip total and empty rows
      if (firstCellLower.contains('total') ||
          firstCell.isEmpty ||
          firstCellLower.contains('transactions total')) {
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

    // Aggregate positions by symbol
    final aggregatedPositions = _aggregatePositions(positions);

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: accountId,
      accountName: 'Schwab Account',
      baseCurrency: 'USD',
      broker: brokerId,
      positions: aggregatedPositions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return (lineStr.contains('symbol') || lineStr.contains('security')) && 
           (lineStr.contains('quantity') || lineStr.contains('shares') || lineStr.contains('price'));
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '').replaceAll('"', '');

      if (header == 'symbol' || header == 'security') indices['symbol'] = i;
      if (header.contains('description') || header.contains('name')) indices['description'] = i;
      if (header.contains('quantity') || header.contains('shares')) indices['quantity'] = i;
      if (header == 'price' || header.contains('lastprice')) indices['price'] = i;
      if (header.contains('marketvalue') || header == 'value') indices['value'] = i;
      if (header.contains('costbasis')) indices['costBasis'] = i;
      if (header.contains('gain') || header.contains('unrealized')) indices['unrealizedPnL'] = i;
      if (header == 'action' || header == 'type') indices['action'] = i;
      if (header.contains('fees') || header.contains('comm')) indices['fees'] = i;
      if (header == 'amount') indices['amount'] = i;
    }

    return indices;
  }

  Position? _parsePositionLine(List<dynamic> line, Map<String, int> indices) {
    try {
      final symbol = BaseBrokerParser.getValueSafe(line, indices['symbol'])
          .replaceAll('"', '');
      final description = BaseBrokerParser.getValueSafe(line, indices['description'])
          .replaceAll('"', '');

      // Skip invalid entries
      if (symbol.isEmpty || 
          symbol.toLowerCase().contains('cash') ||
          symbol.toLowerCase() == 'total') {
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

      // Skip zero positions
      if (quantity == 0 && value == 0) return null;

      // Calculate values
      final calculatedValue = value != 0 ? value : quantity * price;
      final calculatedCostBasis = costBasis != 0 ? costBasis : calculatedValue;
      final calculatedPnL = unrealizedPnL != 0 
          ? unrealizedPnL 
          : calculatedValue - calculatedCostBasis;

      return Position(
        id: BaseBrokerParser.generateId(),
        symbol: symbol.toUpperCase(),
        name: description.isNotEmpty ? description : symbol,
        assetType: BaseBrokerParser.inferAssetTypeFromSymbol(symbol, description),
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

  /// Aggregate positions with same symbol
  List<Position> _aggregatePositions(List<Position> positions) {
    final Map<String, Position> aggregated = {};

    for (final pos in positions) {
      if (aggregated.containsKey(pos.symbol)) {
        final existing = aggregated[pos.symbol]!;
        aggregated[pos.symbol] = Position(
          id: existing.id,
          symbol: existing.symbol,
          name: existing.name,
          assetType: existing.assetType,
          sector: existing.sector,
          currency: existing.currency,
          quantity: existing.quantity + pos.quantity,
          closePrice: pos.closePrice, // Use latest price
          value: existing.value + pos.value,
          costBasis: existing.costBasis + pos.costBasis,
          unrealizedPnL: existing.unrealizedPnL + pos.unrealizedPnL,
          lastUpdated: DateTime.now(),
        );
      } else {
        aggregated[pos.symbol] = pos;
      }
    }

    return aggregated.values.toList();
  }
}