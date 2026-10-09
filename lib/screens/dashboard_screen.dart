import 'package:flutter/material.dart';

import '../data/expense_store.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/expense_tile.dart';
import 'expense_form.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onSeeAll});

  /// Called when the user wants the full expense list.
  final VoidCallback onSeeAll;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _range = 6;

  /// Month picked by tapping the trend chart; null means the current month.
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.isEmpty) return const _EmptyDashboard();

    final now = DateTime.now();
    final current = monthOf(now);
    final totals = store.monthlyTotals(_range, now: now);
    var selected = _selected ?? current;
    if (!totals.any((t) => t.month == selected)) selected = current;

    final trend = _Panel(
      title: 'Monthly spending',
      subtitle: 'Tap a month to see its details',
      trailing: SegmentedButton<int>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: const [
          ButtonSegment(value: 3, label: Text('3M')),
          ButtonSegment(value: 6, label: Text('6M')),
          ButtonSegment(value: 12, label: Text('12M')),
        ],
        selected: {_range},
        onSelectionChanged: (value) => setState(() => _range = value.first),
      ),
      child: SizedBox(
        height: 240,
        child: MonthlyTrendChart(
          totals: totals,
          selected: selected,
          currency: store.currency,
          onSelect: (month) => setState(() => _selected = month),
        ),
      ),
    );

    final categories = _Panel(
      title: 'By category',
      subtitle: formatMonth(selected),
      child: CategoryBreakdown(
        totals: store.categoryTotals(selected),
        currency: store.currency,
      ),
    );

    final recent = _Panel(
      title: 'Recent expenses',
      trailing: TextButton(
        onPressed: widget.onSeeAll,
        child: const Text('See all'),
      ),
      padChild: false,
      child: Column(
        children: [
          for (final expense in store.expenses.take(5))
            ExpenseTile(expense: expense),
          const SizedBox(height: 8),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            // Leave room for the floating "Add expense" button.
            96,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    _Summary(month: selected, now: now),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 16,
                        children: [
                          Expanded(flex: 3, child: trend),
                          Expanded(flex: 2, child: categories),
                        ],
                      )
                    else ...[
                      trend,
                      categories,
                    ],
                    recent,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Headline total for [month] with the change from the month before.
class _Summary extends StatelessWidget {
  const _Summary({required this.month, required this.now});

  final DateTime month;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final palette = ChartPalette.of(context);

    final expenses = store.forMonth(month);
    final total = store.totalForMonth(month);
    final previousMonth = addMonths(month, -1);
    final previous = store.totalForMonth(previousMonth);
    final categories = store.categoryTotals(month);
    // For the month in progress, average over the days elapsed so far.
    final days = month == monthOf(now)
        ? now.day
        : DateUtils.getDaysInMonth(month.year, month.month);

    final Widget delta;
    if (previous == 0) {
      delta = Text(
        'Nothing recorded in ${formatMonthName(previousMonth)} to compare',
        style: theme.textTheme.bodyMedium?.copyWith(color: palette.mutedInk),
      );
    } else {
      final change = (total - previous) * 100 / previous;
      final up = change > 0;
      final color = up ? theme.colorScheme.error : palette.good;
      delta = Row(
        children: [
          Icon(
            up ? Icons.arrow_upward : Icons.arrow_downward,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${change.abs().round()}% ${up ? 'more' : 'less'} than ${formatMonthName(previousMonth)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spent in ${formatMonth(month)}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: palette.mutedInk,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                formatMoney(total, store.currency),
                style: const TextStyle(
                  fontSize: 48,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            delta,
            const Divider(height: 32),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 12,
              children: [
                _Stat(
                  label: 'Daily average',
                  value: formatMoney(total ~/ days, store.currency),
                ),
                _Stat(label: 'Expenses', value: '${expenses.length}'),
                _Stat(
                  label: 'Top category',
                  value: categories.isEmpty
                      ? '–'
                      : categories.first.category.label,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.bodySmall?.copyWith(
              color: ChartPalette.of(context).mutedInk,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.padChild = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  /// False for children (like list tiles) that bring their own side padding.
  final bool padChild;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: text.bodySmall?.copyWith(
                            color: ChartPalette.of(context).mutedInk,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          Padding(
            padding: padChild
                ? const EdgeInsets.fromLTRB(20, 0, 20, 16)
                : EdgeInsets.zero,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  const _EmptyDashboard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No expenses yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add your first expense and your spending trends will show up here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openExpenseForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => StoreScope.of(context).addSampleData(),
              child: const Text('Try it with sample data'),
            ),
          ],
        ),
      ),
    );
  }
}
