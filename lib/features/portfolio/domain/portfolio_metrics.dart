import 'dart:math' as math;

import 'entities/portfolio_entities.dart';
import 'utils/portfolio_region_mapper.dart';

/// Aggregated, derived portfolio metrics used both by the UI dashboard and by
/// the AI analysis prompt builder.
///
/// All percentage fields are expressed in percent (e.g. 12.5 means 12.5%).
/// All monetary fields are expressed in the portfolio base currency.
class PortfolioMetricsSnapshot {
  final int positionCount;
  final int profitablePositions;
  final int losingPositions;

  final double totalValueBase;
  final double totalCostBasisBase;
  final double totalUnrealizedPnLBase;
  final double totalPnLPercent;

  final double top1ConcentrationPercent;
  final double top5ConcentrationPercent;
  final double top10ConcentrationPercent;

  /// Herfindahl-Hirschman Index on weights (0..10000). Higher means more
  /// concentrated. <1500 is considered diversified, >2500 highly concentrated.
  final double herfindahlIndex;

  /// effectiveN = 1 / sum(w_i^2). Approximates the "number of equally weighted
  /// positions" the portfolio behaves like.
  final double effectiveNumberOfPositions;

  /// Region allocation in base currency keyed by region code from
  /// [PortfolioRegionMapper] (e.g. "us", "europe", ...).
  final Map<String, double> regionAllocation;

  /// Sector allocation in base currency.
  final Map<String, double> sectorAllocation;

  /// Asset type allocation in base currency.
  final Map<String, double> assetTypeAllocation;

  /// Currency exposure in base currency keyed by ISO code.
  final Map<String, double> currencyAllocation;

  /// Share of portfolio value (in percent) denominated in the base currency.
  final double baseCurrencyExposurePercent;

  const PortfolioMetricsSnapshot({
    required this.positionCount,
    required this.profitablePositions,
    required this.losingPositions,
    required this.totalValueBase,
    required this.totalCostBasisBase,
    required this.totalUnrealizedPnLBase,
    required this.totalPnLPercent,
    required this.top1ConcentrationPercent,
    required this.top5ConcentrationPercent,
    required this.top10ConcentrationPercent,
    required this.herfindahlIndex,
    required this.effectiveNumberOfPositions,
    required this.regionAllocation,
    required this.sectorAllocation,
    required this.assetTypeAllocation,
    required this.currencyAllocation,
    required this.baseCurrencyExposurePercent,
  });

  /// Returns region allocation expressed as percent of total value.
  Map<String, double> get regionAllocationPercent =>
      _toPercentMap(regionAllocation, totalValueBase);

  Map<String, double> get sectorAllocationPercent =>
      _toPercentMap(sectorAllocation, totalValueBase);

  Map<String, double> get assetTypeAllocationPercent =>
      _toPercentMap(assetTypeAllocation, totalValueBase);

  Map<String, double> get currencyAllocationPercent =>
      _toPercentMap(currencyAllocation, totalValueBase);

  static Map<String, double> _toPercentMap(
    Map<String, double> raw,
    double total,
  ) {
    if (total <= 0) return const <String, double>{};
    final out = <String, double>{};
    for (final entry in raw.entries) {
      out[entry.key] = (entry.value / total) * 100.0;
    }
    return out;
  }
}

/// Produces a [PortfolioMetricsSnapshot] from a [Portfolio] without mutating it.
///
/// All math is local and side-effect free, so it is safe to call this in a
/// build() if needed (cheap for typical portfolios).
class PortfolioMetrics {
  PortfolioMetrics._();

  static PortfolioMetricsSnapshot compute(Portfolio portfolio) {
    final positions = portfolio.positions;
    final totalValue = portfolio.totalValue;

    if (positions.isEmpty || totalValue <= 0) {
      return PortfolioMetricsSnapshot(
        positionCount: positions.length,
        profitablePositions: 0,
        losingPositions: 0,
        totalValueBase: totalValue,
        totalCostBasisBase: portfolio.totalCostBasis,
        totalUnrealizedPnLBase: portfolio.totalUnrealizedPnL,
        totalPnLPercent: portfolio.totalPnLPercent,
        top1ConcentrationPercent: 0,
        top5ConcentrationPercent: 0,
        top10ConcentrationPercent: 0,
        herfindahlIndex: 0,
        effectiveNumberOfPositions: 0,
        regionAllocation: const <String, double>{},
        sectorAllocation: const <String, double>{},
        assetTypeAllocation: const <String, double>{},
        currencyAllocation: const <String, double>{},
        baseCurrencyExposurePercent: 0,
      );
    }

    final sortedByValue = List<Position>.from(positions)
      ..sort(
          (a, b) => b.valueInBaseCurrency.compareTo(a.valueInBaseCurrency));

    final weights = <double>[];
    double sumSquaredWeights = 0.0;
    int profitable = 0;
    int losing = 0;

    final regionAlloc = <String, double>{};

    for (final position in sortedByValue) {
      final v = position.valueInBaseCurrency;
      if (v <= 0) {
        weights.add(0);
      } else {
        final w = v / totalValue;
        weights.add(w);
        sumSquaredWeights += w * w;
      }
      if (position.unrealizedPnL > 0) {
        profitable++;
      } else if (position.unrealizedPnL < 0) {
        losing++;
      }

      final regionCode = PortfolioRegionMapper.resolveRegionCode(position);
      regionAlloc[regionCode] = (regionAlloc[regionCode] ?? 0) + v;
    }

    double cumulative(int n) {
      final upper = math.min(n, weights.length);
      double sum = 0.0;
      for (var i = 0; i < upper; i++) {
        sum += weights[i];
      }
      return sum * 100.0;
    }

    final hhi = sumSquaredWeights * 10000.0;
    final effectiveN =
        sumSquaredWeights > 0 ? 1.0 / sumSquaredWeights : 0.0;

    final baseCurrency = portfolio.baseCurrency.toUpperCase();
    double baseExposure = 0.0;
    final currencyAlloc = portfolio.currencyAllocation;
    for (final entry in currencyAlloc.entries) {
      if (entry.key.toUpperCase() == baseCurrency) {
        baseExposure = entry.value;
        break;
      }
    }
    final baseCurrencyExposurePercent =
        totalValue > 0 ? (baseExposure / totalValue) * 100.0 : 0.0;

    return PortfolioMetricsSnapshot(
      positionCount: positions.length,
      profitablePositions: profitable,
      losingPositions: losing,
      totalValueBase: totalValue,
      totalCostBasisBase: portfolio.totalCostBasis,
      totalUnrealizedPnLBase: portfolio.totalUnrealizedPnL,
      totalPnLPercent: portfolio.totalPnLPercent,
      top1ConcentrationPercent: cumulative(1),
      top5ConcentrationPercent: cumulative(5),
      top10ConcentrationPercent: cumulative(10),
      herfindahlIndex: hhi,
      effectiveNumberOfPositions: effectiveN,
      regionAllocation: regionAlloc,
      sectorAllocation: portfolio.sectorAllocation,
      assetTypeAllocation: portfolio.assetTypeAllocation,
      currencyAllocation: currencyAlloc,
      baseCurrencyExposurePercent: baseCurrencyExposurePercent,
    );
  }
}
