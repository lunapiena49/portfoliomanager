import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../domain/utils/portfolio_region_mapper.dart';

const int _kMaxTreemapTiles = 16;
const double _kOtherBucketThreshold = 1.0;
const double _kMinTileSizePx = 24.0;

class PortfolioTreemapSection extends StatelessWidget {
  final Portfolio portfolio;

  const PortfolioTreemapSection({
    super.key,
    required this.portfolio,
  });

  @override
  Widget build(BuildContext context) {
    final positions = portfolio.positions
        .where((position) =>
            position.valueInBaseCurrency > 0 &&
            position.valueInBaseCurrency.isFinite)
        .toList();
    final totalValue = positions.fold<double>(
      0.0,
      (sum, position) => sum + position.valueInBaseCurrency,
    );
    final baseCurrency = portfolio.baseCurrency;
    final localeString = context.locale.toString();

    final positionNodes = _buildPositionNodes(
      context,
      positions,
      totalValue,
      baseCurrency,
      localeString,
    );
    final regionNodes = _buildRegionNodes(
      context,
      positions,
      totalValue,
      baseCurrency,
      localeString,
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
    String locale,
  ) {
    if (positions.isEmpty || totalValue <= 0) {
      return [];
    }

    final sorted = [...positions]
      ..sort((a, b) => b.valueInBaseCurrency.compareTo(a.valueInBaseCurrency));

    final visible = <Position>[];
    final bucket = <Position>[];

    for (var i = 0; i < sorted.length; i++) {
      final position = sorted[i];
      final percent = (position.valueInBaseCurrency / totalValue) * 100;
      final overflow = visible.length >= _kMaxTreemapTiles - 1;
      final tooSmall = percent < _kOtherBucketThreshold;
      if (overflow || (tooSmall && i > 0)) {
        bucket.add(position);
      } else {
        visible.add(position);
      }
    }

    final nodes = <TreemapNode>[];
    for (var i = 0; i < visible.length; i++) {
      final position = visible[i];
      final value = position.valueInBaseCurrency;
      final percent = (value / totalValue) * 100;
      nodes.add(
        TreemapNode(
          label: position.symbol,
          value: value,
          color: Color(_paletteColor(i)),
          tooltip: _buildTooltip(
            position.symbol,
            percent,
            value,
            baseCurrency,
            locale,
          ),
        ),
      );
    }

    if (bucket.isNotEmpty) {
      final bucketValue = bucket.fold<double>(
        0,
        (sum, p) => sum + p.valueInBaseCurrency,
      );
      final bucketPercent = (bucketValue / totalValue) * 100;
      final tooltipLabel = 'portfolio.charts.other_label'.tr(
        namedArgs: {'count': bucket.length.toString()},
      );
      nodes.add(
        TreemapNode(
          label: 'portfolio.charts.other'.tr(),
          value: bucketValue,
          color: Color(_paletteColor(visible.length)),
          tooltip: _buildTooltip(
            tooltipLabel,
            bucketPercent,
            bucketValue,
            baseCurrency,
            locale,
          ),
        ),
      );
    }

    return nodes;
  }

  List<TreemapNode> _buildRegionNodes(
    BuildContext context,
    List<Position> positions,
    double totalValue,
    String baseCurrency,
    String locale,
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

    return [
      for (final entry in entries)
        TreemapNode(
          label: _regionLabel(context, entry.key),
          value: entry.value,
          color: Color(PortfolioRegionMapper.colorForRegion(entry.key)),
          tooltip: _buildTooltip(
            _regionLabel(context, entry.key),
            (entry.value / totalValue) * 100,
            entry.value,
            baseCurrency,
            locale,
          ),
        ),
    ];
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
    String label,
    double percent,
    double value,
    String baseCurrency,
    String locale,
  ) {
    final percentLabel = CurrencyFormatter.formatPercent(percent);
    final valueLabel =
        CurrencyFormatter.format(value, baseCurrency, locale: locale);
    return '$label\n'
        '${'portfolio.charts.tooltip.allocation'.tr()}: $percentLabel\n'
        '${'portfolio.charts.tooltip.value'.tr()}: $valueLabel';
  }

  static int _paletteColor(int index) {
    final palette = AppConstants.chartColors;
    if (index < palette.length) {
      return palette[index];
    }
    final hue = (index * 137.508) % 360.0;
    final hsl = HSLColor.fromAHSL(1.0, hue, 0.55, 0.5);
    return hsl.toColor().toARGB32();
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final tiles = _squarify(nodes, Offset.zero & size);
        final gap = 4.w;

        final children = <Widget>[];
        for (final tile in tiles) {
          final gapRect = _applyGap(tile.rect, gap);
          if (gapRect.width <= 0 || gapRect.height <= 0) {
            continue;
          }
          final showLabel =
              gapRect.width >= _kMinTileSizePx && gapRect.height >= _kMinTileSizePx;
          children.add(
            Positioned(
              left: gapRect.left,
              top: gapRect.top,
              width: gapRect.width,
              height: gapRect.height,
              child: _TreemapTileWidget(
                node: tile.node,
                showLabel: showLabel,
              ),
            ),
          );
        }

        return Stack(children: children);
      },
    );
  }

  List<_TreemapTile> _squarify(List<TreemapNode> nodes, Rect rect) {
    if (nodes.isEmpty || rect.width <= 0 || rect.height <= 0) {
      return [];
    }

    final totalValue = nodes.fold<double>(0, (sum, node) => sum + node.value);
    if (totalValue <= 0) {
      return [];
    }
    final totalArea = rect.width * rect.height;
    if (totalArea <= 0) {
      return [];
    }
    final scale = totalArea / totalValue;

    final scaled = nodes
        .map((n) => _ScaledNode(node: n, area: n.value * scale))
        .toList();

    final tiles = <_TreemapTile>[];
    var available = rect;
    var remaining = scaled;

    while (remaining.isNotEmpty) {
      final shortSide = math.min(available.width, available.height);
      if (shortSide <= 0) break;

      final row = <_ScaledNode>[];
      var index = 0;
      while (index < remaining.length) {
        final candidate = remaining[index];
        final newRow = [...row, candidate];
        if (row.isEmpty ||
            _worst(newRow, shortSide) <= _worst(row, shortSide)) {
          row.add(candidate);
          index++;
        } else {
          break;
        }
      }

      if (row.isEmpty) {
        break;
      }

      final placed = _layoutRow(row, available);
      tiles.addAll(placed.tiles);
      available = placed.remaining;
      remaining = remaining.sublist(row.length);
    }

    return tiles;
  }

  double _worst(List<_ScaledNode> row, double w) {
    if (row.isEmpty) return double.infinity;
    final s = row.fold<double>(0, (sum, n) => sum + n.area);
    if (s <= 0) return double.infinity;
    var rmax = row.first.area;
    var rmin = row.first.area;
    for (final n in row) {
      if (n.area > rmax) rmax = n.area;
      if (n.area < rmin) rmin = n.area;
    }
    if (rmin <= 0) return double.infinity;
    final w2 = w * w;
    final s2 = s * s;
    return math.max((w2 * rmax) / s2, s2 / (w2 * rmin));
  }

  _RowLayout _layoutRow(List<_ScaledNode> row, Rect available) {
    final s = row.fold<double>(0, (sum, n) => sum + n.area);
    final isHorizontal = available.width >= available.height;
    final tiles = <_TreemapTile>[];

    if (isHorizontal) {
      final stripWidth = s / available.height;
      var y = available.top;
      for (final node in row) {
        final h = node.area / stripWidth;
        tiles.add(_TreemapTile(
          node: node.node,
          rect: Rect.fromLTWH(available.left, y, stripWidth, h),
        ));
        y += h;
      }
      final newLeft = available.left + stripWidth;
      final newWidth = math.max(0.0, available.width - stripWidth);
      return _RowLayout(
        tiles: tiles,
        remaining: Rect.fromLTWH(
          newLeft,
          available.top,
          newWidth,
          available.height,
        ),
      );
    }

    final stripHeight = s / available.width;
    var x = available.left;
    for (final node in row) {
      final w = node.area / stripHeight;
      tiles.add(_TreemapTile(
        node: node.node,
        rect: Rect.fromLTWH(x, available.top, w, stripHeight),
      ));
      x += w;
    }
    final newTop = available.top + stripHeight;
    final newHeight = math.max(0.0, available.height - stripHeight);
    return _RowLayout(
      tiles: tiles,
      remaining: Rect.fromLTWH(
        available.left,
        newTop,
        available.width,
        newHeight,
      ),
    );
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
  final bool showLabel;

  const _TreemapTileWidget({
    required this.node,
    required this.showLabel,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = _getForegroundColor(node.color);

    return Tooltip(
      message: node.tooltip,
      triggerMode: kIsWeb ? TooltipTriggerMode.longPress : TooltipTriggerMode.tap,
      waitDuration: Duration.zero,
      showDuration: const Duration(seconds: 4),
      preferBelow: false,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(6.r),
      ),
      textStyle: TextStyle(color: Colors.white, fontSize: 12.sp),
      child: Container(
        decoration: BoxDecoration(
          color: node.color,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: showLabel
            ? Center(
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
              )
            : null,
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

class _ScaledNode {
  final TreemapNode node;
  final double area;

  const _ScaledNode({
    required this.node,
    required this.area,
  });
}

class _RowLayout {
  final List<_TreemapTile> tiles;
  final Rect remaining;

  const _RowLayout({
    required this.tiles,
    required this.remaining,
  });
}
