import 'package:flutter/material.dart';

import 'models/expense.dart';

const _seed = Color(0xFF2A78D6);

ThemeData buildTheme(Brightness brightness) => ThemeData(
  colorSchemeSeed: _seed,
  brightness: brightness,
  cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero),
);

/// Colors used by the dashboard charts. Each mode has its own steps of the
/// same hues, chosen to stay distinguishable (including for colorblind
/// viewers) on that mode's surface.
class ChartPalette {
  const ChartPalette._({
    required this.series,
    required this.seriesMuted,
    required this.grid,
    required this.axis,
    required this.mutedInk,
    required this.good,
    required this.other,
    required this.categorical,
  });

  /// Highlighted bar in the monthly trend.
  final Color series;

  /// Non-selected bars in the monthly trend.
  final Color seriesMuted;
  final Color grid;
  final Color axis;
  final Color mutedInk;

  /// "Spending went down" text.
  final Color good;
  final Color other;
  final List<Color> categorical;

  static const light = ChartPalette._(
    series: Color(0xFF2A78D6),
    seriesMuted: Color(0xFF9EC5F4),
    grid: Color(0xFFE1E0D9),
    axis: Color(0xFFC3C2B7),
    mutedInk: Color(0xFF6F6D68),
    good: Color(0xFF006300),
    other: Color(0xFF898781),
    categorical: [
      Color(0xFF2A78D6),
      Color(0xFFEB6834),
      Color(0xFF1BAF7A),
      Color(0xFFEDA100),
      Color(0xFFE87BA4),
      Color(0xFF008300),
      Color(0xFF4A3AA7),
    ],
  );

  static const dark = ChartPalette._(
    series: Color(0xFF3987E5),
    seriesMuted: Color(0xFF184F95),
    grid: Color(0xFF2C2C2A),
    axis: Color(0xFF383835),
    mutedInk: Color(0xFFA09E97),
    good: Color(0xFF0CA30C),
    other: Color(0xFF898781),
    categorical: [
      Color(0xFF3987E5),
      Color(0xFFD95926),
      Color(0xFF199E70),
      Color(0xFFC98500),
      Color(0xFFD55181),
      Color(0xFF008300),
      Color(0xFF9085E9),
    ],
  );

  static ChartPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  Color category(ExpenseCategory category) =>
      category == ExpenseCategory.other ? other : categorical[category.index];
}
