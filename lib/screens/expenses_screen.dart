import 'package:flutter/material.dart';

import '../data/expense_store.dart';
import '../format.dart';
import '../models/expense.dart';
import '../widgets/expense_tile.dart';

/// Every expense, newest first, grouped by month, with search and a
/// category filter.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _query = '';
  ExpenseCategory? _category;

  void _delete(Expense expense) {
    final store = StoreScope.of(context);
    store.remove(expense.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Deleted "${expense.title}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.add(expense),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();

    final filtered = store.expenses.where(
      (e) =>
          (_category == null || e.category == _category) &&
          (query.isEmpty ||
              e.note.toLowerCase().contains(query) ||
              e.category.label.toLowerCase().contains(query)),
    );

    // Flatten into month headers followed by that month's expenses.
    final items = <Object>[];
    final monthTotals = <DateTime, int>{};
    for (final expense in filtered) {
      final month = monthOf(expense.date);
      if (!monthTotals.containsKey(month)) items.add(month);
      monthTotals[month] = (monthTotals[month] ?? 0) + expense.amountMinor;
      items.add(expense);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search expenses',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final category in [null, ...ExpenseCategory.values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(category?.label ?? 'All'),
                        selected: category == _category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        store.isEmpty
                            ? 'No expenses yet'
                            : 'No expenses match your filters',
                        style: theme.textTheme.bodyLarge,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: items.length,
                      itemBuilder: (context, index) => switch (items[index]) {
                        DateTime month => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 24, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  formatMonth(month),
                                  style: theme.textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                formatMoney(
                                  monthTotals[month]!,
                                  store.currency,
                                ),
                                style: theme.textTheme.titleSmall,
                              ),
                            ],
                          ),
                        ),
                        Expense expense => Dismissible(
                          key: ValueKey(expense.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: theme.colorScheme.errorContainer,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                          onDismissed: (_) => _delete(expense),
                          child: ExpenseTile(expense: expense),
                        ),
                        _ => const SizedBox.shrink(),
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
