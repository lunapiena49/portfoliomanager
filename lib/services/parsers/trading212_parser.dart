import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Trading 212 CSV exports
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: US format (1.50)
/// - Dates: ISO 8601 (2024-01-15T10:30:00Z)
/// - Base currency: Indicated in header (EUR), (GBP)
/// - CRITICAL: Columns are DYNAMIC - appear/disappear based on transaction types
/// - Column order may change between exports
/// - Only "Invest" account (NO CFD)
/// - Max 12 month windows per export
/// 
/// Header (18 columns, but dynamic):
///   Action,Time,ISIN,Ticker,Name,No. of shares,Price / share,
///   Currency (Price / share),Exchange rate,Result (EUR),Total (EUR),
///   Withholding tax,Currency (Withholding tax),Charge amount (EUR),
///   Stamp duty reserve tax (EUR),Notes,ID,Currency conversion fee (EUR)
/// 
/// Action values: Market buy, Market sell, Limit buy, Limit sell, 
///                Dividend (Ordinary), Deposit, Withdrawal, Interest on cash,
///                Currency conversion
class Trading212Parser extends BaseBrokerParser {
  @override
  String get brokerId => 'trading212';

  @override
  String get brokerName => 'Trading 212';

  @override
  String get defaultCurrency => 'EUR';

  @override
  Portfolio parse(String csvContent) {
    final lines = BaseBrokerParser.parseCSV(csvContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positionMap = <String, _T212Position>{};
    var headerIndices = <String, int>{};
    var baseCurrency = 'EUR';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().trim();
      final firstCellLower = firstCell.toLowerCase();

      // Detect header row - Trading 212 always starts with "Action"
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        // Try to detect base currency from header
        final headerStr = line.join(' ');
        if (headerStr.contains('(GBP)')) {
          baseCurrency = 'GBP';
        } else if (headerStr.contains('(USD)')) {
          baseCurrency = 'USD';
        }
        continue;
      }

      // Skip non-trade rows
      if (firstCell.isEmpty) continue;

      // Parse transaction
      if (headerIndices.isNotEmpty) {
        _parseTransaction(line, headerIndices, positionMap, baseCurrency);
      }
    }

    // Convert to positions
    final positions = positionMap.values
        .where((p) => p.quantity > 0)
        .map((p) => p.toPosition(baseCurrency))
        .toList();

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: 'T212-${DateTime.now().millisecondsSinceEpoch}',
      accountName: 'Trading 212 Account',
      baseCurrency: baseCurrency,
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    if (line.isEmpty) return false;
    final firstCell = line[0].toString().toLowerCase().trim();
    return firstCell == 'action';
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    // Trading 212 has dynamic columns, so we need flexible matching
    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().trim();

      if (header == 'action') indices['action'] = i;
      if (header == 'time') indices['time'] = i;
      if (header == 'isin') indices['isin'] = i;
      if (header == 'ticker') indices['ticker'] = i;
      if (header == 'name') indices['name'] = i;
      if (header.contains('no. of shares') || header.contains('shares')) {
        indices['shares'] = i;
      }
      if (header.contains('price / share') || header == 'price') {
        indices['price'] = i;
      }
      if (header.contains('currency') && header.contains('price')) {
        indices['priceCurrency'] = i;
      }
      if (header.contains('exchange rate')) indices['exchangeRate'] = i;
      if (header.contains('result')) indices['result'] = i;
      if (header.contains('total') && !header.contains('currency')) {
        indices['total'] = i;
      }
      if (header == 'id') indices['id'] = i;
      if (header.contains('withholding tax') && !header.contains('currency')) {
        indices['withholdingTax'] = i;
      }
    }

    return indices;
  }

  void _parseTransaction(
    List<dynamic> line, 
    Map<String, int> indices,
    Map<String, _T212Position> positionMap,
    String baseCurrency,
  ) {
    try {
      final action = BaseBrokerParser.getValueSafe(line, indices['action']).toLowerCase();
      
      // Only process buy/sell actions
      final isBuy = action.contains('buy');
      final isSell = action.contains('sell');
      final isDividend = action.contains('dividend');

      if (!isBuy && !isSell && !isDividend) return;

      final ticker = BaseBrokerParser.getValueSafe(line, indices['ticker']);
      final isin = BaseBrokerParser.getValueSafe(line, indices['isin']);
      final name = BaseBrokerParser.getValueSafe(line, indices['name']);

      if (ticker.isEmpty && isin.isEmpty) return;

      final shares = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['shares']),
      );
      final price = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['price']),
      );
      final total = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['total']),
      );
      final result = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['result']),
      );
      final priceCurrency = BaseBrokerParser.getValueSafe(line, indices['priceCurrency']);

      final key = ticker.isNotEmpty ? ticker : isin;

      if (!positionMap.containsKey(key)) {
        positionMap[key] = _T212Position(
          ticker: ticker,
          isin: isin,
          name: name,
          currency: priceCurrency.isNotEmpty ? priceCurrency : baseCurrency,
        );
      }

      if (isBuy) {
        positionMap[key]!.addBuy(shares, price, total);
      } else if (isSell) {
        positionMap[key]!.addSell(shares, price, total, result);
      } else if (isDividend) {
        positionMap[key]!.addDividend(total);
      }
    } catch (e) {
      // Skip invalid lines
    }
  }
}

class _T212Position {
  final String ticker;
  final String isin;
  final String name;
  final String currency;
  double quantity = 0;
  double totalInvested = 0;
  double realizedPnL = 0;
  double dividends = 0;
  double lastPrice = 0;

  _T212Position({
    required this.ticker,
    required this.isin,
    required this.name,
    required this.currency,
  });

  void addBuy(double shares, double price, double total) {
    quantity += shares;
    totalInvested += total.abs();
    if (price > 0) lastPrice = price;
  }

  void addSell(double shares, double price, double total, double result) {
    quantity -= shares;
    // Reduce cost basis proportionally
    if (quantity >= 0) {
      final avgCost = totalInvested / (quantity + shares);
      totalInvested -= avgCost * shares;
    }
    realizedPnL += result;
    if (price > 0) lastPrice = price;
  }

  void addDividend(double amount) {
    dividends += amount;
  }

  Position toPosition(String baseCurrency) {
    final value = quantity * lastPrice;
    final unrealizedPnL = value - totalInvested;

    return Position(
      id: BaseBrokerParser.generateId(),
      symbol: ticker.isNotEmpty ? ticker.toUpperCase() : isin,
      name: name.isNotEmpty ? name : ticker,
      assetType: _inferAssetType(),
      sector: 'Other',
      currency: currency.isNotEmpty ? currency : baseCurrency,
      quantity: quantity,
      closePrice: lastPrice,
      value: value,
      costBasis: totalInvested,
      unrealizedPnL: unrealizedPnL,
      isin: isin.isNotEmpty ? isin : null,
      lastUpdated: DateTime.now(),
    );
  }

  String _inferAssetType() {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('etf')) return 'ETFs';
    if (nameLower.contains('reit') || nameLower.contains('real estate')) return 'Real Estate';
    return 'Stocks';
  }
}