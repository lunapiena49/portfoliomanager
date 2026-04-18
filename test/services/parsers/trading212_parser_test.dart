import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_manager/services/parsers/trading212_parser.dart';

void main() {
  late Trading212Parser parser;

  setUp(() {
    parser = Trading212Parser();
  });

  group('Trading212Parser', () {
    test('exposes broker metadata', () {
      expect(parser.brokerId, 'trading212');
      expect(parser.brokerName, 'Trading 212');
      expect(parser.defaultCurrency, 'EUR');
    });

    test('throws on empty csv', () {
      expect(() => parser.parse(''), throwsA(isA<FormatException>()));
    });

    test('detects base currency from header', () {
      const csv = 'Action,Time,ISIN,Ticker,Name,No. of shares,Price / share,Currency (Price / share),Total (GBP)\n'
          'Market buy,2024-01-15T10:30:00Z,US0378331005,AAPL,Apple,5,180.00,USD,900.00\n';

      final portfolio = parser.parse(csv);
      expect(portfolio.baseCurrency, 'GBP');
    });

    test('accumulates buy transactions into positions', () {
      const csv = 'Action,Time,ISIN,Ticker,Name,No. of shares,Price / share,Currency (Price / share),Total (EUR)\n'
          'Market buy,2024-01-15T10:30:00Z,US0378331005,AAPL,Apple,5,100.00,USD,500.00\n'
          'Market buy,2024-02-01T10:30:00Z,US0378331005,AAPL,Apple,5,110.00,USD,550.00\n';

      final portfolio = parser.parse(csv);
      expect(portfolio.positions.length, 1);

      final aapl = portfolio.positions.first;
      expect(aapl.symbol, 'AAPL');
      expect(aapl.quantity, 10);
      expect(aapl.costBasis, closeTo(1050.0, 0.01));
    });

    test('ignores unsupported action types', () {
      const csv = 'Action,Time,ISIN,Ticker,Name,No. of shares,Price / share,Currency (Price / share),Total (EUR)\n'
          'Deposit,2024-01-15T10:30:00Z,,,,,,,100.00\n'
          'Interest on cash,2024-01-20T10:30:00Z,,,,,,,0.50\n';

      final portfolio = parser.parse(csv);
      expect(portfolio.positions, isEmpty);
    });

    test('skips positions with non-positive quantity (sell-all scenario)', () {
      const csv = 'Action,Time,ISIN,Ticker,Name,No. of shares,Price / share,Currency (Price / share),Total (EUR),Result (EUR)\n'
          'Market buy,2024-01-15T10:30:00Z,US0378331005,AAPL,Apple,5,100.00,USD,500.00,0\n'
          'Market sell,2024-02-01T10:30:00Z,US0378331005,AAPL,Apple,5,110.00,USD,550.00,50\n';

      final portfolio = parser.parse(csv);
      expect(portfolio.positions, isEmpty);
    });
  });
}
