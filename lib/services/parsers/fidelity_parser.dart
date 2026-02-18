import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Fidelity CSV exports
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: US format with $ symbol ($441.41)
/// - Dates: MM/DD/YYYY (N/A for positions snapshot)
/// - BOM: UTF-8 BOM at start
/// - Footer: 2 legal disclaimer lines at end
/// - Prefixes: +/- for gain/loss (+$111.14, -$18.98)
/// - Percentages: % symbol (+4.44%)
/// 
/// Header: Account Number,Account Name,Symbol,Description,Quantity,Last Price,
///         Last Price Change,Current Value,Today's Gain/Loss Dollar,...
class FidelityParser extends BaseBrokerParser {
  @override
  String get brokerId => 'fidelity';

  @override
  String get brokerName => 'Fidelity';

  @override
  Portfolio parse(String csvContent) {
    final lines = BaseBrokerParser.parseCSV(csvContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positions = <Position>[];
    var headerIndices = <String, int>{};
    var accountId = '';
    var accountName = '';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().trim();
      final firstCellLower = firstCell.toLowerCase();

      // Skip disclaimer/footer lines
      if (firstCellLower.contains('brokerage services') ||
          firstCellLower.contains('fidelity') && firstCellLower.contains('llc') ||
          firstCellLower.contains('disclaimer') ||
          firstCell.isEmpty) {
        continue;
      }

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        continue;
      }

      // Skip total and cash rows
      if (firstCellLower.contains('total') ||
          firstCellLower.contains('cash') ||
          firstCellLower.contains('pending')) {
        continue;
      }

      // Parse data row
      if (headerIndices.isNotEmpty) {
        final position = _parsePositionLine(line, headerIndices);
        if (position != null) {
          positions.add(position);
          // Extract account info from first valid position
          if (accountId.isEmpty && headerIndices['accountNumber'] != null) {
            accountId = BaseBrokerParser.getValueSafe(line, headerIndices['accountNumber']);
          }
          if (accountName.isEmpty && headerIndices['accountName'] != null) {
            accountName = BaseBrokerParser.getValueSafe(line, headerIndices['accountName']);
          }
        }
      }
    }

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: accountId.replaceAll(RegExp(r'[^0-9A-Za-z]'), ''),
      accountName: accountName.isNotEmpty ? accountName : 'Fidelity Account',
      baseCurrency: 'USD',
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('symbol') && lineStr.contains('description');
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '');

      if (header == 'accountnumber' || header == 'account') {
        indices['accountNumber'] = i;
      }
      if (header == 'accountname') indices['accountName'] = i;
      if (header == 'symbol') indices['symbol'] = i;
      if (header == 'description') indices['description'] = i;
      if (header == 'quantity') indices['quantity'] = i;
      if (header == 'lastprice' || header == 'price') indices['price'] = i;
      if (header == 'currentvalue' || header == 'marketvalue') indices['value'] = i;
      if (header == 'costbasis' || header == 'costbasistotal') indices['costBasis'] = i;
      if (header == 'costbasispers' || header == 'costbasispershare') {
        indices['costBasisPerShare'] = i;
      }
      if (header.contains('totalgain') || 
          header.contains('unrealized') ||
          header == 'gain/lossdollar') {
        indices['unrealizedPnL'] = i;
      }
      if (header.contains('totalgain') && header.contains('percent')) {
        indices['unrealizedPnLPercent'] = i;
      }
      if (header == 'type' || header == 'securitytype') indices['assetType'] = i;
      if (header == 'percentofaccount') indices['percentOfAccount'] = i;
    }

    return indices;
  }

  Position? _parsePositionLine(List<dynamic> line, Map<String, int> indices) {
    try {
      final symbol = BaseBrokerParser.getValueSafe(line, indices['symbol']);
      final description = BaseBrokerParser.getValueSafe(line, indices['description']);

      // Skip invalid entries
      if (symbol.isEmpty || 
          symbol.toLowerCase().contains('pending') ||
          symbol.toLowerCase() == 'n/a') {
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

      // Skip zero quantity positions
      if (quantity == 0 && value == 0) return null;

      // Calculate missing values
      final calculatedValue = value != 0 ? value : quantity * price;
      final calculatedCostBasis = costBasis != 0 ? costBasis : calculatedValue;
      final calculatedPnL = unrealizedPnL != 0 
          ? unrealizedPnL 
          : calculatedValue - calculatedCostBasis;

      return Position(
        id: BaseBrokerParser.generateId(),
        symbol: symbol.toUpperCase(),
        name: description.isNotEmpty ? description : symbol,
        assetType: assetTypeRaw.isNotEmpty
            ? BaseBrokerParser.normalizeAssetType(assetTypeRaw)
            : _inferAssetType(symbol, description),
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

  String _inferAssetType(String symbol, String description) {
    final descLower = description.toLowerCase();
    final symLower = symbol.toLowerCase();

    if (descLower.contains('etf') || symLower.endsWith('x')) return 'ETFs';
    if (descLower.contains('bond') || descLower.contains('treasury')) return 'Bonds';
    if (descLower.contains('fund') || descLower.contains('mutual')) return 'Funds';
    if (descLower.contains('money market') || symLower.contains('core')) return 'Cash';

    return 'Stocks';
  }
}