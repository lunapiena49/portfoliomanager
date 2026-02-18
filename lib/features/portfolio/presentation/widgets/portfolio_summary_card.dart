import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';

class PortfolioSummaryCard extends StatelessWidget {
  final Portfolio portfolio;

  const PortfolioSummaryCard({
    super.key,
    required this.portfolio,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = portfolio.totalUnrealizedPnL >= 0;
    final pnlColor = isProfit ? AppTheme.profitColor : AppTheme.lossColor;
    final pnlIcon = isProfit ? Icons.trending_up : Icons.trending_down;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account name
            Text(
              portfolio.accountName.isNotEmpty
                  ? portfolio.accountName
                  : portfolio.accountId,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 20.h),

            // Total Value
            Text(
              'portfolio.total_value'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 4.h),
            Text(
              _formatCurrency(portfolio.totalValue, portfolio.baseCurrency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                    value: _formatCurrency(
                      portfolio.totalUnrealizedPnL,
                      portfolio.baseCurrency,
                      showSign: true,
                    ),
                    valueColor: pnlColor,
                    icon: pnlIcon,
                    iconColor: pnlColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 40.h,
                  color: Theme.of(context).dividerColor,
                ),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'portfolio.position.pnl_percent'.tr(),
                    value: '${isProfit ? '+' : ''}${portfolio.totalPnLPercent.toStringAsFixed(2)}%',
                    valueColor: pnlColor,
                  ),
                ),
              ],
            ),

            // Statistics if available
            if (portfolio.statistics != null) ...[
              SizedBox(height: 16.h),
              Divider(height: 1, color: Theme.of(context).dividerColor),
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
        return '£';
      case 'CHF':
        return 'CHF ';
      case 'JPY':
        return '¥';
      default:
        return '$currency ';
    }
  }
}
