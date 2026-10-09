import 'package:flutter/material.dart';

import '../data/expense_store.dart';
import '../format.dart';
import '../widgets/update_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _pickCurrency(BuildContext context) async {
    final store = StoreScope.of(context);
    final picked = await showDialog<Currency>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Currency'),
        children: [
          for (final currency in currencies)
            ListTile(
              leading: SizedBox(
                width: 40,
                child: Text(
                  currency.symbol,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              title: Text(currency.name),
              subtitle: Text(currency.code),
              trailing: currency.code == store.currency.code
                  ? const Icon(Icons.check)
                  : null,
              onTap: () => Navigator.of(context).pop(currency),
            ),
        ],
      ),
    );
    if (picked != null) store.setCurrency(picked);
  }

  Future<void> _confirmClear(BuildContext context) async {
    final store = StoreScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all expenses?'),
        content: Text(
          'This permanently removes all ${store.expenses.length} expenses '
          'from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true) store.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Currency'),
              subtitle: Text(
                '${store.currency.name} (${store.currency.symbol})',
              ),
              onTap: () => _pickCurrency(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Add sample data'),
              subtitle: const Text(
                'Six months of made-up expenses to try the dashboard',
              ),
              onTap: store.addSampleData,
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: const Text('Delete all expenses'),
              enabled: !store.isEmpty,
              onTap: () => _confirmClear(context),
            ),
            const Divider(),
            const UpdateTile(),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Your data stays on this device'),
              subtitle: Text('Expenses are saved locally and never uploaded.'),
            ),
          ],
        ),
      ),
    );
  }
}
