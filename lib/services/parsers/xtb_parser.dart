import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for XTB CSV exports (Polish broker)
/// 
/// Format characteristics:
/// - Separator: SEMICOLON (;) - unique among brokers!
/// - Decimals: Period (.) - may be comma in Polish locale
/// - Dates: DD.MM.YYYY HH:MM:SS
/// - Symbols: TICKER.EXCHANGE format (e.g., AAPL.US, MSFT.US)
/// - Note: Format changed in March 2025 to Excel with tabs
/// 
/// Cash Operations Header:
///   ID;Symbol;Type;Time;Comment;Amount
/// 
/// Closed Positions Header:
///   ID;Position;Symbol;Type;Open Time;Close Time;Open Rate;Close Rate;
///   Commission;Rollover;Profit;Net Profit;Comment
/// 
/// Example: 123456;AAPL.US;Stocks/ETF purchase;15.03.2024 10:30:25;buy 0.5 at 175.50;-87.75
class XTBParser extends BaseBrokerParser {
  @override
  String get brokerId => 'xtb';

  @override
  String get brokerName => 'XTB';

  @override
  String get defaultCurrency => 'USD';

  @override
  Portfolio parse(String csvContent) {
    // XTB uses semicolon as delimiter
    final lines = BaseBrokerParser.parseCSV(csvContent, fieldDelimiter: ';');

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positionMap = <String, _XTBPosition>{};
    var headerIndices = <String, int>{};
    var isClosedPositionsFormat = false;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().trim();

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        isClosedPositionsFormat = _isClosedPositionsHeader(line);
        continue;
      }

      // Skip non-data rows
      if (firstCell.isEmpty || !_isNumeric(firstCell)) {
        continue;
      }

      // Parse transaction
      if (headerIndices.isNotEmpty) {
        if (isClosedPositionsFormat) {
          _parseClosedPosition(line, headerIndices, positionMap);
        } else {
          _parseCashOperation(line, headerIndices, positionMap);
        }
      }
    }

    // Convert to positions
    final positions = positionMap.values
        .where((p) => p.quantity != 0)
        .map((p) => p.toPosition())
        .toList();

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: 'XTB-${DateTime.now().millisecondsSinceEpoch}',
      accountName: 'XTB Account',
      baseCurrency: 'USD',
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('symbol') && 
           (lineStr.contains('type') || lineStr.contains('position'));
  }

  bool _isClosedPositionsHeader(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('open rate') || lineStr.contains('close rate');
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().trim();

      if (header == 'id') indices['id'] = i;
      if (header == 'position') indices['position'] = i;
      if (header == 'symbol') indices['symbol'] = i;
      if (header == 'type') indices['type'] = i;
      if (header == 'time' || header == 'open time') indices['openTime'] = i;
      if (header == 'close time') indices['closeTime'] = i;
      if (header == 'open rate') indices['openRate'] = i;
      if (header == 'close rate') indices['closeRate'] = i;
      if (header == 'commission') indices['commission'] = i;
      if (header == 'rollover') indices['rollover'] = i;
      if (header == 'profit') indices['profit'] = i;
      if (header == 'net profit') indices['netProfit'] = i;
      if (header == 'comment') indices['comment'] = i;
      if (header == 'amount') indices['amount'] = i;
    }

    return indices;
  }

  void _parseCashOperation(
    List<dynamic> line, 
    Map<String, int> indices,
    Map<String, _XTBPosition> positionMap,
  ) {
    try {
      final symbol = _cleanSymbol(BaseBrokerParser.getValueSafe(line, indices['symbol']));
      final typeStr = BaseBrokerParser.getValueSafe(line, indices['type']).toLowerCase();
      final comment = BaseBrokerParser.getValueSafe(line, indices['comment']);
      final amount = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['amount']),
      );

      if (symbol.isEmpty) return;

      // Parse from comment: "buy 0.5 at 175.50"
      final buyMatch = RegExp(r'buy\s+([\d.,]+)\s+at\s+([\d.,]+)').firstMatch(comment.toLowerCase());
      final sellMatch = RegExp(r'sell\s+([\d.,]+)\s+at\s+([\d.,]+)').firstMatch(comment.toLowerCase());

      double quantity = 0;
      double price = 0;
      bool isBuy = false;

      if (buyMatch != null) {
        quantity = _parseXTBNumber(buyMatch.group(1) ?? '0');
        price = _parseXTBNumber(buyMatch.group(2) ?? '0');
        isBuy = true;
      } else if (sellMatch != null) {
        quantity = _parseXTBNumber(sellMatch.group(1) ?? '0');
        price = _parseXTBNumber(sellMatch.group(2) ?? '0');
        isBuy = false;
      } else if (typeStr.contains('purchase') || typeStr.contains('buy')) {
        isBuy = true;
      }

      if (quantity == 0 && amount != 0 && price != 0) {
        quantity = amount.abs() / price;
      }

      if (quantity == 0) return;

      if (!positionMap.containsKey(symbol)) {
        positionMap[symbol] = _XTBPosition(
          symbol: symbol,
          assetType: _inferAssetType(typeStr),
        );
      }

      if (isBuy) {
        positionMap[symbol]!.addBuy(quantity, price, amount.abs());
      } else {
        positionMap[symbol]!.addSell(quantity, price);
      }
    } catch (e) {
      // Skip invalid lines
    }
  }

  void _parseClosedPosition(
    List<dynamic> line, 
    Map<String, int> indices,
    Map<String, _XTBPosition> positionMap,
  ) {
    try {
      final symbol = _cleanSymbol(BaseBrokerParser.getValueSafe(line, indices['symbol']));
      final typeStr = BaseBrokerParser.getValueSafe(line, indices['type']).toLowerCase();
      final openRate = _parseXTBNumber(BaseBrokerParser.getValueSafe(line, indices['openRate']));
      final closeRate = _parseXTBNumber(BaseBrokerParser.getValueSafe(line, indices['closeRate']));
      final netProfit = _parseXTBNumber(BaseBrokerParser.getValueSafe(line, indices['netProfit']));

      if (symbol.isEmpty || openRate == 0) return;

      // Closed positions don't contribute to current holdings
      // but we track realized P&L
      if (!positionMap.containsKey(symbol)) {
        positionMap[symbol] = _XTBPosition(
          symbol: symbol,
          assetType: _inferAssetType(typeStr),
        );
      }

      positionMap[symbol]!.addRealizedPnL(netProfit);
      positionMap[symbol]!.updatePrice(closeRate > 0 ? closeRate : openRate);
    } catch (e) {
      // Skip invalid lines
    }
  }

  String _cleanSymbol(String rawSymbol) {
    // Remove exchange suffix: AAPL.US -> AAPL
    final parts = rawSymbol.split('.');
    return parts[0].toUpperCase();
  }

  double _parseXTBNumber(String value) {
    if (value.isEmpty) return 0.0;
    // XTB may use comma as decimal in Polish locale
    return BaseBrokerParser.parseDoubleSafe(value.replaceAll(',', '.'));
  }

  String _inferAssetType(String typeStr) {
    if (typeStr.contains('etf')) return 'ETFs';
    if (typeStr.contains('stock') || typeStr.contains('equity')) return 'Stocks';
    if (typeStr.contains('crypto')) return 'Crypto';
    if (typeStr.contains('cfd')) return 'CFDs';
    if (typeStr.contains('forex') || typeStr.contains('fx')) return 'Forex';
    return 'Stocks';
  }
}

class _XTBPosition {
  final String symbol;
  final String assetType;
  double quantity = 0;
  double totalCost = 0;
  double lastPrice = 0;
  double realizedPnL = 0;

  _XTBPosition({
    required this.symbol,
    required this.assetType,
  });

  void addBuy(double qty, double price, double cost) {
    quantity += qty;
    totalCost += cost;
    if (price > 0) lastPrice = price;
  }

  void addSell(double qty, double price) {
    // Reduce position
    if (quantity > 0) {
      final avgCost = totalCost / quantity;
      totalCost -= avgCost * qty;
    }
    quantity -= qty;
    if (price > 0) lastPrice = price;
  }

  void addRealizedPnL(double pnl) {
    realizedPnL += pnl;
  }

  void updatePrice(double price) {
    if (price > 0) lastPrice = price;
  }

  Position toPosition() {
    final value = quantity * lastPrice;
    return Position(
      id: BaseBrokerParser.generateId(),
      symbol: symbol,
      name: symbol,
      assetType: assetType,
      sector: 'Other',
      currency: 'USD',
      quantity: quantity,
      closePrice: lastPrice,
      value: value,
      costBasis: totalCost,
      unrealizedPnL: value - totalCost,
      lastUpdated: DateTime.now(),
    );
  }
}