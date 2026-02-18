import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../domain/utils/portfolio_region_mapper.dart';
import '../bloc/portfolio_bloc.dart';

class PositionDetailPage extends StatelessWidget {
  final String positionId;

  const PositionDetailPage({
    super.key,
    required this.positionId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PortfolioBloc, PortfolioState>(
      builder: (context, state) {
        if (state is! PortfolioLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final position = state.portfolio.positions.firstWhere(
          (p) => p.id == positionId,
          orElse: () => state.portfolio.positions.first,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(position.symbol),
            actions: [
              IconButton(
                tooltip: 'common.edit'.tr(),
                icon: const Icon(Icons.edit),
                onPressed: () => context.push(
                  '${RouteNames.home}/position/${position.id}/edit',
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context, position, state.portfolio.baseCurrency),
                SizedBox(height: 24.h),

                // Details
                _buildDetailsCard(context, position),
                SizedBox(height: 16.h),

                // P&L Card
                _buildPnLCard(context, position, state.portfolio.baseCurrency),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Position position, String baseCurrency) {
    final isProfit = position.unrealizedPnL >= 0;
    final pnlColor = isProfit ? AppTheme.profitColor : AppTheme.lossColor;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              position.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 6.h,
              children: [
                _buildTag(context, _getAssetTypeLabel(context, position.assetType)),
                if (_shouldShowSector(position.sector))
                  _buildTag(context, _getSectorLabel(context, position.sector)),
                _buildTag(context, position.currency),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              _formatCurrency(position.valueInBaseCurrency, baseCurrency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  isProfit ? Icons.trending_up : Icons.trending_down,
                  color: pnlColor,
                  size: 20.w,
                ),
                SizedBox(width: 4.w),
                Text(
                  '${isProfit ? '+' : ''}${position.pnlPercent.toStringAsFixed(2)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: pnlColor,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '(${_formatCurrency(position.unrealizedPnLInBaseCurrency, baseCurrency, showSign: true)})',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: pnlColor,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionRow(BuildContext context, Position position) {
    final resolvedCode = PortfolioRegionMapper.resolveRegionCode(position);
    final resolvedLabel = _getRegionLabel(context, resolvedCode);
    final isAuto = position.regionOverride == null;
    final displayValue = isAuto
        ? '${'portfolio.position.region_auto'.tr()} ($resolvedLabel)'
        : resolvedLabel;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'portfolio.position.region'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Flexible(
            child: Text(
              displayValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, Position position) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 16.h),
            _buildDetailRow(context, 'portfolio.position.quantity'.tr(), 
                position.quantity.toStringAsFixed(4)),
            _buildDetailRow(context, 'portfolio.position.price'.tr(),
                '${position.currency} ${position.closePrice.toStringAsFixed(2)}'),
            _buildDetailRow(context, 'portfolio.position.value'.tr(),
                '${position.currency} ${position.value.toStringAsFixed(2)}'),
            _buildDetailRow(context, 'portfolio.position.cost_basis'.tr(),
                '${position.currency} ${position.costBasis.toStringAsFixed(2)}'),
            if (position.fxRateToBase != 1.0)
              _buildDetailRow(context, 'FX Rate',
                  position.fxRateToBase.toStringAsFixed(4)),
            if (position.exchange != null)
              _buildDetailRow(context, 'Exchange', position.exchange!),
            _buildRegionRow(context, position),
          ],
        ),
      ),
    );
  }

  Widget _buildPnLCard(BuildContext context, Position position, String baseCurrency) {
    final isProfit = position.unrealizedPnL >= 0;
    final pnlColor = isProfit ? AppTheme.profitColor : AppTheme.lossColor;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'portfolio.position.pnl'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 16.h),
            _buildDetailRow(
              context,
              'Unrealized P&L (${position.currency})',
              '${isProfit ? '+' : ''}${position.unrealizedPnL.toStringAsFixed(2)}',
              valueColor: pnlColor,
            ),
            _buildDetailRow(
              context,
              'Unrealized P&L ($baseCurrency)',
              '${isProfit ? '+' : ''}${position.unrealizedPnLInBaseCurrency.toStringAsFixed(2)}',
              valueColor: pnlColor,
            ),
            _buildDetailRow(
              context,
              'P&L %',
              '${isProfit ? '+' : ''}${position.pnlPercent.toStringAsFixed(2)}%',
              valueColor: pnlColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
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
      default:
        return '$currency ';
    }
  }

  String _getRegionLabel(BuildContext context, String code) {
    switch (code) {
      case PortfolioRegionMapper.auto:
        return 'portfolio.position.region_auto'.tr();
      case PortfolioRegionMapper.unitedStates:
        return 'portfolio.charts.regions.us'.tr();
      case PortfolioRegionMapper.europe:
        return 'portfolio.charts.regions.europe'.tr();
      case PortfolioRegionMapper.asia:
        return 'portfolio.charts.regions.asia'.tr();
      case PortfolioRegionMapper.restOfWorld:
        return 'portfolio.charts.regions.rest_world'.tr();
      case PortfolioRegionMapper.liquidity:
        return 'portfolio.charts.regions.liquidity'.tr();
      case PortfolioRegionMapper.commodities:
        return 'portfolio.charts.regions.commodities'.tr();
      case PortfolioRegionMapper.unassigned:
      default:
        return 'portfolio.charts.regions.unassigned'.tr();
    }
  }
}
