import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';

/// Parser for Interactive Brokers (IBKR) CSV files
/// Handles the complex multi-section format of IBKR PortfolioAnalyst exports
class IBKRParser extends BaseBrokerParser {
  @override
  String get brokerId => 'ibkr';

  @override
  String get brokerName => 'Interactive Brokers';

  @override
  String get defaultCurrency => 'EUR';

  /// Parse IBKR CSV content and return a Portfolio object
  @override
  Portfolio parse(String csvContent) {
    // Use the shared CSV loader to normalize CRLF -> LF and strip any BOM;
    // previously CsvToListConverter was instantiated inline which left
    // Windows IBKR exports with trailing empty cells.
    final lines = BaseBrokerParser.parseCSV(csvContent);

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
      id: BaseBrokerParser.generateId(),
      accountId: introData['account'] ?? '',
      accountName: introData['name'] ?? '',
      baseCurrency: introData['baseCurrency'] ?? 'EUR',
      broker: 'ibkr',
      positions: positions,
      profile: PortfolioProfile(
        name: profileData['name'] ?? '',
        accountType: profileData['accountType'] ?? 'Individual',
        age: BaseBrokerParser.parseIntSafe(profileData['age']),
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

  /// Parse Key Statistics section using header-name lookup so IBKR column
  /// re-orderings don't silently shift values.
  static PortfolioStatistics? _parseKeyStatistics(List<List<dynamic>> lines) {
    var indices = <String, int>{};

    for (final line in lines) {
      if (line.isEmpty || line[0].toString() != 'Key Statistics') continue;
      if (line.length < 2) continue;

      final rowType = line[1].toString();
      if (rowType == 'Header') {
        indices = _parseKeyStatsHeader(line);
        continue;
      }
      if (rowType != 'Data') continue;

      try {
        double v(String key, {double fallback = 0.0}) =>
            BaseBrokerParser.parseDoubleSafe(
              BaseBrokerParser.getValueSafe(line, indices[key]),
              defaultValue: fallback,
            );
        String? s(String key) {
          final raw = BaseBrokerParser.getValueSafe(line, indices[key]);
          return raw.isEmpty ? null : raw;
        }
        double? vOpt(String key) {
          final raw = BaseBrokerParser.getValueSafe(line, indices[key]);
          return raw.isEmpty ? null : BaseBrokerParser.parseDoubleSafe(raw);
        }

        return PortfolioStatistics(
          beginningNAV: v('beginningNAV'),
          endingNAV: v('endingNAV'),
          cumulativeReturn: v('cumulativeReturn'),
          oneMonthReturn: v('oneMonthReturn'),
          threeMonthReturn: v('threeMonthReturn'),
          bestReturn: vOpt('bestReturn'),
          bestReturnDate: s('bestReturnDate'),
          worstReturn: vOpt('worstReturn'),
          worstReturnDate: s('worstReturnDate'),
          mtm: v('mtm'),
          depositsWithdrawals: v('depositsWithdrawals'),
          dividends: v('dividends'),
          interest: v('interest'),
          feesCommissions: v('feesCommissions'),
          changeInNAV: v('changeInNAV'),
        );
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Map Key Statistics header tokens to canonical field names
  static Map<String, int> _parseKeyStatsHeader(List<dynamic> line) {
    final indices = <String, int>{};
    for (var i = 2; i < line.length; i++) {
      final token = line[i]
          .toString()
          .toLowerCase()
          .replaceAll(' ', '')
          .replaceAll('&', '')
          .replaceAll('-', '');
      switch (token) {
        case 'beginningnav':
          indices['beginningNAV'] = i;
          break;
        case 'endingnav':
          indices['endingNAV'] = i;
          break;
        case 'cumulativereturn':
          indices['cumulativeReturn'] = i;
          break;
        case 'onemonthreturn':
        case 'mtdreturn':
        case 'monthtodatereturn':
          indices['oneMonthReturn'] = i;
          break;
        case 'threemonthreturn':
        case 'qtdreturn':
        case 'quartertodatereturn':
          indices['threeMonthReturn'] = i;
          break;
        case 'bestreturn':
          indices['bestReturn'] = i;
          break;
        case 'bestreturndate':
          indices['bestReturnDate'] = i;
          break;
        case 'worstreturn':
          indices['worstReturn'] = i;
          break;
        case 'worstreturndate':
          indices['worstReturnDate'] = i;
          break;
        case 'mtm':
          indices['mtm'] = i;
          break;
        case 'depositswithdrawals':
        case 'depositswithdrawal':
          indices['depositsWithdrawals'] = i;
          break;
        case 'dividends':
          indices['dividends'] = i;
          break;
        case 'interest':
          indices['interest'] = i;
          break;
        case 'feescommissions':
        case 'feesandcommissions':
          indices['feesCommissions'] = i;
          break;
        case 'changeinnav':
        case 'changeinnetassetvalue':
          indices['changeInNAV'] = i;
          break;
      }
    }
    return indices;
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
                accountReturn: BaseBrokerParser.parseDoubleSafe(returnValue),
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
      final symbol = BaseBrokerParser.getValueSafe(line, indices['symbol']);
      final description =
          BaseBrokerParser.getValueSafe(line, indices['description']);

      // Skip if no symbol or description
      if (symbol.isEmpty && description.isEmpty) return null;

      // Skip "Total" rows
      if (symbol.toLowerCase().startsWith('total')) return null;

      final assetType = BaseBrokerParser.normalizeAssetType(
        BaseBrokerParser.getValueSafe(line, indices['assetType']),
      );
      final currency = BaseBrokerParser.getValueSafe(line, indices['currency'])
          .toUpperCase();
      final sector = BaseBrokerParser.normalizeSector(
        BaseBrokerParser.getValueSafe(line, indices['sector']),
      );

      final quantity = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['quantity']),
      );
      final closePrice = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['closePrice']),
      );
      final value = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['value']),
      );
      final costBasis = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['costBasis']),
      );
      final unrealizedPnL = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['unrealizedPnL']),
      );
      final fxRateToBase = BaseBrokerParser.parseDoubleSafe(
        BaseBrokerParser.getValueSafe(line, indices['fxRateToBase']),
        defaultValue: 1.0,
      );

      // Skip zero quantity positions
      if (quantity == 0 && value == 0) return null;

      return Position(
        id: BaseBrokerParser.generateId(),
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
}
