import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Revolut Trading CSV exports
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: Period (.)
/// - Dates: YYYY-MM-DD (ISO format) - cleanest format among brokers
/// - Negative values: Parentheses (455.75)
/// - Currency: Column per row (typically USD)
/// - Provider: DriveWealth LLC
/// - Export available since June 2021
/// 
/// Header:
///   Trade Date,Settle Date,Currency,Activity Type,Symbol / Description,
///   Symbol,Description,Quantity,Price,Amount
/// 
/// Activity Type values: BUY, SELL, DIV (Dividend), CDEP (Cash deposit), 
///                       CSD/SSP (Stock split)
class RevolutParser extends BaseBrokerParser {
  @override
  String get brokerId => 'revolut';

  @override
  String get brokerName => 'Revolut';

  @override
  String get defaultCurrency => 'USD';

  @override
  Portfolio parse(String csvContent) {
    final lines = BaseBrokerParser.parseCSV(csvContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positionMap = <String, _RevolutPosition>{};
    var headerIndices = <String, int>{};
    var baseCurrency = 'USD';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().trim();

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        continue;
      }

      // Skip empty rows
      if (firstCell.isEmpty) continue;

      // Parse transaction
      if (headerIndices.isNotEmpty) {
        _parseTransaction(line, headerIndices, positionMap);
      }
    }

    // Determine base currency from positions
    final positions = positionMap.values
        .where((p) => p.quantity > 0)
        .map((p) => p.toPosition())
        .toList();

    if (positions.isNotEmpty) {
      final currencies = positions.map((p) => p.currency).toSet();
      if (currencies.length == 1) {
        baseCurrency = currencies.first;
      }
    }

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: 'REV-${DateTime.now().millisecondsSinceEpoch}',
      accountName: 'Revolut Account',
      baseCurrency: baseCurrency,
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('trade date') && 
           (lineStr.contains('symbol') || lineStr.contains('activity type'));
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '');

      if (header == 'tradedate') indices['tradeDate'] = i;
      if (header == 'settledate') indices['settleDate'] = i;
      if (header == 'currency') indices['currency'] = i;
      if (header == 'activitytype') indices['activityType'] = i;
      if (header == 'symbol/description') indices['symbolDesc'] = i;
      if (header == 'symbol') indices['symbol'] = i;
      if (header == 'description') indices['description'] = i;
      if (header == 'quantity') indices['quantity'] = i;
      if (header == 'price') indices['price'] = i;
      if (header == 'amount') indices['amount'] = i;
    }

    return indices;
  }

  void _parseTransaction(
    List<dynamic> line, 
    Map<String, int> indices,
    Map<String, _RevolutPosition> positionMap,
  ) {
    try {
      final activityType = BaseBrokerParser.getValueSafe(line, indices['activityType'])
          .toUpperCase();
      
      // Only process relevant activity types
      final isBuy = activityType == 'BUY';
      final isSell = activityType == 'SELL';
      final isDividend = activityType == 'DIV';
      final isSplit = activityType == 'CSD' || activityType == 'SSP';

      if (!isBuy && !isSell && !isDividend && !isSplit) return;

      // Get symbol - Revolut has both "Symbol / Description" and separate columns
      var symbol = BaseBrokerParser.getValueSafe(line, indices['symbol']);
      if (symbol.isEmpty) {
        final symbolDesc = BaseBrokerParser.getValueSafe(line, indices['symbolDesc']);
        symbol = symbolDesc.split(' - ')[0].split(' ')[0];
      }

      if (symbol.isEmpty) return;

      final description = BaseBrokerParser.getValueSafe(line, indices['description']);
      final currency = BaseBrokerParser.getValueSafe(line, indices['currency']).toUpperCase();
      final quantity = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['quantity']),
      );
      final price = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['price']),
      );
      final amount = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['amount']),
      );

      if (!positionMap.containsKey(symbol)) {
        positionMap[symbol] = _RevolutPosition(
          symbol: symbol,
          description: description,
          currency: currency.isNotEmpty ? currency : 'USD',
        );
      }

      if (isBuy) {
        positionMap[symbol]!.addBuy(quantity, price, amount.abs());
      } else if (isSell) {
        positionMap[symbol]!.addSell(quantity, price, amount.abs());
      } else if (isDividend) {
        positionMap[symbol]!.addDividend(amount);
      } else if (isSplit) {
        positionMap[symbol]!.handleSplit(quantity);
      }
    } catch (e) {
      // Skip invalid lines
    }
  }
}

class _RevolutPosition {
  final String symbol;
  final String description;
  final String currency;
  double quantity = 0;
  double totalCost = 0;
  double lastPrice = 0;
  double dividends = 0;
  double realizedPnL = 0;

  _RevolutPosition({
    required this.symbol,
    required this.description,
    required this.currency,
  });

  void addBuy(double qty, double price, double cost) {
    quantity += qty;
    totalCost += cost;
    if (price > 0) lastPrice = price;
  }

  void addSell(double qty, double price, double proceeds) {
    if (quantity > 0) {
      final avgCost = totalCost / quantity;
      final costOfSold = avgCost * qty;
      realizedPnL += proceeds - costOfSold;
      totalCost -= costOfSold;
    }
    quantity -= qty;
    if (price > 0) lastPrice = price;
  }

  void addDividend(double amount) {
    dividends += amount;
  }

  void handleSplit(double newQuantity) {
    // Stock split - adjust quantity but maintain cost basis
    if (newQuantity > 0) {
      quantity = newQuantity;
    }
  }

  Position toPosition() {
    final value = quantity * lastPrice;
    return Position(
      id: BaseBrokerParser.generateId(),
      symbol: symbol.toUpperCase(),
      name: description.isNotEmpty ? description : symbol,
      assetType: _inferAssetType(),
      sector: 'Other',
      currency: currency,
      quantity: quantity,
      closePrice: lastPrice,
      value: value,
      costBasis: totalCost,
      unrealizedPnL: value - totalCost,
      lastUpdated: DateTime.now(),
    );
  }

  String _inferAssetType() {
    final descLower = description.toLowerCase();
    if (descLower.contains('etf')) return 'ETFs';
    if (descLower.contains('reit') || descLower.contains('real estate')) return 'Real Estate';
    return 'Stocks';
  }
}