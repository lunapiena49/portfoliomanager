import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../portfolio/domain/portfolio_metrics.dart';

/// Read-only dashboard of derived portfolio metrics shown in the analysis
/// page. Same numbers the AI receives (concentration block) so the user can
/// reconcile what the agent will reason about.
class PortfolioMetricsCard extends StatelessWidget {
  final PortfolioMetricsSnapshot metrics;
  final String baseCurrency;

  const PortfolioMetricsCard({
    super.key,
    required this.metrics,
    required this.baseCurrency,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: theme.primaryColor),
                SizedBox(width: 8.w),
                Text(
                  'analysis.metrics.title'.tr(),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'analysis.metrics.subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            SizedBox(height: 12.h),
            _row(theme, 'analysis.metrics.position_count'.tr(),
                metrics.positionCount.toString()),
            _row(
              theme,
              'analysis.metrics.profitable'.tr(),
              '${metrics.profitablePositions} / ${metrics.positionCount}',
            ),
            _row(
              theme,
              'analysis.metrics.top_1'.tr(),
              '${metrics.top1ConcentrationPercent.toStringAsFixed(1)}%',
            ),
            _row(
              theme,
              'analysis.metrics.top_5'.tr(),
              '${metrics.top5ConcentrationPercent.toStringAsFixed(1)}%',
            ),
            _row(
              theme,
              'analysis.metrics.top_10'.tr(),
              '${metrics.top10ConcentrationPercent.toStringAsFixed(1)}%',
            ),
            _row(
              theme,
              'analysis.metrics.hhi'.tr(),
              '${metrics.herfindahlIndex.toStringAsFixed(0)} (${_hhiLabel().tr()})',
            ),
            _row(
              theme,
              'analysis.metrics.effective_n'.tr(),
              metrics.effectiveNumberOfPositions.toStringAsFixed(1),
            ),
            _row(
              theme,
              'analysis.metrics.base_currency_exposure'.tr(
                namedArgs: {'currency': baseCurrency},
              ),
              '${metrics.baseCurrencyExposurePercent.toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  String _hhiLabel() {
    final hhi = metrics.herfindahlIndex;
    if (hhi < 1500) return 'analysis.metrics.hhi_diversified';
    if (hhi < 2500) return 'analysis.metrics.hhi_moderate';
    return 'analysis.metrics.hhi_concentrated';
  }

  Widget _row(ThemeData theme, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
