import 'package:flutter/material.dart';

import '../format.dart';

/// Order matters: chart colors are assigned by index, and [other] must stay
/// last (it is drawn in neutral gray).
enum ExpenseCategory {
  food('Food & Dining', Icons.restaurant_outlined),
  transport('Transport', Icons.directions_bus_outlined),
  bills('Bills & Utilities', Icons.receipt_long_outlined),
  shopping('Shopping', Icons.shopping_bag_outlined),
  entertainment('Entertainment', Icons.movie_outlined),
  health('Health', Icons.favorite_outline),
  education('Education', Icons.school_outlined),
  other('Other', Icons.more_horiz);

  const ExpenseCategory(this.label, this.icon);

  final String label;
  final IconData icon;

  static ExpenseCategory fromName(String? name) => values.firstWhere(
    (c) => c.name == name,
    orElse: () => ExpenseCategory.other,
  );
}

class Expense {
  Expense({
    required this.id,
    required this.amountMinor,
    required this.category,
    required DateTime date,
    this.note = '',
  }) : date = dateOnly(date);

  final String id;

  /// Amount in minor units (cents), to avoid floating point drift in sums.
  final int amountMinor;
  final ExpenseCategory category;
  final DateTime date;
  final String note;

  String get title => note.isEmpty ? category.label : note;

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    amountMinor: (json['amount'] as num).toInt(),
    category: ExpenseCategory.fromName(json['category'] as String?),
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amountMinor,
    'category': category.name,
    'date': date.toIso8601String().substring(0, 10),
    'note': note,
  };
}
