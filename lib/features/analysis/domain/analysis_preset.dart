/// Identifies a discrete piece of portfolio data that can be included or
/// excluded from the prompt sent to the AI agent.
///
/// Slices are surfaced to the user in the "what the AI will see" transparency
/// panel. Each preset declares the slices it needs; the user can opt-out of
/// individual slices for privacy before sending.
enum AnalysisDataSlice {
  /// Account name, base currency, total value, total cost basis, total P&L.
  coreSummary,

  /// Top N positions by value (ticker, name, asset type, sector, qty, price,
  /// value, cost, P&L).
  holdings,

  /// Map sector -> value/percent.
  sectorAllocation,

  /// Map asset type -> value/percent.
  assetAllocation,

  /// Map region (US/Europe/Asia/...) -> value/percent.
  regionAllocation,

  /// Map currency -> value/percent + base currency exposure.
  currencyAllocation,

  /// HHI, effective N, top1/top5/top10 concentration.
  concentration,

  /// Cumulative return, 1m/3m return, best/worst, dividends, fees.
  /// Available only when [Portfolio.statistics] is populated by the import.
  statistics,

  /// Per-period returns from [Portfolio.historicalPerformance].
  performanceHistory,

  /// Investor profile (age, objectives, net worth) when available.
  /// Off by default to avoid sharing PII unless the user opts in.
  investorProfile,
}

/// Predefined analysis modes the user can pick. Each preset bundles:
///   - the set of data slices the AI will receive,
///   - a concrete instruction to drive the AI's response.
enum AnalysisPreset {
  /// Complete portfolio review (acts like the previous "Generate Full Analysis"
  /// button but with explicit slice declaration).
  fullReview,
  riskAssessment,
  diversification,
  performanceReview,
  recommendations,
  geographicExposure,
  concentrationCheck,
}

/// Definition of an [AnalysisPreset]: which slices it requires, which i18n
/// keys describe it, and the concrete instruction appended to the prompt.
class AnalysisPresetDefinition {
  final AnalysisPreset preset;
  final String id;
  final String titleKey;
  final String descriptionKey;
  final Set<AnalysisDataSlice> requiredSlices;
  final String instruction;

  const AnalysisPresetDefinition({
    required this.preset,
    required this.id,
    required this.titleKey,
    required this.descriptionKey,
    required this.requiredSlices,
    required this.instruction,
  });
}

class AnalysisPresets {
  AnalysisPresets._();

  static const Set<AnalysisDataSlice> _alwaysOn = {
    AnalysisDataSlice.coreSummary,
  };

  static const AnalysisPresetDefinition fullReview = AnalysisPresetDefinition(
    preset: AnalysisPreset.fullReview,
    id: 'full_review',
    titleKey: 'analysis.presets.full_review.title',
    descriptionKey: 'analysis.presets.full_review.description',
    requiredSlices: {
      AnalysisDataSlice.coreSummary,
      AnalysisDataSlice.holdings,
      AnalysisDataSlice.sectorAllocation,
      AnalysisDataSlice.assetAllocation,
      AnalysisDataSlice.regionAllocation,
      AnalysisDataSlice.currencyAllocation,
      AnalysisDataSlice.concentration,
      AnalysisDataSlice.statistics,
    },
    instruction:
        'Provide a comprehensive analysis covering: 1) portfolio summary and '
        'key metrics, 2) risk assessment (concentration, sector and currency '
        'exposure), 3) diversification, 4) performance review, '
        '5) actionable recommendations, 6) any red flags worth a closer look.',
  );

  static const AnalysisPresetDefinition riskAssessment =
      AnalysisPresetDefinition(
    preset: AnalysisPreset.riskAssessment,
    id: 'risk',
    titleKey: 'analysis.presets.risk.title',
    descriptionKey: 'analysis.presets.risk.description',
    requiredSlices: {
      AnalysisDataSlice.coreSummary,
      AnalysisDataSlice.holdings,
      AnalysisDataSlice.concentration,
      AnalysisDataSlice.sectorAllocation,
      AnalysisDataSlice.regionAllocation,
      AnalysisDataSlice.currencyAllocation,
    },
    instruction:
        'Assess the risk profile of this portfolio. Focus on concentration '
        '(HHI, effective number of positions, top holdings weight), sector '
        'and geographic exposure, currency risk relative to the base '
        'currency, and call out any single position whose weight is unusually '
        'large. Rank the most material risks first and explain each briefly.',
  );

  static const AnalysisPresetDefinition diversification =
      AnalysisPresetDefinition(
    preset: AnalysisPreset.diversification,
    id: 'diversification',
    titleKey: 'analysis.presets.diversification.title',
    descriptionKey: 'analysis.presets.diversification.description',
    requiredSlices: {
      AnalysisDataSlice.coreSummary,
      AnalysisDataSlice.holdings,
      AnalysisDataSlice.assetAllocation,
      AnalysisDataSlice.sectorAllocation,
      AnalysisDataSlice.regionAllocation,
      AnalysisDataSlice.concentration,
    },
    instruction:
        'Evaluate how well diversified the portfolio is across asset class, '
        'sector and geography. Flag clusters and gaps; suggest concrete '
        'rebalancing buckets if the diversification is weak.',
  );

  static const AnalysisPresetDefinition performanceReview =
      AnalysisPresetDefinition(
    preset: AnalysisPreset.performanceReview,
    id: 'performance',
    titleKey: 'analysis.presets.performance.title',
    descriptionKey: 'analysis.presets.performance.description',
    requiredSlices: {
      AnalysisDataSlice.coreSummary,
      AnalysisDataSlice.holdings,
      AnalysisDataSlice.statistics,
      AnalysisDataSlice.performanceHistory,
    },
    instruction:
        'Review the portfolio performance. Identify the largest contributors '
        'to gain/loss, comment on cumulative and recent returns, dividends, '
        'and fees. Be specific with figures from the data provided; do not '
        'invent numbers that are not in the input.',
  );

  static const AnalysisPresetDefinition recommendations =
      AnalysisPresetDefinition(
    preset: AnalysisPreset.recommendations,
    id: 'recommendations',
    titleKey: 'analysis.presets.recommendations.title',
    descriptionKey: 'analysis.presets.recommendations.description',
    requiredSlices: {
      AnalysisDataSlice.coreSummary,
      AnalysisDataSlice.holdings,
      AnalysisDataSlice.sectorAllocation,
      AnalysisDataSlice.assetAllocation,
      AnalysisDataSlice.regionAllocation,
      AnalysisDataSlice.concentration,
    },
    instruction:
        'Provide 3 to 5 actionable, prioritized recommendations. For each '
        'recommendation: state the issue, the proposed change (with '
        'approximate weights or buckets), and the expected effect. Keep '
        'recommendations grounded in the data shown above.',
  );

  static const AnalysisPresetDefinition geographicExposure =
      AnalysisPresetDefinition(
    preset: AnalysisPreset.geographicExposure,
    id: 'geographic',
    titleKey: 'analysis.presets.geographic.title',
    descriptionKey: 'analysis.presets.geographic.description',
    requiredSlices: {
      AnalysisDataSlice.coreSummary,
      AnalysisDataSlice.holdings,
      AnalysisDataSlice.regionAllocation,
      AnalysisDataSlice.currencyAllocation,
    },
    instruction:
        'Analyze the geographic and currency exposure. Comment on home bias '
        'against the base currency, exposure to emerging vs developed markets, '
        'and any region that looks under or over represented for a balanced '
        'global portfolio.',
  );

  static const AnalysisPresetDefinition concentrationCheck =
      AnalysisPresetDefinition(
    preset: AnalysisPreset.concentrationCheck,
    id: 'concentration',
    titleKey: 'analysis.presets.concentration.title',
    descriptionKey: 'analysis.presets.concentration.description',
    requiredSlices: {
      AnalysisDataSlice.coreSummary,
      AnalysisDataSlice.holdings,
      AnalysisDataSlice.concentration,
      AnalysisDataSlice.sectorAllocation,
    },
    instruction:
        'Focus exclusively on concentration. Interpret the HHI value, the '
        'effective number of positions, and the cumulative top1/top5/top10 '
        'weights. Tell the user whether the portfolio is concentrated, '
        'moderately diversified or well diversified, and which single '
        'positions or sectors drive the concentration.',
  );

  static const List<AnalysisPresetDefinition> all = [
    fullReview,
    riskAssessment,
    diversification,
    performanceReview,
    recommendations,
    geographicExposure,
    concentrationCheck,
  ];

  static AnalysisPresetDefinition byPreset(AnalysisPreset preset) {
    switch (preset) {
      case AnalysisPreset.fullReview:
        return fullReview;
      case AnalysisPreset.riskAssessment:
        return riskAssessment;
      case AnalysisPreset.diversification:
        return diversification;
      case AnalysisPreset.performanceReview:
        return performanceReview;
      case AnalysisPreset.recommendations:
        return recommendations;
      case AnalysisPreset.geographicExposure:
        return geographicExposure;
      case AnalysisPreset.concentrationCheck:
        return concentrationCheck;
    }
  }

  static Set<AnalysisDataSlice> alwaysOnSlices() => Set.of(_alwaysOn);

  static String dataSliceI18nKey(AnalysisDataSlice slice) {
    switch (slice) {
      case AnalysisDataSlice.coreSummary:
        return 'analysis.data_slices.core_summary';
      case AnalysisDataSlice.holdings:
        return 'analysis.data_slices.holdings';
      case AnalysisDataSlice.sectorAllocation:
        return 'analysis.data_slices.sector_allocation';
      case AnalysisDataSlice.assetAllocation:
        return 'analysis.data_slices.asset_allocation';
      case AnalysisDataSlice.regionAllocation:
        return 'analysis.data_slices.region_allocation';
      case AnalysisDataSlice.currencyAllocation:
        return 'analysis.data_slices.currency_allocation';
      case AnalysisDataSlice.concentration:
        return 'analysis.data_slices.concentration';
      case AnalysisDataSlice.statistics:
        return 'analysis.data_slices.statistics';
      case AnalysisDataSlice.performanceHistory:
        return 'analysis.data_slices.performance_history';
      case AnalysisDataSlice.investorProfile:
        return 'analysis.data_slices.investor_profile';
    }
  }
}
