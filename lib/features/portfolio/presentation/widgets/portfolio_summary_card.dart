import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';

class PortfolioSummaryCard extends StatefulWidget {
  final Portfolio portfolio;

  const PortfolioSummaryCard({
    super.key,
    required this.portfolio,
  });

  @override
  State<PortfolioSummaryCard> createState() => _PortfolioSummaryCardState();
}

class _PortfolioSummaryCardState extends State<PortfolioSummaryCard> {
  static const String _hiddenPlaceholder =
      '\u2022\u2022\u2022\u2022\u2022\u2022';
  bool _isHidden = false;

  @override
  Widget build(BuildContext context) {
    final portfolio = widget.portfolio;
    final isProfit = portfolio.totalUnrealizedPnL >= 0;
    final pnlColor = isProfit ? AppTheme.profitColor : AppTheme.lossColor;
    final pnlIcon = isProfit ? Icons.trending_up : Icons.trending_down;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: account name + action buttons (privacy + detail)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    portfolio.accountName.isNotEmpty
                        ? portfolio.accountName
                        : portfolio.accountId,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildActionButton(
                  context,
                  icon: _isHidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  tooltip: _isHidden
                      ? 'portfolio.privacy.show'.tr()
                      : 'portfolio.privacy.hide'.tr(),
                  onTap: () => setState(() => _isHidden = !_isHidden),
                ),
                SizedBox(width: 8.w),
                _buildActionButton(
                  context,
                  icon: Icons.analytics_outlined,
                  tooltip: 'portfolio.detail.tooltip'.tr(),
                  onTap: () => context.push(RouteNames.analysis),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // Total Value
            Text(
              'portfolio.total_value'.tr(),
              style: theme.textTheme.bodySmall,
            ),
            SizedBox(height: 4.h),
            Text(
              _isHidden
                  ? _hiddenPlaceholder
                  : _formatCurrency(
                      portfolio.totalValue,
                      portfolio.baseCurrency,
                    ),
              style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 16.h),

            // P&L Row
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'portfolio.total_pnl'.tr(),
                    value: _isHidden
                        ? _hiddenPlaceholder
                        : _formatCurrency(
                            portfolio.totalUnrealizedPnL,
                            portfolio.baseCurrency,
                            showSign: true,
                          ),
                    valueColor: _isHidden ? null : pnlColor,
                    icon: _isHidden ? null : pnlIcon,
                    iconColor: _isHidden ? null : pnlColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40.h,
                  color: theme.dividerColor,
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'portfolio.position.pnl_percent'.tr(),
                    value: _isHidden
                        ? _hiddenPlaceholder
                        : '${isProfit ? '+' : ''}${portfolio.totalPnLPercent.toStringAsFixed(2)}%',
                    valueColor: _isHidden ? null : pnlColor,
                  ),
                ),
              ],
            ),

            // Statistics if available
            if (portfolio.statistics != null) ...[
              SizedBox(height: 16.h),
              Divider(height: 1, color: theme.dividerColor),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      context,
                      label: '1M',
                      value: portfolio.statistics!.oneMonthReturn,
                    ),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                      context,
                      label: '3M',
                      value: portfolio.statistics!.threeMonthReturn,
                    ),
                  ),
                  Expanded(
                    child: _buildMiniStat(
                      context,
                      label: 'YTD',
                      value: portfolio.statistics!.cumulativeReturn,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Compact circular IconButton kept symmetric for visual balance.
  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 18.w,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
    IconData? icon,
    Color? iconColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16.w, color: iconColor),
                SizedBox(width: 4.w),
              ],
              Flexible(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: valueColor,
                        fontWeight: FontWeight.w600,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String label,
    required double value,
  }) {
    if (_isHidden) {
      return Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          SizedBox(height: 4.h),
          Text(
            _hiddenPlaceholder,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      );
    }

    final isPositive = value >= 0;
    final color = isPositive ? AppTheme.profitColor : AppTheme.lossColor;

    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        SizedBox(height: 4.h),
        Text(
          '${isPositive ? '+' : ''}${value.toStringAsFixed(2)}%',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  String _formatCurrency(double value, String currency, {bool showSign = false}) {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );

    if (showSign && value > 0) {
      return '+${formatter.format(value)}';
    }
    return formatter.format(value);
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return 'EUR ';
      case 'USD':
        return '\$';
      case 'GBP':
        return '\u00A3';
      case 'CHF':
        return 'CHF ';
      case 'JPY':
        return '\u00A5';
      default:
        return '$currency ';
    }
  }
}
