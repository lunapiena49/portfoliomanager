import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';
import 'ibkr_parser.dart';
import 'td_ameritrade_parser.dart';
import 'fidelity_parser.dart';
import 'charles_schwab_parser.dart';
import 'etrade_parser.dart';
import 'robinhood_parser.dart';
import 'vanguard_parser.dart';
import 'degiro_parser.dart';
import 'trading212_parser.dart';
import 'xtb_parser.dart';
import 'revolut_parser.dart';
import 'generic_parser.dart';

/// Factory for getting the appropriate parser based on broker ID
/// Also provides broker detection from CSV content
class BrokerParserFactory {
  /// Map of broker IDs to their parser instances
  static final Map<String, BaseBrokerParser> _parsers = {
    'ibkr': IBKRParser(),
    'td_ameritrade': TDAmeritradeParser(),
    'fidelity': FidelityParser(),
    'charles_schwab': CharlesSchwabParser(),
    'etrade': ETradeParser(),
    'robinhood': RobinhoodParser(),
    'vanguard': VanguardParser(),
    'degiro': DEGIROParser(),
    'trading212': Trading212Parser(),
    'xtb': XTBParser(),
    'revolut': RevolutParser(),
    'other': GenericCSVParser(),
  };

  /// Get parser for a specific broker
  /// Returns null if broker ID not found
  static BaseBrokerParser? getParser(String brokerId) {
    return _parsers[brokerId.toLowerCase()];
  }

  /// Get all available parser instances
  static List<BaseBrokerParser> get allParsers => _parsers.values.toList();

  /// Get list of supported broker IDs
  static List<String> get supportedBrokers => _parsers.keys.toList();

  /// Get broker info for UI display
  static List<BrokerInfo> get brokerInfoList => [
    BrokerInfo(
      id: 'ibkr',
      name: 'Interactive Brokers',
      description: 'PortfolioAnalyst export',
      region: 'Global',
    ),
    BrokerInfo(
      id: 'td_ameritrade',
      name: 'TD Ameritrade',
      description: 'Now part of Charles Schwab',
      region: 'USA',
    ),
    BrokerInfo(
      id: 'fidelity',
      name: 'Fidelity',
      description: 'Positions export',
      region: 'USA',
    ),
    BrokerInfo(
      id: 'charles_schwab',
      name: 'Charles Schwab',
      description: 'Transaction history export',
      region: 'USA',
    ),
    BrokerInfo(
      id: 'etrade',
      name: 'E*TRADE',
      description: 'Morgan Stanley',
      region: 'USA',
    ),
    BrokerInfo(
      id: 'robinhood',
      name: 'Robinhood',
      description: 'Activity report',
      region: 'USA',
    ),
    BrokerInfo(
      id: 'vanguard',
      name: 'Vanguard',
      description: 'Holdings export',
      region: 'USA',
    ),
    BrokerInfo(
      id: 'degiro',
      name: 'DEGIRO',
      description: 'Account statement',
      region: 'Europe',
    ),
    BrokerInfo(
      id: 'trading212',
      name: 'Trading 212',
      description: 'Invest account only',
      region: 'Europe',
    ),
    BrokerInfo(
      id: 'xtb',
      name: 'XTB',
      description: 'Cash operations export',
      region: 'Europe',
    ),
    BrokerInfo(
      id: 'revolut',
      name: 'Revolut',
      description: 'Trading account',
      region: 'Global',
    ),
    BrokerInfo(
      id: 'other',
      name: 'Other / Generic',
      description: 'Auto-detect format',
      region: 'Any',
    ),
  ];

  /// Parse CSV content with specified broker
  static Portfolio parseWithBroker(String csvContent, String brokerId) {
    final parser = getParser(brokerId);
    if (parser == null) {
      throw ArgumentError('Unsupported broker: $brokerId');
    }

    // Normalize parser usage and post-process positions
    final portfolio = parser.parse(csvContent);
    final normalizedPositions = BaseBrokerParser.normalizeAndDeduplicatePositions(
      portfolio.positions,
    );

    return portfolio.copyWith(positions: normalizedPositions);
  }

  /// Auto-detect broker from CSV content and parse
  static Portfolio autoParseCSV(String csvContent) {
    final detectedBroker = detectBroker(csvContent);
    return parseWithBroker(csvContent, detectedBroker);
  }

  // Detect broker using scoring (header + keyword match)
  static String detectBroker(String csvContent) {
    final contentLower = csvContent.toLowerCase();
    final firstLines = csvContent.split('\n').take(25).join('\n').toLowerCase();

    final scores = <String, int>{};

    void addScore(String brokerId, int score) {
      scores[brokerId] = (scores[brokerId] ?? 0) + score;
    }

    bool hasAny(String haystack, List<String> needles) {
      return needles.any(haystack.contains);
    }

    bool hasAll(String haystack, List<String> needles) {
      return needles.every(haystack.contains);
    }

    // IBKR
    if (hasAny(contentLower, ['interactive brokers', 'ibkr'])) {
      addScore('ibkr', 3);
    }
    if (hasAny(firstLines, ['introduction,header', 'open position summary'])) {
      addScore('ibkr', 5);
    }

    // TD Ameritrade
    if (hasAny(contentLower, ['td ameritrade', 'tdameritrade'])) {
      addScore('td_ameritrade', 3);
    }
    if (firstLines.contains('***end of file***')) {
      addScore('td_ameritrade', 5);
    }

    // Fidelity
    if (csvContent.startsWith('\uFEFF')) {
      addScore('fidelity', 2);
    }
    if (contentLower.contains('fidelity')) {
      addScore('fidelity', 3);
    }
    if (firstLines.contains('account number,account name,symbol')) {
      addScore('fidelity', 5);
    }

    // Charles Schwab
    if (hasAny(contentLower, ['schwab', 'charles schwab'])) {
      addScore('charles_schwab', 3);
    }
    if (hasAll(firstLines, ['transactions for account', 'as of'])) {
      addScore('charles_schwab', 5);
    }
    if (firstLines.contains('"date","action","symbol"')) {
      addScore('charles_schwab', 3);
    }

    // E*TRADE
    if (hasAny(contentLower, ['e*trade', 'etrade', 'morgan stanley'])) {
      addScore('etrade', 3);
    }
    if (hasAll(firstLines, ['transactiondate', 'transactiontype'])) {
      addScore('etrade', 4);
    }

    // Robinhood
    if (contentLower.contains('robinhood')) {
      addScore('robinhood', 3);
    }
    if (hasAll(firstLines, ['activity date', 'trans code'])) {
      addScore('robinhood', 5);
    }

    // Vanguard
    if (contentLower.contains('vanguard')) {
      addScore('vanguard', 3);
    }
    if (hasAll(firstLines, ['investment name', 'share price'])) {
      addScore('vanguard', 5);
    }

    // DEGIRO
    if (contentLower.contains('degiro')) {
      addScore('degiro', 3);
    }
    if (hasAll(firstLines, ['isin', 'order id'])) {
      addScore('degiro', 4);
    }
    if (firstLines.contains('date,time,product,isin')) {
      addScore('degiro', 5);
    }

    // Trading 212
    if (hasAny(contentLower, ['trading 212', 'trading212'])) {
      addScore('trading212', 3);
    }
    if (firstLines.startsWith('action,time,isin')) {
      addScore('trading212', 5);
    }

    // XTB
    if (contentLower.contains('xtb')) {
      addScore('xtb', 3);
    }
    if (csvContent.contains(';') &&
        hasAny(firstLines, ['symbol;type', 'position;symbol'])) {
      addScore('xtb', 5);
    }

    // Revolut
    if (hasAny(contentLower, ['revolut', 'drivewealth'])) {
      addScore('revolut', 3);
    }
    if (firstLines.contains('trade date,settle date,currency,activity type')) {
      addScore('revolut', 5);
    }

    if (scores.isEmpty) {
      return 'other';
    }

    final bestEntry = scores.entries.reduce(
      (current, next) => next.value > current.value ? next : current,
    );

    const detectionThreshold = 4;
    if (bestEntry.value < detectionThreshold) {
      return 'other';
    }

    return bestEntry.key;
  }
}

/// Information about a supported broker for UI display
class BrokerInfo {
  final String id;
  final String name;
  final String description;
  final String region;

  const BrokerInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.region,
  });
}