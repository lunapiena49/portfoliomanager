import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_manager/services/parsers/robinhood_parser.dart';

void main() {
  late RobinhoodParser parser;

  setUp(() {
    parser = RobinhoodParser();
  });

  group('RobinhoodParser', () {
    test('rejects empty csv', () {
      expect(() => parser.parse(''), throwsA(isA<FormatException>()));
    });

    test('identifies broker metadata', () {
      expect(parser.brokerId, 'robinhood');
      expect(parser.brokerName, 'Robinhood');
      expect(parser.defaultCurrency, 'USD');
    });

    test('parses buy transactions into position with accurate cost basis', () {
      const csv = '"Activity Date","Instrument","Description","Trans Code","Quantity","Price","Amount"\n'
          '"1/5/2024","AAPL","Apple Inc","Buy","10","\$150.00","\$1500.00"\n'
          '"2/5/2024","AAPL","Apple Inc","Buy","5","\$160.00","\$800.00"\n';

      final portfolio = parser.parse(csv);
      expect(portfolio.positions.length, 1);

      final aapl = portfolio.positions.first;
      expect(aapl.symbol, 'AAPL');
      expect(aapl.quantity, 15);
      expect(aapl.costBasis, closeTo(2300.0, 0.01));
      // closePrice is the last transaction price observed.
      expect(aapl.closePrice, 160.0);
      expect(aapl.currency, 'USD');
    });

    test('cost basis is positive and proportional after partial sell', () {
      // Buy 10 @ \$100 = 1000 total cost
      // Sell 4 @ \$120 -> avg cost 100/share, so totalCost -= 400, remaining 600 for 6 shares
      const csv = '"Activity Date","Instrument","Description","Trans Code","Quantity","Price","Amount"\n'
          '"1/5/2024","MSFT","Microsoft","Buy","10","\$100.00","\$1000.00"\n'
          '"2/5/2024","MSFT","Microsoft","Sell","4","\$120.00","(\$480.00)"\n';

      final portfolio = parser.parse(csv);
      expect(portfolio.positions.length, 1);

      final msft = portfolio.positions.first;
      expect(msft.quantity, 6);
      // No cargo-cult divisor: we expect exactly 600 (or very close), not 600 * 6/6.001.
      expect(msft.costBasis, closeTo(600.0, 0.01));
      expect(msft.costBasis, greaterThan(0));
    });

    test('classifies known crypto symbols', () {
      const csv = '"Activity Date","Instrument","Description","Trans Code","Quantity","Price","Amount"\n'
          '"1/5/2024","BTC","Bitcoin","Buy","0.5","\$40000.00","\$20000.00"\n';

      final portfolio = parser.parse(csv);
      expect(portfolio.positions.first.assetType, 'Crypto');
    });
  });
}
