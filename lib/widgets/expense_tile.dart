import 'package:flutter/material.dart';

import '../data/expense_store.dart';
import '../format.dart';
import '../models/expense.dart';
import '../screens/expense_form.dart';
import '../theme.dart';

/// One expense row; tapping opens it for editing.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final color = ChartPalette.of(context).category(expense.category);
    final subtitle = expense.note.isEmpty
        ? formatDay(expense.date)
        : '${expense.category.label} · ${formatDay(expense.date)}';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(expense.category.icon, color: color, size: 20),
      ),
      title: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatMoney(expense.amountMinor, store.currency),
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: () => openExpenseForm(context, expense: expense),
    );
  }
}
