import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'expense_form.dart';
import 'expenses_screen.dart';
import 'settings_screen.dart';

/// App frame: a bottom bar on phones, a side rail on wide (desktop) windows.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _tabs = [
    (label: 'Dashboard', icon: Icons.insights_outlined),
    (label: 'Expenses', icon: Icons.receipt_long_outlined),
    (label: 'Settings', icon: Icons.settings_outlined),
  ];

  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final body = IndexedStack(
      index: _index,
      children: [
        DashboardScreen(onSeeAll: () => setState(() => _index = 1)),
        const ExpensesScreen(),
        const SettingsScreen(),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(_tabs[_index].label)),
      body: wide
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [
                    for (final tab in _tabs)
                      NavigationRailDestination(
                        icon: Icon(tab.icon),
                        label: Text(tab.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final tab in _tabs)
                  NavigationDestination(icon: Icon(tab.icon), label: tab.label),
              ],
            ),
      floatingActionButton: _index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () => openExpenseForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
    );
  }
}
