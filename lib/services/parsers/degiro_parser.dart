import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for DEGIRO CSV exports (European broker)
/// 
/// Format characteristics:
/// - Separator: Comma (,)
/// - Decimals: European format (127,54) in localized, period in English export
/// - Dates: DD-MM-YYYY (e.g., 11-10-2024)
/// - Time: HH:MM (24h format)
/// - Order ID: UUID format
/// - Empty columns between some fields (marked by ,,)
/// 
/// Account Statement Header:
///   Date,Time,Value date,Product,ISIN,Description,FX,Change,,Balance,,Order ID
/// 
/// Transactions Header:
///   Date,Time,Product,ISIN,Exchange,Execution Venue,Number,Price,,Local Value,,
///   Value,,Exchange Rate,,Transaction Costs,,Total,,Order ID
/// 
/// Description patterns: "Buy X [Product]@[Price] [Currency] (ISIN)"
class DEGIROParser extends BaseBrokerParser {
  @override
  String get brokerId => 'degiro';

  @override
  String get brokerName => 'DEGIRO';

  @override
  String get defaultCurrency => 'EUR';

  @override
  Portfolio parse(String csvContent) {
    // First try comma delimiter
    var lines = BaseBrokerParser.parseCSV(csvContent);

    // If first line seems to use semicolon, re-parse
    if (lines.isNotEmpty && 
        lines[0].length == 1 && 
        lines[0][0].toString().contains(';')) {
      lines = BaseBrokerParser.parseCSV(csvContent, fieldDelimiter: ';');
    }

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    final positionMap = <String, _DEGIROPosition>{};
    var headerIndices = <String, int>{};
    var baseCurrency = 'EUR';

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      final firstCell = line[0].toString().trim();
      final firstCellLower = firstCell.toLowerCase();

      // Detect header row
      if (_isHeaderRow(line)) {
        headerIndices = _parseHeader(line);
        continue;
      }

      // Skip non-data rows
      if (firstCell.isEmpty || 
          firstCellLower.contains('total') ||
          firstCellLower.contains('degiro')) {
        continue;
      }

      // Parse transaction and accumulate positions
      if (headerIndices.isNotEmpty) {
        _parseTransaction(line, headerIndices, positionMap);
      }
    }

    // Convert to positions
    final positions = positionMap.values
        .where((p) => p.quantity != 0)
        .map((p) => p.toPosition())
        .toList();

    // Determine base currency from positions
    if (positions.isNotEmpty) {
      final currencies = positions.map((p) => p.currency).toSet();
      if (currencies.length == 1) {
        baseCurrency = currencies.first;
      }
    }

    return Portfolio(
      id: BaseBrokerParser.generateId(),
      accountId: 'DEGIRO-${DateTime.now().millisecondsSinceEpoch}',
      accountName: 'DEGIRO Account',
      baseCurrency: baseCurrency,
      broker: brokerId,
      positions: positions,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  bool _isHeaderRow(List<dynamic> line) {
    final lineStr = line.join(' ').toLowerCase();
    return (lineStr.contains('product') || lineStr.contains('isin')) && 
           (lineStr.contains('date') || lineStr.contains('price') || lineStr.contains('number'));
  }

  Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};

    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().trim();

      if (header == 'date' || header == 'datum') indices['date'] = i;
      if (header == 'time' || header == 'tijd') indices['time'] = i;
      if (header == 'product' || header == 'produkt') indices['product'] = i;
      if (header == 'isin') indices['isin'] = i;
      if (header == 'description' || header == 'omschrijving') indices['description'] = i;
      if (header == 'number' || header == 'aantal' || header == 'quantity') {
        indices['quantity'] = i;
      }
      if ((header == 'price' || header == 'prijs' || header == 'kurs') && 
          !indices.containsKey('price')) {
        indices['price'] = i;
      }
      if (header == 'value' || header == 'waarde' || header == 'wert') {
        indices['value'] = i;
      }
      if (header == 'local value' || header == 'lokale waarde') {
        indices['localValue'] = i;
      }
      if (header == 'fx' || header == 'exchange rate' || header == 'wisselkoers') {
        indices['exchangeRate'] = i;
      }
      if (header == 'change' || header == 'mutatie') indices['change'] = i;
      if (header == 'balance' || header == 'saldo') indices['balance'] = i;
    }

    return indices;
  }

  void _parseTransaction(
    List<dynamic> line, 
    Map<String, int> indices,
    Map<String, _DEGIROPosition> positionMap,
  ) {
    try {
      final product = BaseBrokerParser.getValueSafe(line, indices['product']);
      final isin = BaseBrokerParser.getValueSafe(line, indices['isin']);
      final description = BaseBrokerParser.getValueSafe(line, indices['description']);

      // Need at least product or ISIN
      if (product.isEmpty && isin.isEmpty) return;

      // Parse quantity (may use European decimal format)
      var quantityStr = BaseBrokerParser.getValueSafe(line, indices['quantity']);
      var priceStr = BaseBrokerParser.getValueSafe(line, indices['price']);
      var valueStr = BaseBrokerParser.getValueSafe(line, indices['value']);
      if (valueStr.isEmpty) {
        valueStr = BaseBrokerParser.getValueSafe(line, indices['localValue']);
      }

      // Handle European format (comma as decimal separator)
      final quantity = _parseEuropeanOrUSDouble(quantityStr);
      final price = _parseEuropeanOrUSDouble(priceStr);
      final value = _parseEuropeanOrUSDouble(valueStr);

      // Determine if buy or sell from description
      final descLower = description.toLowerCase();
      final isBuy = descLower.contains('buy') || descLower.contains('koop');
      final isSell = descLower.contains('sell') || descLower.contains('verkoop');

      // Skip non-trade transactions
      if (!isBuy && !isSell && quantity == 0) return;

      // Determine sign
      final signedQuantity = isSell ? -quantity.abs() : quantity.abs();

      // Extract currency from description or default
      final currency = _extractCurrency(description);

      // Use ISIN as key, fallback to product
      final key = isin.isNotEmpty ? isin : product;

      if (!positionMap.containsKey(key)) {
        positionMap[key] = _DEGIROPosition(
          symbol: _extractSymbol(product, isin),
          name: product,
          isin: isin,
          currency: currency,
        );
      }

      positionMap[key]!.addTransaction(
        quantity: signedQuantity,
        price: price,
        value: value,
      );
    } catch (e) {
      // Skip invalid lines
    }
  }

  double _parseEuropeanOrUSDouble(String value) {
    if (value.isEmpty) return 0.0;

    // Check if European format (comma as decimal, period as thousand)
    final hasComma = value.contains(',');
    final hasPeriod = value.contains('.');

    if (hasComma && !hasPeriod) {
      // Pure European: 127,54 -> 127.54
      return BaseBrokerParser.parseDoubleSafe(value.replaceAll(',', '.'));
    } else if (hasComma && hasPeriod) {
      // Mixed: 1.234,56 (European) or 1,234.56 (US)
      final commaIndex = value.indexOf(',');
      final periodIndex = value.indexOf('.');
      if (commaIndex > periodIndex) {
        // European: 1.234,56
        return BaseBrokerParser.parseDoubleSafe(
          value.replaceAll('.', '').replaceAll(',', '.'),
        );
      }
    }

    // US format or already clean
    return BaseBrokerParser.parseDoubleSafe(value);
  }

  String _extractCurrency(String description) {
    if (description.contains('EUR')) return 'EUR';
    if (description.contains('USD')) return 'USD';
    if (description.contains('GBP')) return 'GBP';
    if (description.contains('CHF')) return 'CHF';
    return 'EUR'; // DEGIRO default
  }

  String _extractSymbol(String product, String isin) {
    // Try to extract ticker from product name
    final parts = product.split(' ');
    if (parts.isNotEmpty) {
      // Common pattern: "VANGUARD FTSE ALL-WORLD..." -> use first word
      final first = parts[0];
      if (first.length <= 6 && first.toUpperCase() == first) {
        return first;
      }
    }
    // Fallback to ISIN
    return isin.isNotEmpty ? isin : product.substring(0, 6.clamp(0, product.length));
  }
}

class _DEGIROPosition {
  final String symbol;
  final String name;
  final String isin;
  final String currency;
  double quantity = 0;
  double totalCost = 0;
  double lastPrice = 0;

  _DEGIROPosition({
    required this.symbol,
    required this.name,
    required this.isin,
    required this.currency,
  });

  void addTransaction({
    required double quantity,
    required double price,
    required double value,
  }) {
    this.quantity += quantity;
    if (quantity > 0) {
      totalCost += value.abs();
    } else {
      // Reduce cost proportionally
      if (this.quantity > 0) {
        final avgCost = totalCost / this.quantity;
        totalCost -= avgCost * quantity.abs();
      }
    }
    if (price > 0) lastPrice = price;
  }

  Position toPosition() {
    final value = quantity * lastPrice;
    return Position(
      id: BaseBrokerParser.generateId(),
      symbol: symbol.toUpperCase(),
      name: name,
      assetType: _inferAssetType(),
      sector: 'Other',
      currency: currency,
      quantity: quantity,
      closePrice: lastPrice,
      value: value,
      costBasis: totalCost,
      unrealizedPnL: value - totalCost,
      isin: isin.isNotEmpty ? isin : null,
      lastUpdated: DateTime.now(),
    );
  }

  String _inferAssetType() {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('etf')) return 'ETFs';
    if (nameLower.contains('bond') || nameLower.contains('oblig')) return 'Bonds';
    if (nameLower.contains('fund') || nameLower.contains('fonds')) return 'Funds';
    return 'Stocks';
  }
}