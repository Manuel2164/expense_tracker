import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../format.dart';
import '../models/expense.dart';
import 'expense_store.dart';

// These names, the saved keys and the pending-expense format must match the
// Kotlin side in android/app/src/main/kotlin/.../WidgetData.kt.
const _androidProviders = ['ExpenseWidgetProvider', 'QuickAddWidgetProvider'];
const _pendingKey = 'pending_expenses';

/// Connects [store] to the Android home-screen widgets: expenses typed into
/// the quick-add widget are imported whenever the app starts or returns to the
/// front, and the widgets are redrawn whenever the store changes. Does nothing
/// on other platforms.
void keepHomeWidgetsInSync(ExpenseStore store) {
  if (!Platform.isAndroid) return;
  var pending = Future<void>.value();

  // Chained so imports and updates never overlap or land out of order.
  void run(Future<void> Function() task) {
    pending = pending.then((_) async {
      try {
        await task();
      } on Exception catch (error) {
        debugPrint('Home-screen widget sync failed: $error');
      }
    });
  }

  void push() => run(() async {
    final now = DateTime.now();
    await HomeWidget.saveWidgetData(
      'month_key',
      '${now.year}-${now.month.toString().padLeft(2, '0')}',
    );
    await HomeWidget.saveWidgetData(
      'month_total_minor',
      store.totalForMonth(monthOf(now)),
    );
    await HomeWidget.saveWidgetData('currency_symbol', store.currency.symbol);
    for (final provider in _androidProviders) {
      await HomeWidget.updateWidget(androidName: provider);
    }
  });

  void importPending() => run(() => _importPending(store));

  store.addListener(push);
  importPending();
  push();
  AppLifecycleListener(onResume: importPending);
}

/// Moves expenses queued by the quick-add widget into [store].
Future<void> _importPending(ExpenseStore store) async {
  final raw = await HomeWidget.getWidgetData<String>(_pendingKey);
  if (raw == null) return;
  final entries = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  if (entries.isEmpty) return;
  // Emptied first: the widgets count queued expenses on top of the saved
  // total, so they must not see both.
  await HomeWidget.saveWidgetData(_pendingKey, '[]');
  for (final entry in entries) {
    store.add(
      Expense(
        id: store.newId(),
        amountMinor: (entry['amount'] as num).toInt(),
        category: ExpenseCategory.fromName(entry['category'] as String?),
        date: DateTime.fromMillisecondsSinceEpoch(
          (entry['time'] as num).toInt(),
        ),
      ),
    );
  }
}

/// Calls [onQuickAdd] whenever the monthly-total widget's add button opens the
/// app, whether that started the app or brought it back to the front.
StreamSubscription<Uri?>? listenForQuickAdd(VoidCallback onQuickAdd) {
  if (!Platform.isAndroid) return null;

  void handle(Uri? uri) {
    if (uri?.host == 'add') onQuickAdd();
  }

  HomeWidget.initiallyLaunchedFromHomeWidget().then(handle);
  return HomeWidget.widgetClicked.listen(handle);
}
