import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../format.dart';
import '../models/expense.dart';

typedef MonthTotal = ({DateTime month, int total});
typedef CategoryTotal = ({ExpenseCategory category, int total});

/// Holds every expense in memory and persists them to a JSON file on the
/// device. Without a [file] it is purely in-memory (used by tests).
class ExpenseStore extends ChangeNotifier {
  ExpenseStore({this._file});

  final File? _file;
  final List<Expense> _expenses = [];
  Currency _currency = currencies.first;
  Future<void> _pendingSave = Future.value();
  int _idCounter = 0;

  static Future<ExpenseStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return openFile(File('${dir.path}${Platform.pathSeparator}expenses.json'));
  }

  static Future<ExpenseStore> openFile(File file) async {
    final store = ExpenseStore(file: file);
    await store._load();
    return store;
  }

  /// Newest first.
  List<Expense> get expenses => List.unmodifiable(_expenses);
  bool get isEmpty => _expenses.isEmpty;
  Currency get currency => _currency;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

  void add(Expense expense) {
    _expenses.add(expense);
    _changed();
  }

  void update(Expense expense) {
    final index = _expenses.indexWhere((e) => e.id == expense.id);
    if (index == -1) return;
    _expenses[index] = expense;
    _changed();
  }

  void remove(String id) {
    _expenses.removeWhere((e) => e.id == id);
    _changed();
  }

  void clear() {
    _expenses.clear();
    _changed();
  }

  void setCurrency(Currency currency) {
    _currency = currency;
    _changed();
  }

  // Queries ------------------------------------------------------------------

  List<Expense> forMonth(DateTime month) =>
      _expenses.where((e) => monthOf(e.date) == month).toList();

  int totalForMonth(DateTime month) =>
      forMonth(month).fold(0, (sum, e) => sum + e.amountMinor);

  /// Totals for the last [count] months, oldest first, ending at [now]'s month.
  List<MonthTotal> monthlyTotals(int count, {DateTime? now}) {
    final current = monthOf(now ?? DateTime.now());
    return [
      for (var i = count - 1; i >= 0; i--)
        (
          month: addMonths(current, -i),
          total: totalForMonth(addMonths(current, -i)),
        ),
    ];
  }

  /// Per-category totals for [month], largest first.
  List<CategoryTotal> categoryTotals(DateTime month) {
    final totals = <ExpenseCategory, int>{};
    for (final e in forMonth(month)) {
      totals[e.category] = (totals[e.category] ?? 0) + e.amountMinor;
    }
    return [
      for (final entry in totals.entries)
        (category: entry.key, total: entry.value),
    ]..sort((a, b) => b.total.compareTo(a.total));
  }

  // Sample data --------------------------------------------------------------

  /// Adds six months of made-up expenses so the dashboard has something to show.
  void addSampleData({DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final random = Random(42);
    // (category, entries per month, min, max) in major units.
    const plan = [
      (ExpenseCategory.food, 9, 8, 60, ['Groceries', 'Lunch', 'Dinner out']),
      (ExpenseCategory.transport, 6, 3, 35, ['Fuel', 'Bus fare', 'Taxi']),
      (ExpenseCategory.bills, 3, 40, 180, ['Electricity', 'Internet', 'Rent']),
      (ExpenseCategory.shopping, 2, 20, 150, ['Clothes', 'Household']),
      (ExpenseCategory.entertainment, 2, 10, 50, ['Movies', 'Streaming']),
      (ExpenseCategory.health, 1, 15, 90, ['Pharmacy', 'Gym']),
      (ExpenseCategory.education, 1, 20, 120, ['Books', 'Online course']),
    ];
    for (var back = 0; back < 6; back++) {
      final month = addMonths(monthOf(today), -back);
      final lastDay = back == 0
          ? today.day
          : DateTime(month.year, month.month + 1, 0).day;
      for (final (category, count, min, max, notes) in plan) {
        for (var i = 0; i < count; i++) {
          _expenses.add(
            Expense(
              id: newId(),
              amountMinor: (min * 100) + random.nextInt((max - min) * 100),
              category: category,
              date: DateTime(
                month.year,
                month.month,
                1 + random.nextInt(lastDay),
              ),
              note: notes[random.nextInt(notes.length)],
            ),
          );
        }
      }
    }
    _changed();
  }

  // Persistence --------------------------------------------------------------

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) return;
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      _currency = currencyByCode(json['currency'] as String?);
      _expenses.addAll(
        (json['expenses'] as List).map(
          (e) => Expense.fromJson(e as Map<String, dynamic>),
        ),
      );
      _sort();
    } on Object catch (error) {
      // Keep the unreadable file around rather than overwriting it on next save.
      debugPrint('Could not read ${file.path}: $error');
      _expenses.clear();
      await file.copy('${file.path}.bak');
    }
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'currency': _currency.code,
    'expenses': [for (final e in _expenses) e.toJson()],
  };

  void _sort() {
    _expenses.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });
  }

  void _changed() {
    _sort();
    notifyListeners();
    final file = _file;
    if (file == null) return;
    final contents = jsonEncode(toJson());
    // Saves are chained so they never overlap; write-then-rename keeps the
    // previous file intact if the app dies mid-write.
    _pendingSave = _pendingSave.then((_) async {
      try {
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(contents, flush: true);
        await tmp.rename(file.path);
      } on FileSystemException catch (error) {
        debugPrint('Could not save ${file.path}: $error');
      }
    });
  }

  /// Completes when all queued saves have been written.
  Future<void> flush() => _pendingSave;
}

/// Exposes the [ExpenseStore] to the widget tree; dependents rebuild whenever
/// the store changes.
class StoreScope extends InheritedNotifier<ExpenseStore> {
  const StoreScope({
    super.key,
    required ExpenseStore store,
    required super.child,
  }) : super(notifier: store);

  static ExpenseStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
