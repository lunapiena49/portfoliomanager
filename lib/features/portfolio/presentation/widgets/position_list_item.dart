import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';

class PositionListItem extends StatelessWidget {
  final Position position;
  final String baseCurrency;
  final VoidCallback? onTap;

  const PositionListItem({
    super.key,
    required this.position,
    required this.baseCurrency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isProfit = position.unrealizedPnL >= 0;
    final pnlColor = isProfit ? AppTheme.profitColor : AppTheme.lossColor;
    final assetTypeLabel = _getAssetTypeLabel(context, position.assetType);
    final sectorLabel = _getSectorLabel(context, position.sector);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              // Symbol badge
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: _getAssetTypeColor(position.assetType).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    _getSymbolAbbrev(position.symbol),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: _getAssetTypeColor(position.assetType),
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),

              // Name and details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      position.symbol,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      position.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      children: [
                        _buildTag(
                          context,
                          assetTypeLabel,
                          _getAssetTypeColor(position.assetType),
                        ),
                        if (_shouldShowSector(position.sector))
                          _buildTag(
                            context,
                            _abbreviateSector(sectorLabel),
                            AppTheme.neutralColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Value and P&L
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(position.valueInBaseCurrency, baseCurrency),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isProfit ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        color: pnlColor,
                        size: 20.w,
                      ),
                      Text(
                        '${position.pnlPercent >= 0 ? '+' : ''}${position.pnlPercent.toStringAsFixed(2)}%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: pnlColor,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    _formatCurrency(position.unrealizedPnLInBaseCurrency, baseCurrency, showSign: true),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: pnlColor,
                        ),
                  ),
                ],
              ),

              // Chevron
              SizedBox(width: 8.w),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontSize: 10.sp,
            ),
      ),
    );
  }

  String _getSymbolAbbrev(String symbol) {
    if (symbol.length <= 4) return symbol;
    return symbol.substring(0, 4);
  }

  String _abbreviateSector(String sector) {
    if (sector.length <= 8) return sector;
    return '${sector.substring(0, 6)}...';
  }

  bool _shouldShowSector(String sector) {
    final normalized = sector.trim().toLowerCase();
    return normalized.isNotEmpty && normalized != 'other';
  }

  String _getAssetTypeLabel(BuildContext context, String assetType) {
    switch (assetType.trim().toLowerCase()) {
      case 'stocks':
        return 'portfolio.asset_types.stocks'.tr();
      case 'etfs':
        return 'portfolio.asset_types.etfs'.tr();
      case 'bonds':
        return 'portfolio.asset_types.bonds'.tr();
      case 'crypto':
        return 'portfolio.asset_types.crypto'.tr();
      case 'funds':
        return 'portfolio.asset_types.funds'.tr();
      case 'options':
        return 'portfolio.asset_types.options'.tr();
      case 'futures':
        return 'portfolio.asset_types.futures'.tr();
      case 'cash':
        return 'portfolio.asset_types.cash'.tr();
      case 'cfds':
        return 'portfolio.asset_types.cfds'.tr();
      case 'commodities':
        return 'portfolio.asset_types.commodities'.tr();
      case 'real estate':
        return 'portfolio.asset_types.real_estate'.tr();
      case 'other':
        return 'portfolio.asset_types.other'.tr();
      default:
        return assetType;
    }
  }

  String _getSectorLabel(BuildContext context, String sector) {
    final normalized = sector.trim();
    if (normalized.isEmpty) return '';
    switch (normalized.toLowerCase()) {
      case 'technology':
        return 'portfolio.sectors.technology'.tr();
      case 'financials':
        return 'portfolio.sectors.financials'.tr();
      case 'healthcare':
        return 'portfolio.sectors.healthcare'.tr();
      case 'consumer cyclicals':
        return 'portfolio.sectors.consumer_cyclicals'.tr();
      case 'consumer non-cyclicals':
        return 'portfolio.sectors.consumer_non_cyclicals'.tr();
      case 'industrials':
        return 'portfolio.sectors.industrials'.tr();
      case 'basic materials':
        return 'portfolio.sectors.basic_materials'.tr();
      case 'energy':
        return 'portfolio.sectors.energy'.tr();
      case 'utilities':
        return 'portfolio.sectors.utilities'.tr();
      case 'real estate':
        return 'portfolio.sectors.real_estate'.tr();
      case 'communications':
        return 'portfolio.sectors.communications'.tr();
      case 'broad':
        return 'portfolio.sectors.broad'.tr();
      case 'other':
        return 'portfolio.sectors.other'.tr();
      default:
        return sector;
    }
  }

  Color _getAssetTypeColor(String assetType) {
    switch (assetType.toLowerCase()) {
      case 'stocks':
        return AppTheme.primaryColor;
      case 'etfs':
        return AppTheme.accentColor;
      case 'crypto':
        return AppTheme.warningColor;
      case 'bonds':
        return AppTheme.successColor;
      case 'options':
        return Colors.purple;
      case 'futures':
        return Colors.orange;
      default:
        return AppTheme.neutralColor;
    }
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
