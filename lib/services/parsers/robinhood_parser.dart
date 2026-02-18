import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Robinhood Activity Report CSV exports
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: US format with $ in quotes ("$53.85")
/// - Dates: M/DD/YYYY or MM/DD/YYYY
/// - All fields in double quotes
/// - Negative values in parentheses: ($43.64)
/// - Max 1 year of history
/// - Reports generated in 2-24 hours
/// 
/// Header: "Activity Date","Process Date","Settle Date","Instrument",
///         "Description","Trans Code","Quantity","Price","Amount"
/// 
/// Trans Code values: Buy, Sell, CDIV (Cash dividend)
class RobinhoodParser extends BaseBrokerParser {
  @override
  String get brokerId => 'robinhood';

  @override
  String get brokerName => 'Robinhood';

  @override
  Portfolio parse(String csvContent) {
    final lines = BaseBrokerParser.parseCSV(csvContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positionMap = <String, _PositionAccumulator>{};
    var headerIndices = <String, int>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().replaceAll('"', '').trim();
      final firstCellLower = firstCell.toLowerCase();

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        continue;
      }

      // Skip invalid rows
      if (firstCell.isEmpty || firstCellLower.contains('total')) {
        continue;
      }

      // Parse transaction row and accumulate into positions
      if (headerIndices.isNotEmpty) {
        _parseTransaction(line, headerIndices, positionMap);
      }
    }

    // Convert accumulated transactions to positions
    final positions = positionMap.values
        .where((acc) => acc.quantity != 0)
        .map((acc) => acc.toPosition())
        .toList();

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: 'RH-${DateTime.now().millisecondsSinceEpoch}',
      accountName: 'Robinhood Account',
      baseCurrency: 'USD',
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return lineStr.contains('instrument') && 
           (lineStr.contains('quantity') || lineStr.contains('price') || lineStr.contains('trans'));
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll('"', '').replaceAll(' ', '');

      if (header.contains('instrument') || header == 'symbol') indices['instrument'] = i;
      if (header.contains('description')) indices['description'] = i;
      if (header == 'transcode' || header == 'transactiontype') indices['transCode'] = i;
      if (header == 'quantity') indices['quantity'] = i;
      if (header == 'price') indices['price'] = i;
      if (header == 'amount') indices['amount'] = i;
      if (header.contains('activitydate') || header.contains('date')) indices['date'] = i;
    }

    return indices;
  }

  void _parseTransaction(
    List<dynamic> line, 
    Map<String, int> indices,
    Map<String, _PositionAccumulator> positionMap,
  ) {
    try {
      final instrument = BaseBrokerParser.getValueSafe(line, indices['instrument'])
          .replaceAll('"', '');
      final description = BaseBrokerParser.getValueSafe(line, indices['description'])
          .replaceAll('"', '');
      final transCode = BaseBrokerParser.getValueSafe(line, indices['transCode'])
          .replaceAll('"', '').toLowerCase();
      
      // Only process buy/sell transactions
      if (!transCode.contains('buy') && !transCode.contains('sell')) {
        return;
      }

      if (instrument.isEmpty) return;

      final quantity = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['quantity']),
      );
      final price = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['price']),
      );
      final amount = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['amount']),
      );

      // Determine sign based on transaction type
      final isBuy = transCode.contains('buy');
      final signedQuantity = isBuy ? quantity : -quantity;
      final signedAmount = amount.abs() * (isBuy ? 1 : -1);

      // Accumulate into position
      if (!positionMap.containsKey(instrument)) {
        positionMap[instrument] = _PositionAccumulator(
          symbol: instrument,
          description: description,
        );
      }

      positionMap[instrument]!.addTransaction(
        quantity: signedQuantity,
        price: price,
        amount: signedAmount,
      );
    } catch (e) {
      // Skip invalid lines
    }
  }
}

/// Helper class to accumulate transactions into a position
class _PositionAccumulator {
  final String symbol;
  final String description;
  double quantity = 0;
  double totalCost = 0;
  double currentPrice = 0;

  _PositionAccumulator({
    required this.symbol,
    required this.description,
  });

  void addTransaction({
    required double quantity,
    required double price,
    required double amount,
  }) {
    this.quantity += quantity;
    if (quantity > 0) {
      // Buy - add to cost basis
      totalCost += amount.abs();
    } else {
      // Sell - reduce cost basis proportionally
      if (this.quantity + quantity.abs() > 0) {
        final avgCost = totalCost / (this.quantity + quantity.abs());
        totalCost -= avgCost * quantity.abs();
      }
    }
    currentPrice = price;
  }

  Position toPosition() {
    final value = quantity * currentPrice;
    final double costBasis =
        quantity > 0 ? (totalCost * quantity / (quantity + 0.001)) : 0.0;
    
    return Position(
      id: BaseBrokerParser.generateId(),
      symbol: symbol.toUpperCase(),
      name: description.isNotEmpty ? description : symbol,
      assetType: _inferAssetType(),
      sector: 'Other',
      currency: 'USD',
      quantity: quantity,
      closePrice: currentPrice,
      value: value,
      costBasis: costBasis.abs(),
      unrealizedPnL: value - costBasis.abs(),
      lastUpdated: DateTime.now(),
    );
  }

  String _inferAssetType() {
    const cryptoSymbols = [
      'BTC', 'ETH', 'DOGE', 'LTC', 'BCH', 'ETC', 'BSV', 
      'SHIB', 'AVAX', 'SOL', 'ADA', 'XRP', 'DOT', 'LINK', 'MATIC'
    ];
    if (cryptoSymbols.contains(symbol.toUpperCase())) {
      return 'Crypto';
    }
    return 'Stocks';
  }
}