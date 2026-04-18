import 'package:flutter_test/flutter_test.dart';
import 'package:portfolio_manager/services/parsers/base_parser.dart';

void main() {
  group('BaseBrokerParser.parseDoubleSafe', () {
    test('parses plain decimals', () {
      expect(BaseBrokerParser.parseDoubleSafe('1234.56'), 1234.56);
      expect(BaseBrokerParser.parseDoubleSafe('0'), 0.0);
      expect(BaseBrokerParser.parseDoubleSafe('-5.5'), -5.5);
    });

    test('treats parenthesized numbers as negative', () {
      expect(BaseBrokerParser.parseDoubleSafe('(43.64)'), -43.64);
      expect(BaseBrokerParser.parseDoubleSafe('(1,234.56)'), -1234.56);
    });

    test('strips currency symbols and commas', () {
      expect(BaseBrokerParser.parseDoubleSafe(r'$1,234.56'), 1234.56);
      expect(BaseBrokerParser.parseDoubleSafe('1,000 USD'), 1000.0);
      expect(BaseBrokerParser.parseDoubleSafe('50%'), 50.0);
    });

    test('returns default on null/empty/invalid', () {
      expect(BaseBrokerParser.parseDoubleSafe(null), 0.0);
      expect(BaseBrokerParser.parseDoubleSafe(''), 0.0);
      expect(BaseBrokerParser.parseDoubleSafe('-'), 0.0);
      expect(BaseBrokerParser.parseDoubleSafe('N/A'), 0.0);
      expect(BaseBrokerParser.parseDoubleSafe('not a number'), 0.0);
    });

    test('honors custom default value', () {
      expect(BaseBrokerParser.parseDoubleSafe(null, defaultValue: -1.0), -1.0);
    });
  });

  group('BaseBrokerParser.parseEuropeanDouble', () {
    test('converts European decimal format to double', () {
      expect(BaseBrokerParser.parseEuropeanDouble('1.234,56'), 1234.56);
      expect(BaseBrokerParser.parseEuropeanDouble('0,50'), 0.50);
    });

    test('returns default on null/empty', () {
      expect(BaseBrokerParser.parseEuropeanDouble(null), 0.0);
      expect(BaseBrokerParser.parseEuropeanDouble(''), 0.0);
      expect(BaseBrokerParser.parseEuropeanDouble('-'), 0.0);
    });
  });

  group('BaseBrokerParser.normalizeAssetType', () {
    test('maps common synonyms to canonical types', () {
      expect(BaseBrokerParser.normalizeAssetType('ETF'), 'ETFs');
      expect(BaseBrokerParser.normalizeAssetType('Stock'), 'Stocks');
      expect(BaseBrokerParser.normalizeAssetType('equity'), 'Stocks');
      expect(BaseBrokerParser.normalizeAssetType('Bond'), 'Bonds');
      expect(BaseBrokerParser.normalizeAssetType('Crypto'), 'Crypto');
      expect(BaseBrokerParser.normalizeAssetType('mutual fund'), 'Funds');
      expect(BaseBrokerParser.normalizeAssetType('CFD'), 'CFDs');
    });

    test('defaults to Other for unknown', () {
      expect(BaseBrokerParser.normalizeAssetType(''), 'Other');
    });
  });

  group('BaseBrokerParser.normalizeSector', () {
    test('maps common sector names', () {
      expect(BaseBrokerParser.normalizeSector('Technology'), 'Technology');
      expect(BaseBrokerParser.normalizeSector('Pharma'), 'Healthcare');
      expect(BaseBrokerParser.normalizeSector('Banks'), 'Financials');
    });

    test('defaults to Other for empty', () {
      expect(BaseBrokerParser.normalizeSector(''), 'Other');
    });
  });

  group('BaseBrokerParser.parseCSV', () {
    test('normalizes CRLF line endings', () {
      const csv = 'a,b,c\r\n1,2,3\r\n4,5,6';
      final rows = BaseBrokerParser.parseCSV(csv);
      expect(rows.length, 3);
      expect(rows[0], ['a', 'b', 'c']);
    });

    test('strips UTF-8 BOM', () {
      const csv = '\uFEFFa,b\n1,2';
      final rows = BaseBrokerParser.parseCSV(csv);
      expect(rows[0][0], 'a');
    });
  });
}
