import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';

/// Pie chart widget for displaying portfolio allocation
class AllocationPieChart extends StatefulWidget {
  final Map<String, double> allocation;
  final String title;
  final String baseCurrency;

  const AllocationPieChart({
    super.key,
    required this.allocation,
    required this.title,
    required this.baseCurrency,
  });

  @override
  State<AllocationPieChart> createState() => _AllocationPieChartState();
}

class _AllocationPieChartState extends State<AllocationPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = widget.allocation.values.fold(0.0, (sum, val) => sum + val);
    
    if (widget.allocation.isEmpty || total == 0) {
      return _buildEmptyState(context);
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40.r,
                        sections: _buildSections(total, isDark),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    flex: 2,
                    child: _buildLegend(context, total),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildSections(double total, bool isDark) {
    final entries = widget.allocation.entries.toList();
    return List.generate(entries.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 16.sp : 12.sp;
      final radius = isTouched ? 60.r : 50.r;
      final entry = entries[i];
      final percent = (entry.value / total * 100);
      
      return PieChartSectionData(
        color: Color(AppConstants.chartColors[i % AppConstants.chartColors.length]),
        value: entry.value,
        title: '${percent.toStringAsFixed(1)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [
            Shadow(
              color: Colors.black26,
              blurRadius: 2,
            ),
          ],
        ),
      );
    });
  }

  Widget _buildLegend(BuildContext context, double total) {
    final entries = widget.allocation.entries.toList();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: List.generate(entries.length, (i) {
          final entry = entries[i];
          final percent = (entry.value / total * 100).toStringAsFixed(1);
          final isTouched = i == touchedIndex;
          
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Row(
              children: [
                Container(
                  width: 12.w,
                  height: 12.w,
                  decoration: BoxDecoration(
                    color: Color(AppConstants.chartColors[i % AppConstants.chartColors.length]),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pie_chart_outline,
                size: 48.w,
                color: Theme.of(context).disabledColor,
              ),
              SizedBox(height: 8.h),
              Text(
                'No data available',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bar chart widget for performance comparison
class PerformanceBarChart extends StatelessWidget {
  final List<PerformanceRecord> records;
  final String title;

  const PerformanceBarChart({
    super.key,
    required this.records,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (records.isEmpty) {
      return _buildEmptyState(context);
    }

    // Filter to last 12 monthly records
    final monthlyRecords = records
        .where((r) => r.periodType == 'month' && r.accountReturn != null)
        .toList();
    
    final displayRecords = monthlyRecords.length > 12 
        ? monthlyRecords.sublist(monthlyRecords.length - 12) 
        : monthlyRecords;

    if (displayRecords.isEmpty) {
      return _buildEmptyState(context);
    }

    final maxY = displayRecords
        .map((r) => r.accountReturn?.abs() ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final yMax = (maxY * 1.2).ceilToDouble();

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
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: yMax,
                  minY: -yMax,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (group) => isDark 
                          ? AppTheme.darkCardColor 
                          : AppTheme.lightCardColor,
                      tooltipPadding: EdgeInsets.all(8.w),
                      tooltipMargin: 8.h,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final record = displayRecords[groupIndex];
                        return BarTooltipItem(
                          '${record.period}\n${record.accountReturn?.toStringAsFixed(2) ?? 0}%',
                          TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= displayRecords.length) {
                            return const SizedBox.shrink();
                          }
                          final period = displayRecords[index].period;
                          // Extract month abbreviation
                          final monthStr = period.length >= 6 
                              ? period.substring(4, 6) 
                              : period;
                          return Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: Text(
                              _getMonthAbbr(monthStr),
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28.h,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          );
                        },
                        reservedSize: 40.w,
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yMax / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _buildBarGroups(displayRecords),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(List<PerformanceRecord> records) {
    return List.generate(records.length, (i) {
      final returnValue = records[i].accountReturn ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: returnValue,
            color: returnValue >= 0 ? AppTheme.profitColor : AppTheme.lossColor,
            width: 16.w,
            borderRadius: BorderRadius.vertical(
              top: returnValue >= 0 ? Radius.circular(4.r) : Radius.zero,
              bottom: returnValue < 0 ? Radius.circular(4.r) : Radius.zero,
            ),
          ),
        ],
      );
    });
  }

  String _getMonthAbbr(String month) {
    final months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    final monthNum = int.tryParse(month);
    if (monthNum != null && monthNum >= 1 && monthNum <= 12) {
      return months[monthNum - 1];
    }
    return month;
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bar_chart,
                size: 48.w,
                color: Theme.of(context).disabledColor,
              ),
              SizedBox(height: 8.h),
              Text(
                'No performance data',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Line chart widget for portfolio value over time
class PortfolioLineChart extends StatelessWidget {
  final List<PerformanceRecord> records;
  final String title;
  final double startingNav;

  const PortfolioLineChart({
    super.key,
    required this.records,
    required this.title,
    required this.startingNav,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (records.isEmpty || startingNav == 0) {
      return _buildEmptyState(context);
    }

    // Calculate cumulative NAV from returns
    final monthlyRecords = records
        .where((r) => r.periodType == 'month' && r.accountReturn != null)
        .toList();

    if (monthlyRecords.isEmpty) {
      return _buildEmptyState(context);
    }

    final spots = _calculateNavSpots(monthlyRecords);
    if (spots.isEmpty) {
      return _buildEmptyState(context);
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yRange = maxY - minY;
    final yPadding = yRange * 0.1;

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
            SizedBox(height: 16.h),
            SizedBox(
              height: 200.h,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yRange / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDark ? AppTheme.darkDivider : AppTheme.lightDivider,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28.h,
                        interval: (monthlyRecords.length / 6).ceilToDouble(),
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= monthlyRecords.length) {
                            return const SizedBox.shrink();
                          }
                          final period = monthlyRecords[index].period;
                          return Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: Text(
                              _formatPeriod(period),
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50.w,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatCompactNumber(value),
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (spots.length - 1).toDouble(),
                  minY: minY - yPadding,
                  maxY: maxY + yPadding,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (touchedSpot) => isDark 
                          ? AppTheme.darkCardColor 
                          : AppTheme.lightCardColor,
                      tooltipPadding: EdgeInsets.all(8.w),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.spotIndex;
                          final period = index < monthlyRecords.length 
                              ? monthlyRecords[index].period 
                              : '';
                          return LineTooltipItem(
                            '$period\n${_formatCompactNumber(spot.y)}',
                            TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AppTheme.primaryColor,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.3),
                            AppTheme.primaryColor.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _calculateNavSpots(List<PerformanceRecord> records) {
    final spots = <FlSpot>[];
    double currentNav = startingNav;
    
    for (var i = 0; i < records.length; i++) {
      final returnPct = records[i].accountReturn ?? 0;
      currentNav = currentNav * (1 + returnPct / 100);
      spots.add(FlSpot(i.toDouble(), currentNav));
    }
    
    return spots;
  }

  String _formatPeriod(String period) {
    // Period format: YYYYMM
    if (period.length >= 6) {
      final month = period.substring(4, 6);
      final year = period.substring(2, 4);
      return '$month/$year';
    }
    return period;
  }

  String _formatCompactNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }

  Widget _buildEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.show_chart,
                size: 48.w,
                color: Theme.of(context).disabledColor,
              ),
              SizedBox(height: 8.h),
              Text(
                'No historical data',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Top performers widget showing best/worst positions
class TopPerformersWidget extends StatelessWidget {
  final List<Position> gainers;
  final List<Position> losers;
  final String baseCurrency;

  const TopPerformersWidget({
    super.key,
    required this.gainers,
    required this.losers,
    required this.baseCurrency,
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
              'Top Performers',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: AppTheme.profitColor,
                            size: 18.w,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'market.top_gainers'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                              color: AppTheme.profitColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      if (gainers.isEmpty)
                        Text(
                          'No gainers',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        ...gainers.take(5).map((p) => _buildPositionRow(context, p, true)),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 150.h,
                  color: Theme.of(context).dividerColor,
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_down,
                            color: AppTheme.lossColor,
                            size: 18.w,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'market.top_losers'.tr(),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.sp,
                              color: AppTheme.lossColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      if (losers.isEmpty)
                        Text(
                          'No losers',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      else
                        ...losers.take(5).map((p) => _buildPositionRow(context, p, false)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPositionRow(BuildContext context, Position position, bool isGainer) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              position.symbol,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${position.pnlPercent >= 0 ? '+' : ''}${position.pnlPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.bold,
              color: isGainer ? AppTheme.profitColor : AppTheme.lossColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary statistics card
class StatisticsCard extends StatelessWidget {
  final PortfolioStatistics statistics;
  final String baseCurrency;

  const StatisticsCard({
    super.key,
    required this.statistics,
    required this.baseCurrency,
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
              'analysis.sections.performance'.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 16.h),
            _buildStatRow(
              context,
              'Cumulative Return',
              '${statistics.cumulativeReturn.toStringAsFixed(2)}%',
              statistics.cumulativeReturn >= 0,
            ),
            _buildStatRow(
              context,
              '1 Month Return',
              '${statistics.oneMonthReturn.toStringAsFixed(2)}%',
              statistics.oneMonthReturn >= 0,
            ),
            _buildStatRow(
              context,
              '3 Month Return',
              '${statistics.threeMonthReturn.toStringAsFixed(2)}%',
              statistics.threeMonthReturn >= 0,
            ),
            if (statistics.bestReturn != null)
              _buildStatRow(
                context,
                'Best Month (${statistics.bestReturnDate ?? 'N/A'})',
                '${statistics.bestReturn!.toStringAsFixed(2)}%',
                true,
              ),
            if (statistics.worstReturn != null)
              _buildStatRow(
                context,
                'Worst Month (${statistics.worstReturnDate ?? 'N/A'})',
                '${statistics.worstReturn!.toStringAsFixed(2)}%',
                false,
              ),
            const Divider(),
            _buildStatRow(
              context,
              'Dividends',
              _formatCurrency(statistics.dividends, baseCurrency),
              statistics.dividends >= 0,
            ),
            _buildStatRow(
              context,
              'Fees & Commissions',
              _formatCurrency(statistics.feesCommissions, baseCurrency),
              false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, String label, String value, bool isPositive) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isPositive ? AppTheme.profitColor : AppTheme.lossColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value, String currency) {
    final symbol = _getCurrencySymbol(currency);
    return '$symbol${value.abs().toStringAsFixed(2)}';
  }

  String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'EUR':
        return 'EUR ';
      case 'USD':
        return '\$';
      case 'GBP':
        return 'GBP ';
      case 'CHF':
        return 'CHF ';
      case 'JPY':
        return 'JPY ';
      default:
        return '$currency ';
    }
  }
}