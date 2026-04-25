import '../../portfolio/domain/entities/portfolio_entities.dart';
import '../../portfolio/domain/portfolio_metrics.dart';
import '../../portfolio/domain/utils/portfolio_region_mapper.dart';
import 'analysis_preset.dart';

/// Builds the textual prompt sent to the AI agent for portfolio analysis.
///
/// This is intentionally decoupled from any HTTP client so that:
///   - the UI can render an exact preview of the payload (transparency
///     requirement: the user must be able to see what we are about to send),
///   - tests can assert on the prompt without spinning up Dio.
class AnalysisPromptBuilder {
  AnalysisPromptBuilder._();

  /// Hard cap on positions included in analysis prompts to bound token usage.
  /// Portfolios with more positions get a "top N by value" slice and a summary
  /// note instead of the full list.
  static const int maxPositionsInPrompt = 50;

  /// Returns the full prompt that would be sent to the AI agent.
  ///
  /// The prompt is split in three deterministic sections:
  ///   1. SCOPE OF DATA: an explicit list of what slices the agent can see
  ///      (and which were intentionally excluded by the user).
  ///   2. PORTFOLIO DATA: one block per active slice.
  ///   3. ANALYSIS REQUEST: either the [presetInstruction] or [customPrompt].
  static String build({
    required Portfolio portfolio,
    required String language,
    String? customPrompt,
    Set<AnalysisDataSlice>? slices,
    String? presetInstruction,
  }) {
    final activeSlices = <AnalysisDataSlice>{
      AnalysisDataSlice.coreSummary,
      ...?slices,
    };
    final excludedSlices = AnalysisDataSlice.values
        .where((s) => !activeSlices.contains(s))
        .toList();

    final needsMetrics =
        activeSlices.contains(AnalysisDataSlice.regionAllocation) ||
            activeSlices.contains(AnalysisDataSlice.concentration);
    final metrics =
        needsMetrics ? PortfolioMetrics.compute(portfolio) : null;

    final buffer = StringBuffer();

    buffer.writeln(_languageInstruction(language));
    buffer.writeln();
    buffer.writeln(
        'You are a professional financial analyst and portfolio advisor.');
    buffer.writeln(
        'Analyze the following investment portfolio and provide detailed insights.');
    buffer.writeln();

    buffer.writeln('=== SCOPE OF DATA YOU ARE SEEING ===');
    buffer.writeln(
        'The user explicitly opted in to share with you the following data slices:');
    for (final slice in activeSlices) {
      buffer.writeln('- ${_sliceLabel(slice)}');
    }
    if (excludedSlices.isNotEmpty) {
      buffer.writeln(
          'The following data slices were withheld by the user; do not assume them:');
      for (final slice in excludedSlices) {
        buffer.writeln('- ${_sliceLabel(slice)}');
      }
    }
    buffer.writeln(
        'Stay strictly within the data above. Do not fabricate prices, returns or positions that are not in the input.');
    buffer.writeln();

    if (activeSlices.contains(AnalysisDataSlice.coreSummary)) {
      _writeCoreSummary(buffer, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.investorProfile) &&
        portfolio.profile != null) {
      _writeInvestorProfile(buffer, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.statistics) &&
        portfolio.statistics != null) {
      _writeStatistics(buffer, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.performanceHistory) &&
        portfolio.historicalPerformance != null &&
        portfolio.historicalPerformance!.isNotEmpty) {
      _writePerformanceHistory(buffer, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.holdings)) {
      _writeHoldings(buffer, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.sectorAllocation)) {
      _writeAllocation(
          buffer, 'SECTOR ALLOCATION', portfolio.sectorAllocation, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.assetAllocation)) {
      _writeAllocation(buffer, 'ASSET TYPE ALLOCATION',
          portfolio.assetTypeAllocation, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.regionAllocation)) {
      _writeAllocation(buffer, 'GEOGRAPHIC ALLOCATION',
          metrics!.regionAllocation, portfolio,
          keyMapper: _humanRegion);
    }
    if (activeSlices.contains(AnalysisDataSlice.currencyAllocation)) {
      _writeAllocation(buffer, 'CURRENCY ALLOCATION',
          portfolio.currencyAllocation, portfolio);
    }
    if (activeSlices.contains(AnalysisDataSlice.concentration)) {
      _writeConcentration(buffer, portfolio, metrics!);
    }

    if (customPrompt != null && customPrompt.isNotEmpty) {
      buffer.writeln('=== USER REQUEST ===');
      buffer.writeln(customPrompt);
    } else if (presetInstruction != null && presetInstruction.isNotEmpty) {
      buffer.writeln('=== ANALYSIS REQUEST ===');
      buffer.writeln(presetInstruction);
    } else {
      buffer.writeln('=== ANALYSIS REQUEST ===');
      buffer.writeln(
          'Provide a structured analysis using only the data above. Cite specific tickers, sectors, regions or figures from the input when supporting claims.');
    }

    return buffer.toString();
  }

  static void _writeCoreSummary(StringBuffer buffer, Portfolio portfolio) {
    buffer.writeln('=== PORTFOLIO SUMMARY ===');
    buffer.writeln(
        'Account: ${portfolio.accountName} (${portfolio.accountId})');
    buffer.writeln('Base Currency: ${portfolio.baseCurrency}');
    buffer.writeln(
        'Total Value: ${portfolio.baseCurrency} ${portfolio.totalValue.toStringAsFixed(2)}');
    buffer.writeln(
        'Total Cost Basis: ${portfolio.baseCurrency} ${portfolio.totalCostBasis.toStringAsFixed(2)}');
    buffer.writeln(
        'Unrealized P&L: ${portfolio.baseCurrency} ${portfolio.totalUnrealizedPnL.toStringAsFixed(2)} (${portfolio.totalPnLPercent.toStringAsFixed(2)}%)');
    buffer.writeln('Number of Positions: ${portfolio.positions.length}');
    buffer.writeln();
  }

  static void _writeInvestorProfile(
      StringBuffer buffer, Portfolio portfolio) {
    final p = portfolio.profile!;
    buffer.writeln('=== INVESTOR PROFILE ===');
    buffer.writeln('Name: ${p.name}');
    buffer.writeln('Account Type: ${p.accountType}');
    if (p.age != null) buffer.writeln('Age: ${p.age}');
    if (p.investmentObjectives != null) {
      buffer.writeln('Objectives: ${p.investmentObjectives}');
    }
    if (p.estimatedNetWorth != null) {
      buffer.writeln('Estimated Net Worth: ${p.estimatedNetWorth}');
    }
    buffer.writeln();
  }

  static void _writeStatistics(StringBuffer buffer, Portfolio portfolio) {
    final stats = portfolio.statistics!;
    buffer.writeln('=== KEY STATISTICS ===');
    buffer.writeln(
        'Cumulative Return: ${stats.cumulativeReturn.toStringAsFixed(2)}%');
    buffer.writeln(
        '1 Month Return: ${stats.oneMonthReturn.toStringAsFixed(2)}%');
    buffer.writeln(
        '3 Month Return: ${stats.threeMonthReturn.toStringAsFixed(2)}%');
    if (stats.bestReturn != null) {
      buffer.writeln(
          'Best Return: ${stats.bestReturn!.toStringAsFixed(2)}% (${stats.bestReturnDate})');
    }
    if (stats.worstReturn != null) {
      buffer.writeln(
          'Worst Return: ${stats.worstReturn!.toStringAsFixed(2)}% (${stats.worstReturnDate})');
    }
    buffer.writeln(
        'Dividends Received: ${portfolio.baseCurrency} ${stats.dividends.toStringAsFixed(2)}');
    buffer.writeln(
        'Fees & Commissions: ${portfolio.baseCurrency} ${stats.feesCommissions.toStringAsFixed(2)}');
    buffer.writeln();
  }

  static void _writePerformanceHistory(
      StringBuffer buffer, Portfolio portfolio) {
    final history = portfolio.historicalPerformance!;
    buffer.writeln('=== PERFORMANCE HISTORY ===');
    for (final record in history) {
      final ret = record.accountReturn?.toStringAsFixed(2) ?? 'n/a';
      buffer.writeln('- ${record.period} (${record.periodType}): $ret%');
    }
    buffer.writeln();
  }

  static void _writeHoldings(StringBuffer buffer, Portfolio portfolio) {
    final totalPositions = portfolio.positions.length;
    final sortedPositions = List<Position>.from(portfolio.positions)
      ..sort((a, b) => b.valueInBaseCurrency.compareTo(a.valueInBaseCurrency));
    final positionsToInclude =
        sortedPositions.take(maxPositionsInPrompt).toList();
    if (totalPositions > maxPositionsInPrompt) {
      buffer.writeln(
          '=== POSITIONS (top $maxPositionsInPrompt of $totalPositions, sorted by value) ===');
    } else {
      buffer.writeln('=== POSITIONS ($totalPositions total) ===');
    }
    for (final position in positionsToInclude) {
      buffer.writeln('- ${position.symbol} (${position.name})');
      buffer.writeln(
          '  Type: ${position.assetType}, Sector: ${position.sector}');
      buffer.writeln(
          '  Qty: ${position.quantity.toStringAsFixed(4)}, Price: ${position.currency} ${position.closePrice.toStringAsFixed(2)}');
      buffer.writeln(
          '  Value: ${position.currency} ${position.value.toStringAsFixed(2)}');
      buffer.writeln(
          '  Cost: ${position.currency} ${position.costBasis.toStringAsFixed(2)}');
      buffer.writeln(
          '  P&L: ${position.currency} ${position.unrealizedPnL.toStringAsFixed(2)} (${position.pnlPercent.toStringAsFixed(2)}%)');
    }
    buffer.writeln();
  }

  static void _writeAllocation(
    StringBuffer buffer,
    String title,
    Map<String, double> allocation,
    Portfolio portfolio, {
    String Function(String)? keyMapper,
  }) {
    buffer.writeln('=== $title ===');
    final total = portfolio.totalValue;
    if (allocation.isEmpty || total <= 0) {
      buffer.writeln('(no data)');
      buffer.writeln();
      return;
    }
    final sorted = allocation.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sorted) {
      final percent = (entry.value / total * 100).toStringAsFixed(1);
      final label = keyMapper != null ? keyMapper(entry.key) : entry.key;
      buffer.writeln(
          '- $label: ${portfolio.baseCurrency} ${entry.value.toStringAsFixed(2)} ($percent%)');
    }
    buffer.writeln();
  }

  static void _writeConcentration(StringBuffer buffer, Portfolio portfolio,
      PortfolioMetricsSnapshot metrics) {
    buffer.writeln('=== CONCENTRATION METRICS ===');
    buffer.writeln(
        'Top 1 holding: ${metrics.top1ConcentrationPercent.toStringAsFixed(1)}% of portfolio');
    buffer.writeln(
        'Top 5 holdings: ${metrics.top5ConcentrationPercent.toStringAsFixed(1)}% of portfolio');
    buffer.writeln(
        'Top 10 holdings: ${metrics.top10ConcentrationPercent.toStringAsFixed(1)}% of portfolio');
    buffer.writeln(
        'Herfindahl-Hirschman Index (0-10000): ${metrics.herfindahlIndex.toStringAsFixed(0)}');
    buffer.writeln(
        'Effective number of equally weighted positions: ${metrics.effectiveNumberOfPositions.toStringAsFixed(1)}');
    buffer.writeln(
        'Profitable positions: ${metrics.profitablePositions} / ${metrics.positionCount}');
    buffer.writeln(
        'Base currency (${portfolio.baseCurrency}) exposure: ${metrics.baseCurrencyExposurePercent.toStringAsFixed(1)}%');
    buffer.writeln();
  }

  static String _languageInstruction(String language) {
    switch (language) {
      case 'it':
        return 'Rispondi sempre in italiano.';
      case 'fr':
        return 'Reponds toujours en francais.';
      case 'de':
        return 'Antworte immer auf Deutsch.';
      case 'es':
        return 'Responde siempre en espanol.';
      case 'pt':
        return 'Responda sempre em portugues.';
      default:
        return 'Always respond in English.';
    }
  }

  static String _sliceLabel(AnalysisDataSlice slice) {
    switch (slice) {
      case AnalysisDataSlice.coreSummary:
        return 'Account summary (name, base currency, total value, P&L)';
      case AnalysisDataSlice.holdings:
        return 'Top holdings (up to 50 by value)';
      case AnalysisDataSlice.sectorAllocation:
        return 'Sector allocation';
      case AnalysisDataSlice.assetAllocation:
        return 'Asset type allocation';
      case AnalysisDataSlice.regionAllocation:
        return 'Geographic allocation';
      case AnalysisDataSlice.currencyAllocation:
        return 'Currency allocation';
      case AnalysisDataSlice.concentration:
        return 'Concentration metrics (HHI, top N, effective N)';
      case AnalysisDataSlice.statistics:
        return 'Account statistics (cumulative return, dividends, fees)';
      case AnalysisDataSlice.performanceHistory:
        return 'Per-period performance history';
      case AnalysisDataSlice.investorProfile:
        return 'Investor profile (age, objectives, net worth)';
    }
  }

  static String _humanRegion(String code) {
    switch (code) {
      case PortfolioRegionMapper.unitedStates:
        return 'United States';
      case PortfolioRegionMapper.europe:
        return 'Europe';
      case PortfolioRegionMapper.asia:
        return 'Asia';
      case PortfolioRegionMapper.restOfWorld:
        return 'Rest of World';
      case PortfolioRegionMapper.liquidity:
        return 'Liquidity / Cash';
      case PortfolioRegionMapper.commodities:
        return 'Commodities';
      case PortfolioRegionMapper.unassigned:
        return 'Unassigned / Global';
      default:
        return code;
    }
  }
}
