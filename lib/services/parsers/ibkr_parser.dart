import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Interactive Brokers (IBKR) CSV files
/// Handles the complex multi-section format of IBKR PortfolioAnalyst exports
class IBKRParser extends BaseBrokerParser {
  static const _uuid = Uuid();

  // [UPDATED] Normalize IBKR parser to BaseBrokerParser interface
  @override
  String get brokerId => 'ibkr';

  @override
  String get brokerName => 'Interactive Brokers';

  @override
  String get defaultCurrency => 'EUR';

  /// Parse IBKR CSV content and return a Portfolio object
  @override
  Portfolio parse(String csvContent) {
    final lines = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvContent);

    if (lines.isEmpty) {
      throw const FormatException('Empty CSV file');
    }

    // Parse different sections
    final introData = _parseIntroduction(lines);
    final profileData = _parseProfile(lines);
    final keyStats = _parseKeyStatistics(lines);
    final historicalPerf = _parseHistoricalPerformance(lines);
    final positions = _parseOpenPositions(lines);

    return Portfolio(
      id: _uuid.v4(),
      accountId: introData['account'] ?? '',
      accountName: introData['name'] ?? '',
      baseCurrency: introData['baseCurrency'] ?? 'EUR',
      broker: 'ibkr',
      positions: positions,
      profile: PortfolioProfile(
        name: profileData['name'] ?? '',
        accountType: profileData['accountType'] ?? 'Individual',
        age: _parseIntSafe(profileData['age']),
        investmentObjectives: profileData['investmentObjectives'],
        estimatedNetWorth: profileData['estimatedNetWorth'],
        estimatedLiquidNetWorth: profileData['estimatedLiquidNetWorth'],
        annualNetIncome: profileData['annualNetIncome'],
      ),
      statistics: keyStats,
      historicalPerformance: historicalPerf,
      lastUpdated: DateTime.now(),
      importedAt: DateTime.now(),
    );
  }

  /// Parse Introduction section
  static Map<String, String> _parseIntroduction(List<List<dynamic>> lines) {
    final data = <String, String>{};
    
    for (final line in lines) {
      if (line.isEmpty || line[0].toString() != 'Introduction') continue;
      
      if (line.length > 1 && line[1].toString() == 'Data') {
        // Introduction,Data,Name,Account,Alias,BaseCurrency,AccountType,...
        if (line.length > 2) data['name'] = line[2].toString();
        if (line.length > 3) data['account'] = line[3].toString();
        if (line.length > 5) data['baseCurrency'] = line[5].toString();
        if (line.length > 6) data['accountType'] = line[6].toString();
        break;
      }
    }
    
    return data;
  }

  /// Parse Profile section
  static Map<String, String> _parseProfile(List<List<dynamic>> lines) {
    final data = <String, String>{};
    
    for (final line in lines) {
      if (line.isEmpty || line[0].toString() != 'Profile') continue;
      
      if (line.length > 2 && line[1].toString() == 'Data') {
        final key = line[2].toString().toLowerCase().replaceAll(' ', '');
        if (line.length > 3) {
          final value = line[3].toString();
          
          switch (key) {
            case 'name':
              data['name'] = value;
              break;
            case 'account':
              data['account'] = value;
              break;
            case 'basecurrency':
              data['baseCurrency'] = value;
              break;
            case 'accounttype':
              data['accountType'] = value;
              break;
            case 'age':
              data['age'] = value;
              break;
            case 'investmentobjectives':
              data['investmentObjectives'] = value;
              break;
            case 'estimatednetworth':
              data['estimatedNetWorth'] = value;
              break;
            case 'estimatedliquidnetworth':
              data['estimatedLiquidNetWorth'] = value;
              break;
            case 'annualnetincome':
              data['annualNetIncome'] = value;
              break;
          }
        }
      }
    }
    
    return data;
  }

  /// Parse Key Statistics section
  static PortfolioStatistics? _parseKeyStatistics(List<List<dynamic>> lines) {
    for (final line in lines) {
      if (line.isEmpty || line[0].toString() != 'Key Statistics') continue;
      
      if (line.length > 1 && line[1].toString() == 'Data') {
        // Key Statistics,Data,BeginningNAV,EndingNAV,CumulativeReturn,...
        try {
          return PortfolioStatistics(
            beginningNAV: _parseDoubleSafe(line.length > 2 ? line[2] : '0'),
            endingNAV: _parseDoubleSafe(line.length > 3 ? line[3] : '0'),
            cumulativeReturn: _parseDoubleSafe(line.length > 4 ? line[4] : '0'),
            oneMonthReturn: _parseDoubleSafe(line.length > 5 ? line[5] : '0'),
            threeMonthReturn: _parseDoubleSafe(line.length > 7 ? line[7] : '0'),
            bestReturn: line.length > 9 ? _parseDoubleSafe(line[9]) : null,
            bestReturnDate: line.length > 10 ? line[10].toString() : null,
            worstReturn: line.length > 11 ? _parseDoubleSafe(line[11]) : null,
            worstReturnDate: line.length > 12 ? line[12].toString() : null,
            mtm: _parseDoubleSafe(line.length > 13 ? line[13] : '0'),
            depositsWithdrawals: _parseDoubleSafe(line.length > 14 ? line[14] : '0'),
            dividends: _parseDoubleSafe(line.length > 15 ? line[15] : '0'),
            interest: _parseDoubleSafe(line.length > 16 ? line[16] : '0'),
            feesCommissions: _parseDoubleSafe(line.length > 17 ? line[17] : '0'),
            changeInNAV: _parseDoubleSafe(line.length > 19 ? line[19] : '0'),
          );
        } catch (e) {
          // Return null if parsing fails
          return null;
        }
      }
    }
    return null;
  }

  /// Parse Historical Performance section
  static List<PerformanceRecord> _parseHistoricalPerformance(List<List<dynamic>> lines) {
    final records = <PerformanceRecord>[];
    var inHistoricalSection = false;
    var currentType = 'month';
    
    for (final line in lines) {
      if (line.isEmpty) continue;
      
      final sectionName = line[0].toString();
      
      if (sectionName == 'Historical Performance (Annualized)') {
        inHistoricalSection = true;
        
        if (line.length > 1) {
          final rowType = line[1].toString();
          
          if (rowType == 'Header') {
            // Determine period type from header
            if (line.length > 2) {
              final headerValue = line[2].toString().toLowerCase();
              if (headerValue == 'month') {
                currentType = 'month';
              } else if (headerValue == 'quarter') {
                currentType = 'quarter';
              } else if (headerValue == 'year') {
                currentType = 'year';
              }
            }
          } else if (rowType == 'Data' && line.length > 3) {
            final period = line[2].toString();
            final returnValue = line.length > 4 ? line[4].toString() : '-';
            
            // Skip empty or invalid returns
            if (returnValue != '-' && returnValue.isNotEmpty) {
              records.add(PerformanceRecord(
                period: period,
                periodType: currentType,
                accountReturn: _parseDoubleSafe(returnValue),
              ));
            }
          }
        }
      } else if (inHistoricalSection && !sectionName.contains('Historical')) {
        // Moved to next section
        break;
      }
    }
    
    return records;
  }

  /// Parse Open Position Summary section
  static List<Position> _parseOpenPositions(List<List<dynamic>> lines) {
    final positions = <Position>[];
    var inPositionSection = false;
    var headerIndices = <String, int>{};
    
    for (final line in lines) {
      if (line.isEmpty) continue;
      
      final sectionName = line[0].toString();
      
      if (sectionName == 'Open Position Summary') {
        inPositionSection = true;
        
        if (line.length > 1) {
          final rowType = line[1].toString();
          
          if (rowType == 'Header') {
            // Parse header to get column indices
            headerIndices = _parseHeader(line);
          } else if (rowType == 'Data' && headerIndices.isNotEmpty) {
            // Skip total rows and meta rows
            final firstValue = line.length > 2 ? line[2].toString() : '';
            if (firstValue.toLowerCase().contains('total') || 
                firstValue.isEmpty ||
                firstValue.toLowerCase() == 'metainfo') {
              continue;
            }
            
            // Parse position data
            final position = _parsePositionLine(line, headerIndices);
            if (position != null) {
              positions.add(position);
            }
          }
        }
      } else if (inPositionSection && sectionName != 'Open Position Summary') {
        // Moved to next section
        break;
      }
    }
    
    return positions;
  }

  /// Parse header line and return column indices
  static Map<String, int> _parseHeader(List<dynamic> line) {
    final indices = <String, int>{};
    
    for (var i = 0; i < line.length; i++) {
      final header = line[i].toString().toLowerCase().replaceAll(' ', '').replaceAll('&', '');
      
      switch (header) {
        case 'date':
          indices['date'] = i;
          break;
        case 'financialinstrument':
          indices['assetType'] = i;
          break;
        case 'currency':
          indices['currency'] = i;
          break;
        case 'symbol':
          indices['symbol'] = i;
          break;
        case 'description':
          indices['description'] = i;
          break;
        case 'sector':
          indices['sector'] = i;
          break;
        case 'quantity':
          indices['quantity'] = i;
          break;
        case 'closeprice':
          indices['closePrice'] = i;
          break;
        case 'value':
          indices['value'] = i;
          break;
        case 'costbasis':
          indices['costBasis'] = i;
          break;
        case 'unrealizedpl':
          indices['unrealizedPnL'] = i;
          break;
        case 'fxratetobase':
          indices['fxRateToBase'] = i;
          break;
      }
    }
    
    return indices;
  }

  /// Parse a single position line
  static Position? _parsePositionLine(List<dynamic> line, Map<String, int> indices) {
    try {
      // Get values with safe access
      final symbol = _getValueSafe(line, indices['symbol']);
      final description = _getValueSafe(line, indices['description']);
      
      // Skip if no symbol or description
      if (symbol.isEmpty && description.isEmpty) return null;
      
      // Skip "Total" rows
      if (symbol.toLowerCase().startsWith('total')) return null;
      
      final assetType = _normalizeAssetType(_getValueSafe(line, indices['assetType']));
      final currency = _getValueSafe(line, indices['currency']).toUpperCase();
      final sector = _normalizeSector(_getValueSafe(line, indices['sector']));
      
      final quantity = _parseDoubleSafe(_getValueSafe(line, indices['quantity']));
      final closePrice = _parseDoubleSafe(_getValueSafe(line, indices['closePrice']));
      final value = _parseDoubleSafe(_getValueSafe(line, indices['value']));
      final costBasis = _parseDoubleSafe(_getValueSafe(line, indices['costBasis']));
      final unrealizedPnL = _parseDoubleSafe(_getValueSafe(line, indices['unrealizedPnL']));
      final fxRateToBase = _parseDoubleSafe(_getValueSafe(line, indices['fxRateToBase']), defaultValue: 1.0);
      
      // Skip zero quantity positions
      if (quantity == 0 && value == 0) return null;
      
      return Position(
        id: _uuid.v4(),
        symbol: symbol,
        name: description,
        assetType: assetType,
        sector: sector,
        currency: currency,
        quantity: quantity,
        closePrice: closePrice,
        value: value,
        costBasis: costBasis,
        unrealizedPnL: unrealizedPnL,
        fxRateToBase: fxRateToBase,
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      // Return null if parsing fails for this position
      return null;
    }
  }

  /// Safely get value from list
  static String _getValueSafe(List<dynamic> line, int? index) {
    if (index == null || index < 0 || index >= line.length) {
      return '';
    }
    return line[index].toString().trim();
  }

  /// Safely parse double
  static double _parseDoubleSafe(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    
    final str = value.toString().trim();
    if (str.isEmpty || str == '-' || str == 'N/A') {
      return defaultValue;
    }
    
    // Remove currency symbols and formatting
    final cleaned = str
        .replaceAll(',', '')
        .replaceAll('\$', '')
        .replaceAll('EUR', '')
        .replaceAll('USD', '')
        .replaceAll(' ', '')
        .trim();
    
    return double.tryParse(cleaned) ?? defaultValue;
  }

  /// Safely parse int
  static int? _parseIntSafe(String? value) {
    if (value == null || value.isEmpty || value == '-') {
      return null;
    }
    return int.tryParse(value.replaceAll(',', '').trim());
  }

  /// Normalize asset type to standard format
  static String _normalizeAssetType(String assetType) {
    final lower = assetType.toLowerCase().trim();
    
    if (lower.contains('etf')) return 'ETFs';
    if (lower.contains('stock')) return 'Stocks';
    if (lower.contains('bond')) return 'Bonds';
    if (lower.contains('option')) return 'Options';
    if (lower.contains('future')) return 'Futures';
    if (lower.contains('forex') || lower.contains('fx')) return 'Forex';
    if (lower.contains('crypto')) return 'Crypto';
    if (lower.contains('commodity')) return 'Commodities';
    
    // Default based on common patterns
    if (assetType.isEmpty) return 'Other';
    
    // Return original with first letter capitalized
    return assetType[0].toUpperCase() + assetType.substring(1);
  }

  /// Normalize sector to standard format
  static String _normalizeSector(String sector) {
    final lower = sector.toLowerCase().trim();
    
    if (lower.isEmpty) return 'Other';
    if (lower.contains('tech')) return 'Technology';
    if (lower.contains('financ')) return 'Financials';
    if (lower.contains('health') || lower.contains('pharma')) return 'Healthcare';
    if (lower.contains('consumer') && lower.contains('cycl')) return 'Consumer Cyclicals';
    if (lower.contains('consumer') && lower.contains('non')) return 'Consumer Non-Cyclicals';
    if (lower.contains('industrial')) return 'Industrials';
    if (lower.contains('material') || lower.contains('basic')) return 'Basic Materials';
    if (lower.contains('energy')) return 'Energy';
    if (lower.contains('utilit')) return 'Utilities';
    if (lower.contains('real') || lower.contains('estate')) return 'Real Estate';
    if (lower.contains('broad') || lower.contains('diversif')) return 'Broad';
    
    // Return original with first letter capitalized
    return sector[0].toUpperCase() + sector.substring(1);
  }
}
