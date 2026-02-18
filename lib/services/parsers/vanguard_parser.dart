import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Vanguard CSV exports
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: US format with $ symbol
/// - Dates: MM/DD/YYYY
/// - Filename: ofxdownload.csv (may download as .csv.xls)
/// - Structure: Holdings section, then Transactions section
/// - History limit: 18 months
/// 
/// Holdings Header: Account Number,Investment Name,Symbol,Shares,Share Price,Total Value
/// 
/// Transaction Header: Account Number,Trade Date,Settlement Date,Transaction Type,
///                     Transaction Description,Investment Name,Symbol,Shares,
///                     Share Price,Principal Amount,Commission,Fees,Net Amount,
///                     Accrued Interest,Account Type
class VanguardParser extends BaseBrokerParser {
  @override
  String get brokerId => 'vanguard';

  @override
  String get brokerName => 'Vanguard';

  @override
  Portfolio parse(String csvContent) {
    final lines = BaseBrokerParser.parseCSV(csvContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positions = <Position>[];
    var headerIndices = <String, int>{};
    var accountId = '';
    var isHoldingsSection = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().trim();
      final firstCellLower = firstCell.toLowerCase();

      // Detect Holdings section header
      if (_isHoldingsHeader(line)) {
        headerIndices = _parseHoldingsHeader(line);
        isHoldingsSection = true;
        continue;
      }

      // Detect Transactions section (stop processing holdings)
      if (_isTransactionsHeader(line)) {
        isHoldingsSection = false;
        break; // We only need holdings for portfolio snapshot
      }

      // Skip non-data rows
      if (firstCellLower.contains('total') || 
          firstCell.isEmpty ||
          firstCellLower.contains('***')) {
        continue;
      }

      // Parse holdings data
      if (isHoldingsSection && headerIndices.isNotEmpty) {
        final position = _parseHoldingsLine(line, headerIndices);
        if (position != null) {
          positions.add(position);
          // Extract account ID from first position
          if (accountId.isEmpty && headerIndices['accountNumber'] != null) {
            accountId = BaseBrokerParser.getValueSafe(line, headerIndices['accountNumber']);
          }
        }
      }
    }

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: accountId.replaceAll(RegExp(r'[^0-9A-Za-z]'), ''),
      accountName: 'Vanguard Account',
      baseCurrency: 'USD',
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHoldingsHeader(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('investment name') && 
           lineStr.contains('symbol') &&
           lineStr.contains('shares');
  }

  bool _isTransactionsHeader(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('trade date') || 
           lineStr.contains('settlement date') ||
           lineStr.contains('transaction type');
  }

  Map<String, int> _parseHoldingsHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '');

      if (header.contains('accountnumber') || header == 'account') {
        indices['accountNumber'] = i;
      }
      if (header.contains('investmentname') || header.contains('name')) {
        indices['name'] = i;
      }
      if (header == 'symbol') indices['symbol'] = i;
      if (header == 'shares' || header.contains('quantity')) indices['shares'] = i;
      if (header.contains('shareprice') || header == 'price') indices['price'] = i;
      if (header.contains('totalvalue') || header == 'value') indices['value'] = i;
    }

    return indices;
  }

  Position? _parseHoldingsLine(List<dynamic> line, Map<String, int> indices) {
    try {
      final symbol = BaseBrokerParser.getValueSafe(line, indices['symbol']);
      final name = BaseBrokerParser.getValueSafe(line, indices['name']);

      // Skip empty symbols or summary rows
      if (symbol.isEmpty || symbol.toLowerCase() == 'n/a') {
        return null;
      }

      final shares = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['shares']),
      );
      final price = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['price']),
      );
      final value = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['value']),
      );

      // Skip zero positions
      if (shares == 0 && value == 0) return null;

      // Calculate values
      final calculatedValue = value != 0 ? value : shares * price;
      final calculatedPrice =
          price != 0 ? price : (shares != 0 ? calculatedValue / shares : 0.0);

      return Position(
        id: BaseBrokerParser.generateId(),
        symbol: symbol.toUpperCase(),
        name: name.isNotEmpty ? name : symbol,
        assetType: _inferAssetType(symbol, name),
        sector: 'Other',
        currency: 'USD',
        quantity: shares,
        closePrice: calculatedPrice,
        value: calculatedValue,
        costBasis: calculatedValue, // Vanguard holdings don't include cost basis
        unrealizedPnL: 0.0, // Would need transaction history
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  String _inferAssetType(String symbol, String name) {
    final nameLower = name.toLowerCase();
    final symLower = symbol.toLowerCase();

    // Vanguard specific patterns
    if (nameLower.contains('etf') || symLower.startsWith('v') && symLower.length <= 5) {
      return 'ETFs';
    }
    if (nameLower.contains('bond') || nameLower.contains('treasury') || 
        nameLower.contains('fixed income')) {
      return 'Bonds';
    }
    if (nameLower.contains('fund') || nameLower.contains('index') ||
        nameLower.contains('admiral') || nameLower.contains('investor')) {
      return 'Funds';
    }
    if (nameLower.contains('money market') || nameLower.contains('settlement')) {
      return 'Cash';
    }
    if (nameLower.contains('target') && nameLower.contains('retirement')) {
      return 'Funds';
    }

    return 'Stocks';
  }
}