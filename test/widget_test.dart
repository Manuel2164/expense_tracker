import 'dart:io';

import 'package:expense_tracker/data/expense_store.dart';
import 'package:expense_tracker/format.dart';
import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

var _nextId = 0;

Expense expense(int amountMinor, ExpenseCategory category, DateTime date) =>
    Expense(
      id: '${_nextId++}',
      amountMinor: amountMinor,
      category: category,
      date: date,
    );

void main() {
  final now = DateTime(2026, 10, 5);

  group('ExpenseStore', () {
    test('monthly totals cover the requested range, oldest first', () {
      final store = ExpenseStore()
        ..add(expense(1000, ExpenseCategory.food, DateTime(2026, 10, 2)))
        ..add(expense(250, ExpenseCategory.food, DateTime(2026, 10, 4)))
        ..add(expense(4000, ExpenseCategory.bills, DateTime(2026, 8, 20)))
        // Outside a 3-month window.
        ..add(expense(9999, ExpenseCategory.other, DateTime(2026, 7, 31)));

      final totals = store.monthlyTotals(3, now: now);

      expect(totals.map((t) => t.month), [
        DateTime(2026, 8),
        DateTime(2026, 9),
        DateTime(2026, 10),
      ]);
      expect(totals.map((t) => t.total), [4000, 0, 1250]);
    });

    test('monthly range crosses a year boundary', () {
      final totals = ExpenseStore().monthlyTotals(
        3,
        now: DateTime(2026, 1, 15),
      );
      expect(totals.first.month, DateTime(2025, 11));
    });

    test('category totals are summed and ranked largest first', () {
      final store = ExpenseStore()
        ..add(expense(500, ExpenseCategory.food, DateTime(2026, 10, 1)))
        ..add(expense(900, ExpenseCategory.transport, DateTime(2026, 10, 2)))
        ..add(expense(700, ExpenseCategory.food, DateTime(2026, 10, 3)))
        ..add(expense(5000, ExpenseCategory.bills, DateTime(2026, 9, 3)));

      final totals = store.categoryTotals(DateTime(2026, 10));

      expect(totals, [
        (category: ExpenseCategory.food, total: 1200),
        (category: ExpenseCategory.transport, total: 900),
      ]);
    });

    test('expenses and currency survive a save and reload', () async {
      final dir = await Directory.systemTemp.createTemp('expense_tracker_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/expenses.json');

      final store = ExpenseStore(file: file)
        ..setCurrency(currencyByCode('NGN'))
        ..add(
          Expense(
            id: 'a',
            amountMinor: 123456,
            category: ExpenseCategory.health,
            date: DateTime(2026, 10, 5, 14, 30),
            note: 'Pharmacy',
          ),
        );
      await store.flush();

      final reloaded = await ExpenseStore.openFile(file);

      expect(reloaded.currency.code, 'NGN');
      final saved = reloaded.expenses.single;
      expect(saved.amountMinor, 123456);
      expect(saved.category, ExpenseCategory.health);
      expect(saved.date, DateTime(2026, 10, 5));
      expect(saved.note, 'Pharmacy');
    });
  });

  testWidgets('dashboard shows trends, then an added expense appears', (
    tester,
  ) async {
    final store = ExpenseStore()..addSampleData();
    await tester.pumpWidget(ExpenseTrackerApp(store: store));

    expect(find.text('Monthly spending'), findsOneWidget);
    expect(find.text('By category'), findsOneWidget);
    expect(
      find.text(
        formatMoney(
          store.totalForMonth(monthOf(DateTime.now())),
          store.currency,
        ),
      ),
      findsOneWidget,
    );

    final before = store.expenses.length;
    await tester.tap(find.text('Add expense'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '12.50');
    await tester.enterText(find.byType(TextFormField).last, 'Test coffee');
    await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
    await tester.pumpAndSettle();

    expect(store.expenses.length, before + 1);
    expect(store.expenses.first.amountMinor, 1250);
    expect(find.text('Test coffee'), findsWidgets);
  });

  testWidgets('empty state offers to add an expense', (tester) async {
    await tester.pumpWidget(ExpenseTrackerApp(store: ExpenseStore()));
    expect(find.text('No expenses yet'), findsWidgets);
  });
}
