import 'package:equatable/equatable.dart';

/// Represents a single position in the portfolio
class Position extends Equatable {
  static const Object _regionOverrideUnset = Object();

  final String id;
  final String symbol;
  final String name;
  final String assetType; // stocks, etfs, crypto, bonds, options
  final String sector;
  final String currency;
  final double quantity;
  final double closePrice;
  final double value;
  final double costBasis;
  final double unrealizedPnL;
  final double fxRateToBase;
  final DateTime? lastUpdated;
  final String? exchange;
  final String? isin;
  final String? regionOverride;

  const Position({
    required this.id,
    required this.symbol,
    required this.name,
    required this.assetType,
    required this.sector,
    required this.currency,
    required this.quantity,
    required this.closePrice,
    required this.value,
    required this.costBasis,
    required this.unrealizedPnL,
    this.fxRateToBase = 1.0,
    this.lastUpdated,
    this.exchange,
    this.isin,
    this.regionOverride,
  });

  /// Calculate P&L percentage
  double get pnlPercent {
    if (costBasis == 0) return 0.0;
    return (unrealizedPnL / costBasis) * 100;
  }

  /// Check if position is profitable
  bool get isProfitable => unrealizedPnL >= 0;

  /// Get value in base currency
  double get valueInBaseCurrency => value * fxRateToBase;

  /// Get cost basis in base currency
  double get costBasisInBaseCurrency => costBasis * fxRateToBase;

  /// Get unrealized P&L in base currency
  double get unrealizedPnLInBaseCurrency => unrealizedPnL * fxRateToBase;

  /// Create a copy with updated values
  Position copyWith({
    String? id,
    String? symbol,
    String? name,
    String? assetType,
    String? sector,
    String? currency,
    double? quantity,
    double? closePrice,
    double? value,
    double? costBasis,
    double? unrealizedPnL,
    double? fxRateToBase,
    DateTime? lastUpdated,
    String? exchange,
    String? isin,
    Object? regionOverride = _regionOverrideUnset,
  }) {
    return Position(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      assetType: assetType ?? this.assetType,
      sector: sector ?? this.sector,
      currency: currency ?? this.currency,
      quantity: quantity ?? this.quantity,
      closePrice: closePrice ?? this.closePrice,
      value: value ?? this.value,
      costBasis: costBasis ?? this.costBasis,
      unrealizedPnL: unrealizedPnL ?? this.unrealizedPnL,
      fxRateToBase: fxRateToBase ?? this.fxRateToBase,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      exchange: exchange ?? this.exchange,
      isin: isin ?? this.isin,
      regionOverride: regionOverride == _regionOverrideUnset
          ? this.regionOverride
          : regionOverride as String?,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'symbol': symbol,
      'name': name,
      'assetType': assetType,
      'sector': sector,
      'currency': currency,
      'quantity': quantity,
      'closePrice': closePrice,
      'value': value,
      'costBasis': costBasis,
      'unrealizedPnL': unrealizedPnL,
      'fxRateToBase': fxRateToBase,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'exchange': exchange,
      'isin': isin,
      'regionOverride': regionOverride,
    };
  }

  /// Create from JSON map
  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      id: json['id'] as String,
      symbol: json['symbol'] as String,
      name: json['name'] as String,
      assetType: json['assetType'] as String,
      sector: json['sector'] as String,
      currency: json['currency'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      closePrice: (json['closePrice'] as num).toDouble(),
      value: (json['value'] as num).toDouble(),
      costBasis: (json['costBasis'] as num).toDouble(),
      unrealizedPnL: (json['unrealizedPnL'] as num).toDouble(),
      fxRateToBase: (json['fxRateToBase'] as num?)?.toDouble() ?? 1.0,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String) 
          : null,
      exchange: json['exchange'] as String?,
      isin: json['isin'] as String?,
      regionOverride: json['regionOverride'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    id, symbol, name, assetType, sector, currency, 
    quantity, closePrice, value, costBasis, unrealizedPnL,
    fxRateToBase, lastUpdated, exchange, isin, regionOverride,
  ];
}

/// Tracks a single import source for a portfolio
class ImportSource extends Equatable {
  final String brokerId;
  final String fileName;
  final DateTime importedAt;
  final int positionCount;

  const ImportSource({
    required this.brokerId,
    required this.fileName,
    required this.importedAt,
    required this.positionCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'brokerId': brokerId,
      'fileName': fileName,
      'importedAt': importedAt.toIso8601String(),
      'positionCount': positionCount,
    };
  }

  factory ImportSource.fromJson(Map<String, dynamic> json) {
    return ImportSource(
      brokerId: json['brokerId'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      importedAt: json['importedAt'] != null
          ? DateTime.parse(json['importedAt'] as String)
          : DateTime.fromMillisecondsSinceEpoch(0),
      positionCount: (json['positionCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [brokerId, fileName, importedAt, positionCount];
}

/// Represents the entire portfolio
class Portfolio extends Equatable {
  final String id;
  final String accountId;
  final String accountName;
  final String baseCurrency;
  final String broker;
  final List<Position> positions;
  // [UPDATED] Track import history and manual edit capability
  final List<ImportSource> importSources;
  final bool allowManualEdits;
  final PortfolioProfile? profile;
  final PortfolioStatistics? statistics;
  final List<PerformanceRecord>? historicalPerformance;
  final DateTime? lastUpdated;
  final DateTime? importedAt;

  const Portfolio({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.baseCurrency,
    required this.broker,
    required this.positions,
    this.importSources = const [],
    this.allowManualEdits = true,
    this.profile,
    this.statistics,
    this.historicalPerformance,
    this.lastUpdated,
    this.importedAt,
  });

  /// Calculate total value in base currency
  double get totalValue {
    return positions.fold(0.0, (sum, pos) => sum + pos.valueInBaseCurrency);
  }

  /// Calculate total cost basis in base currency
  double get totalCostBasis {
    return positions.fold(0.0, (sum, pos) => sum + pos.costBasisInBaseCurrency);
  }

  /// Calculate total unrealized P&L in base currency
  double get totalUnrealizedPnL {
    return positions.fold(0.0, (sum, pos) => sum + pos.unrealizedPnLInBaseCurrency);
  }

  /// Calculate total P&L percentage
  double get totalPnLPercent {
    if (totalCostBasis == 0) return 0.0;
    return (totalUnrealizedPnL / totalCostBasis) * 100;
  }

  /// Get positions by asset type
  List<Position> getPositionsByType(String assetType) {
    return positions.where((p) => p.assetType.toLowerCase() == assetType.toLowerCase()).toList();
  }

  /// Get positions by sector
  List<Position> getPositionsBySector(String sector) {
    return positions.where((p) => p.sector.toLowerCase() == sector.toLowerCase()).toList();
  }

  /// Get positions by currency
  List<Position> getPositionsByCurrency(String currency) {
    return positions.where((p) => p.currency.toUpperCase() == currency.toUpperCase()).toList();
  }

  /// Get sector allocation
  Map<String, double> get sectorAllocation {
    final allocation = <String, double>{};
    for (final position in positions) {
      final sector = position.sector.isEmpty ? 'Other' : position.sector;
      allocation[sector] = (allocation[sector] ?? 0) + position.valueInBaseCurrency;
    }
    return allocation;
  }

  /// Get asset type allocation
  Map<String, double> get assetTypeAllocation {
    final allocation = <String, double>{};
    for (final position in positions) {
      allocation[position.assetType] = (allocation[position.assetType] ?? 0) + position.valueInBaseCurrency;
    }
    return allocation;
  }

  /// Get currency allocation
  Map<String, double> get currencyAllocation {
    final allocation = <String, double>{};
    for (final position in positions) {
      allocation[position.currency] = (allocation[position.currency] ?? 0) + position.valueInBaseCurrency;
    }
    return allocation;
  }

  /// Get top gainers (by P&L percentage)
  List<Position> getTopGainers({int limit = 5}) {
    final sorted = List<Position>.from(positions)
      ..sort((a, b) => b.pnlPercent.compareTo(a.pnlPercent));
    return sorted.take(limit).where((p) => p.pnlPercent > 0).toList();
  }

  /// Get top losers (by P&L percentage)
  List<Position> getTopLosers({int limit = 5}) {
    final sorted = List<Position>.from(positions)
      ..sort((a, b) => a.pnlPercent.compareTo(b.pnlPercent));
    return sorted.take(limit).where((p) => p.pnlPercent < 0).toList();
  }

  /// Create a copy with updated values
  Portfolio copyWith({
    String? id,
    String? accountId,
    String? accountName,
    String? baseCurrency,
    String? broker,
    List<Position>? positions,
    List<ImportSource>? importSources,
    bool? allowManualEdits,
    PortfolioProfile? profile,
    PortfolioStatistics? statistics,
    List<PerformanceRecord>? historicalPerformance,
    DateTime? lastUpdated,
    DateTime? importedAt,
  }) {
    return Portfolio(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      accountName: accountName ?? this.accountName,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      broker: broker ?? this.broker,
      positions: positions ?? this.positions,
      importSources: importSources ?? this.importSources,
      allowManualEdits: allowManualEdits ?? this.allowManualEdits,
      profile: profile ?? this.profile,
      statistics: statistics ?? this.statistics,
      historicalPerformance: historicalPerformance ?? this.historicalPerformance,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      importedAt: importedAt ?? this.importedAt,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'accountName': accountName,
      'baseCurrency': baseCurrency,
      'broker': broker,
      'positions': positions.map((p) => p.toJson()).toList(),
      'importSources': importSources.map((s) => s.toJson()).toList(),
      'allowManualEdits': allowManualEdits,
      'profile': profile?.toJson(),
      'statistics': statistics?.toJson(),
      'historicalPerformance': historicalPerformance?.map((h) => h.toJson()).toList(),
      'lastUpdated': lastUpdated?.toIso8601String(),
      'importedAt': importedAt?.toIso8601String(),
    };
  }

  /// Create from JSON map
  factory Portfolio.fromJson(Map<String, dynamic> json) {
    return Portfolio(
      id: json['id'] as String,
      accountId: json['accountId'] as String,
      accountName: json['accountName'] as String,
      baseCurrency: json['baseCurrency'] as String,
      broker: json['broker'] as String,
      positions: (json['positions'] as List)
          .map((p) => Position.fromJson(p as Map<String, dynamic>))
          .toList(),
      importSources: json['importSources'] != null
          ? (json['importSources'] as List)
              .map((s) => ImportSource.fromJson(s as Map<String, dynamic>))
              .toList()
          : const [],
      allowManualEdits: json['allowManualEdits'] as bool? ?? true,
      profile: json['profile'] != null 
          ? PortfolioProfile.fromJson(json['profile'] as Map<String, dynamic>) 
          : null,
      statistics: json['statistics'] != null 
          ? PortfolioStatistics.fromJson(json['statistics'] as Map<String, dynamic>) 
          : null,
      historicalPerformance: json['historicalPerformance'] != null 
          ? (json['historicalPerformance'] as List)
              .map((h) => PerformanceRecord.fromJson(h as Map<String, dynamic>))
              .toList()
          : null,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.parse(json['lastUpdated'] as String) 
          : null,
      importedAt: json['importedAt'] != null 
          ? DateTime.parse(json['importedAt'] as String) 
          : null,
    );
  }

  /// Create empty portfolio
  factory Portfolio.empty() {
    return Portfolio(
      id: '',
      accountId: '',
      accountName: '',
      baseCurrency: 'EUR',
      broker: '',
      positions: const [],
      importSources: const [],
      allowManualEdits: true,
    );
  }

  @override
  List<Object?> get props => [
    id, accountId, accountName, baseCurrency, broker, positions,
    importSources, allowManualEdits,
    profile, statistics, historicalPerformance, lastUpdated, importedAt,
  ];
}

/// Portfolio profile information
class PortfolioProfile extends Equatable {
  final String name;
  final String accountType;
  final int? age;
  final String? investmentObjectives;
  final String? estimatedNetWorth;
  final String? estimatedLiquidNetWorth;
  final String? annualNetIncome;

  const PortfolioProfile({
    required this.name,
    required this.accountType,
    this.age,
    this.investmentObjectives,
    this.estimatedNetWorth,
    this.estimatedLiquidNetWorth,
    this.annualNetIncome,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'accountType': accountType,
      'age': age,
      'investmentObjectives': investmentObjectives,
      'estimatedNetWorth': estimatedNetWorth,
      'estimatedLiquidNetWorth': estimatedLiquidNetWorth,
      'annualNetIncome': annualNetIncome,
    };
  }

  factory PortfolioProfile.fromJson(Map<String, dynamic> json) {
    return PortfolioProfile(
      name: json['name'] as String,
      accountType: json['accountType'] as String,
      age: json['age'] as int?,
      investmentObjectives: json['investmentObjectives'] as String?,
      estimatedNetWorth: json['estimatedNetWorth'] as String?,
      estimatedLiquidNetWorth: json['estimatedLiquidNetWorth'] as String?,
      annualNetIncome: json['annualNetIncome'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    name, accountType, age, investmentObjectives,
    estimatedNetWorth, estimatedLiquidNetWorth, annualNetIncome,
  ];
}

/// Portfolio statistics
class PortfolioStatistics extends Equatable {
  final double beginningNAV;
  final double endingNAV;
  final double cumulativeReturn;
  final double oneMonthReturn;
  final double threeMonthReturn;
  final double? bestReturn;
  final String? bestReturnDate;
  final double? worstReturn;
  final String? worstReturnDate;
  final double mtm;
  final double depositsWithdrawals;
  final double dividends;
  final double interest;
  final double feesCommissions;
  final double changeInNAV;

  const PortfolioStatistics({
    required this.beginningNAV,
    required this.endingNAV,
    required this.cumulativeReturn,
    required this.oneMonthReturn,
    required this.threeMonthReturn,
    this.bestReturn,
    this.bestReturnDate,
    this.worstReturn,
    this.worstReturnDate,
    required this.mtm,
    required this.depositsWithdrawals,
    required this.dividends,
    required this.interest,
    required this.feesCommissions,
    required this.changeInNAV,
  });

  Map<String, dynamic> toJson() {
    return {
      'beginningNAV': beginningNAV,
      'endingNAV': endingNAV,
      'cumulativeReturn': cumulativeReturn,
      'oneMonthReturn': oneMonthReturn,
      'threeMonthReturn': threeMonthReturn,
      'bestReturn': bestReturn,
      'bestReturnDate': bestReturnDate,
      'worstReturn': worstReturn,
      'worstReturnDate': worstReturnDate,
      'mtm': mtm,
      'depositsWithdrawals': depositsWithdrawals,
      'dividends': dividends,
      'interest': interest,
      'feesCommissions': feesCommissions,
      'changeInNAV': changeInNAV,
    };
  }

  factory PortfolioStatistics.fromJson(Map<String, dynamic> json) {
    return PortfolioStatistics(
      beginningNAV: (json['beginningNAV'] as num).toDouble(),
      endingNAV: (json['endingNAV'] as num).toDouble(),
      cumulativeReturn: (json['cumulativeReturn'] as num).toDouble(),
      oneMonthReturn: (json['oneMonthReturn'] as num).toDouble(),
      threeMonthReturn: (json['threeMonthReturn'] as num).toDouble(),
      bestReturn: (json['bestReturn'] as num?)?.toDouble(),
      bestReturnDate: json['bestReturnDate'] as String?,
      worstReturn: (json['worstReturn'] as num?)?.toDouble(),
      worstReturnDate: json['worstReturnDate'] as String?,
      mtm: (json['mtm'] as num).toDouble(),
      depositsWithdrawals: (json['depositsWithdrawals'] as num).toDouble(),
      dividends: (json['dividends'] as num).toDouble(),
      interest: (json['interest'] as num).toDouble(),
      feesCommissions: (json['feesCommissions'] as num).toDouble(),
      changeInNAV: (json['changeInNAV'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [
    beginningNAV, endingNAV, cumulativeReturn, oneMonthReturn, threeMonthReturn,
    bestReturn, bestReturnDate, worstReturn, worstReturnDate, mtm,
    depositsWithdrawals, dividends, interest, feesCommissions, changeInNAV,
  ];
}

/// Historical performance record
class PerformanceRecord extends Equatable {
  final String period; // YYYYMM or YYYY Qn or YTD
  final String periodType; // month, quarter, year
  final double? accountReturn;

  const PerformanceRecord({
    required this.period,
    required this.periodType,
    this.accountReturn,
  });

  Map<String, dynamic> toJson() {
    return {
      'period': period,
      'periodType': periodType,
      'accountReturn': accountReturn,
    };
  }

  factory PerformanceRecord.fromJson(Map<String, dynamic> json) {
    return PerformanceRecord(
      period: json['period'] as String,
      periodType: json['periodType'] as String,
      accountReturn: (json['accountReturn'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props => [period, periodType, accountReturn];
}
