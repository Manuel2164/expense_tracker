import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/expense_store.dart';
import '../format.dart';
import '../theme.dart';

/// Column chart of total spending per month. Tapping a column selects it.
class MonthlyTrendChart extends StatelessWidget {
  const MonthlyTrendChart({
    super.key,
    required this.totals,
    required this.selected,
    required this.currency,
    required this.onSelect,
  });

  final List<MonthTotal> totals;
  final DateTime selected;
  final Currency currency;
  final ValueChanged<DateTime> onSelect;

  static const _axisWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final scheme = Theme.of(context).colorScheme;
    final tickStyle = TextStyle(
      fontSize: 11,
      color: palette.mutedInk,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final maxValue = totals.map((t) => t.total / 100).fold(0.0, max);
    final step = _niceStep(maxValue);
    final maxY = max(4, (maxValue / step).ceil()) * step;

    return Semantics(
      label:
          'Monthly spending. ${[for (final t in totals) '${formatMonth(t.month)}: ${formatMoney(t.total, currency)}'].join(', ')}',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = (constraints.maxWidth - _axisWidth) / totals.length;
          final monthLabel = DateFormat(slot < 30 ? 'MMMMM' : 'MMM');
          return BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              alignment: BarChartAlignment.spaceAround,
              barGroups: [
                for (final (i, t) in totals.indexed)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: t.total / 100,
                        width: min(24, slot * 0.6),
                        color: t.month == selected
                            ? palette.series
                            : palette.seriesMuted,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: step,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: palette.grid, strokeWidth: 1),
              ),
              borderData: FlBorderData(
                border: Border(bottom: BorderSide(color: palette.axis)),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: _axisWidth,
                    interval: step,
                    getTitlesWidget: (value, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text(formatCompact(value), style: tickStyle),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final month = totals[value.toInt()].month;
                      final isSelected = month == selected;
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(
                          monthLabel.format(month),
                          style: tickStyle.copyWith(
                            color: isSelected ? scheme.onSurface : null,
                            fontWeight: isSelected ? FontWeight.w600 : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.inverseSurface,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItem: (group, _, rod, _) {
                    final t = totals[group.x];
                    return BarTooltipItem(
                      '${DateFormat('MMM y').format(t.month)}\n',
                      TextStyle(color: scheme.onInverseSurface, fontSize: 12),
                      children: [
                        TextSpan(
                          text: formatMoney(t.total, currency),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                touchCallback: (event, response) {
                  final spot = response?.spot;
                  if (event is FlTapUpEvent && spot != null) {
                    onSelect(totals[spot.touchedBarGroupIndex].month);
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// A round tick interval (1, 2 or 5 × a power of ten) giving about 4 ticks.
  static double _niceStep(double maxValue) {
    if (maxValue <= 0) return 1;
    final raw = maxValue / 4;
    final magnitude = pow(10, (log(raw) / ln10).floor()).toDouble();
    final normalized = raw / magnitude;
    final step = normalized <= 1
        ? 1
        : normalized <= 2
        ? 2
        : normalized <= 5
        ? 5
        : 10;
    return step * magnitude;
  }
}

/// Ranked list of categories with a share-of-total bar under each row.
class CategoryBreakdown extends StatelessWidget {
  const CategoryBreakdown({
    super.key,
    required this.totals,
    required this.currency,
  });

  final List<CategoryTotal> totals;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final palette = ChartPalette.of(context);
    final text = Theme.of(context).textTheme;
    final sum = totals.fold(0, (sum, t) => sum + t.total);

    if (totals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No expenses this month',
            style: text.bodyMedium?.copyWith(color: palette.mutedInk),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final t in totals)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette.category(t.category),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        t.category.label,
                        style: text.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatMoney(t.total, currency),
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(t.total * 100 / sum).round()}%',
                        textAlign: TextAlign.end,
                        style: text.bodySmall?.copyWith(
                          color: palette.mutedInk,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: 6,
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: palette.grid,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: t.total / sum,
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.category(t.category),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
