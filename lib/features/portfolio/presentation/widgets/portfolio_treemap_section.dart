import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../domain/utils/portfolio_region_mapper.dart';

class PortfolioTreemapSection extends StatelessWidget {
  final Portfolio portfolio;

  const PortfolioTreemapSection({
    super.key,
    required this.portfolio,
  });

  @override
  Widget build(BuildContext context) {
    final positions = portfolio.positions
        .where((position) => position.valueInBaseCurrency > 0)
        .toList();
    final totalValue = positions.fold<double>(
      0.0,
      (sum, position) => sum + position.valueInBaseCurrency,
    );
    final baseCurrency = portfolio.baseCurrency;

    final positionNodes = _buildPositionNodes(
      context,
      positions,
      totalValue,
      baseCurrency,
    );
    final regionNodes = _buildRegionNodes(
      context,
      positions,
      totalValue,
      baseCurrency,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'portfolio.charts.title'.tr(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SizedBox(height: 12.h),
        TreemapChartCard(
          title: 'portfolio.charts.positions_title'.tr(),
          subtitle: 'portfolio.charts.positions_subtitle'.tr(),
          nodes: positionNodes,
          emptyLabel: 'portfolio.charts.empty'.tr(),
        ),
        SizedBox(height: 16.h),
        TreemapChartCard(
          title: 'portfolio.charts.regions_title'.tr(),
          subtitle: 'portfolio.charts.regions_subtitle'.tr(),
          nodes: regionNodes,
          emptyLabel: 'portfolio.charts.empty'.tr(),
        ),
      ],
    );
  }

  List<TreemapNode> _buildPositionNodes(
    BuildContext context,
    List<Position> positions,
    double totalValue,
    String baseCurrency,
  ) {
    if (positions.isEmpty || totalValue <= 0) {
      return [];
    }

    final sorted = [...positions]
      ..sort((a, b) => b.valueInBaseCurrency.compareTo(a.valueInBaseCurrency));

    return List.generate(sorted.length, (index) {
      final position = sorted[index];
      final value = position.valueInBaseCurrency;
      final percent = totalValue == 0 ? 0.0 : (value / totalValue * 100).toDouble();
      final color = Color(
        AppConstants.chartColors[index % AppConstants.chartColors.length],
      );
      final tooltip = _buildTooltip(
        context,
        position.symbol,
        percent,
        value,
        baseCurrency,
      );

      return TreemapNode(
        label: position.symbol,
        value: value,
        color: color,
        tooltip: tooltip,
      );
    });
  }

  List<TreemapNode> _buildRegionNodes(
    BuildContext context,
    List<Position> positions,
    double totalValue,
    String baseCurrency,
  ) {
    if (positions.isEmpty || totalValue <= 0) {
      return [];
    }

    final allocations = <String, double>{};

    for (final position in positions) {
      final regionCode = PortfolioRegionMapper.resolveRegionCode(position);
      allocations[regionCode] =
          (allocations[regionCode] ?? 0) + position.valueInBaseCurrency;
    }

    final entries = allocations.entries
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return List.generate(entries.length, (index) {
      final entry = entries[index];
      final label = _regionLabel(context, entry.key);
      final value = entry.value;
      final percent = totalValue == 0 ? 0.0 : (value / totalValue * 100).toDouble();
      final color = Color(
        AppConstants.chartColors[index % AppConstants.chartColors.length],
      );
      final tooltip = _buildTooltip(
        context,
        label,
        percent,
        value,
        baseCurrency,
      );

      return TreemapNode(
        label: label,
        value: value,
        color: color,
        tooltip: tooltip,
      );
    });
  }

  String _regionLabel(BuildContext context, String regionCode) {
    switch (regionCode) {
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
        return 'portfolio.charts.regions.unassigned'.tr();
      default:
        return 'portfolio.charts.regions.unassigned'.tr();
    }
  }

  String _buildTooltip(
    BuildContext context,
    String label,
    double percent,
    double value,
    String baseCurrency,
  ) {
    return '${label}\n'
        '${'portfolio.charts.tooltip.allocation'.tr()}: ${percent.toStringAsFixed(1)}%\n'
        '${'portfolio.charts.tooltip.value'.tr()}: ${_formatCurrency(value, baseCurrency)}';
  }

  String _formatCurrency(double value, String currency) {
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: 2,
    );
    return formatter.format(value);
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return 'EUR ';
      case 'USD':
        return r'$';
      case 'GBP':
        return 'GBP ';
      case 'CHF':
        return 'CHF ';
      case 'JPY':
        return 'JPY ';
      case 'CAD':
        return 'CAD ';
      case 'AUD':
        return 'AUD ';
      default:
        return '${currency.toUpperCase()} ';
    }
  }
}

class TreemapChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<TreemapNode> nodes;
  final String emptyLabel;

  const TreemapChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.nodes,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 4.h),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 240.h,
              child: nodes.isEmpty
                  ? _buildEmptyState(context)
                  : TreemapChart(nodes: nodes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final iconSize = math.min(42.r, constraints.maxHeight * 0.35);
        final spacing = math.min(8.h, constraints.maxHeight * 0.08);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.dashboard_customize,
                size: iconSize,
                color: Theme.of(context).disabledColor,
              ),
              SizedBox(height: spacing),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.9),
                child: Text(
                  emptyLabel,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TreemapChart extends StatelessWidget {
  final List<TreemapNode> nodes;

  const TreemapChart({
    super.key,
    required this.nodes,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...nodes]
      ..sort((a, b) => b.value.compareTo(a.value));

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final rect = Offset.zero & size;
        final tiles = _layoutTiles(sorted, rect, true);
        final gap = 4.w;

        return Stack(
          children: tiles
              .map((tile) {
                final gapRect = _applyGap(tile.rect, gap);
                if (gapRect.width <= 0 || gapRect.height <= 0) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: gapRect.left,
                  top: gapRect.top,
                  width: gapRect.width,
                  height: gapRect.height,
                  child: _TreemapTileWidget(
                    node: tile.node,
                  ),
                );
              })
              .whereType<Widget>()
              .toList(),
        );
      },
    );
  }

  List<_TreemapTile> _layoutTiles(
    List<TreemapNode> nodes,
    Rect rect,
    bool vertical,
  ) {
    if (nodes.isEmpty || rect.width <= 0 || rect.height <= 0) {
      return [];
    }

    if (nodes.length == 1) {
      return [_TreemapTile(node: nodes.first, rect: rect)];
    }

    final total = nodes.fold<double>(0, (sum, node) => sum + node.value);
    if (total == 0) {
      return [];
    }

    final first = nodes.first;
    final ratio = (first.value / total).clamp(0.0, 1.0);

    if (vertical) {
      final width = rect.width * ratio;
      final firstRect = Rect.fromLTWH(rect.left, rect.top, width, rect.height);
      final remainingRect = Rect.fromLTWH(
        rect.left + width,
        rect.top,
        rect.width - width,
        rect.height,
      );
      return [
        _TreemapTile(node: first, rect: firstRect),
        ..._layoutTiles(nodes.sublist(1), remainingRect, !vertical),
      ];
    }

    final height = rect.height * ratio;
    final firstRect = Rect.fromLTWH(rect.left, rect.top, rect.width, height);
    final remainingRect = Rect.fromLTWH(
      rect.left,
      rect.top + height,
      rect.width,
      rect.height - height,
    );

    return [
      _TreemapTile(node: first, rect: firstRect),
      ..._layoutTiles(nodes.sublist(1), remainingRect, !vertical),
    ];
  }

  Rect _applyGap(Rect rect, double gap) {
    final half = gap / 2;
    final width = math.max(0.0, rect.width - gap);
    final height = math.max(0.0, rect.height - gap);
    return Rect.fromLTWH(rect.left + half, rect.top + half, width, height);
  }
}

class _TreemapTileWidget extends StatelessWidget {
  final TreemapNode node;

  const _TreemapTileWidget({
    required this.node,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _getForegroundColor(node.color);

    return Tooltip(
      message: node.tooltip,
      triggerMode: kIsWeb ? TooltipTriggerMode.longPress : TooltipTriggerMode.tap,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 2),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6.r),
      ),
      textStyle: TextStyle(color: Colors.white, fontSize: 12.sp),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            color: node.color,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  node.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getForegroundColor(Color background) {
    return background.computeLuminance() > 0.6
        ? Colors.black87
        : Colors.white;
  }
}

class TreemapNode {
  final String label;
  final double value;
  final Color color;
  final String tooltip;

  const TreemapNode({
    required this.label,
    required this.value,
    required this.color,
    required this.tooltip,
  });
}

class _TreemapTile {
  final TreemapNode node;
  final Rect rect;

  const _TreemapTile({
    required this.node,
    required this.rect,
  });
}

