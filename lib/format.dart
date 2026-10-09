import 'package:intl/intl.dart';

class Currency {
  const Currency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;
}

/// All supported currencies use two decimal places, so amounts can be stored
/// as integer minor units (cents, kobo, pence...).
const currencies = [
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('NGN', '₦', 'Nigerian Naira'),
  Currency('GHS', '₵', 'Ghanaian Cedi'),
  Currency('KES', 'KSh', 'Kenyan Shilling'),
  Currency('ZAR', 'R', 'South African Rand'),
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('CAD', r'CA$', 'Canadian Dollar'),
  Currency('AUD', r'A$', 'Australian Dollar'),
];

Currency currencyByCode(String? code) => currencies.firstWhere(
  (c) => c.code == code,
  orElse: () => currencies.first,
);

String formatMoney(int minor, Currency currency) => NumberFormat.currency(
  symbol: currency.symbol,
  decimalDigits: 2,
).format(minor / 100);

/// Short form for axis ticks: 0, 500, 1.5K, 2M.
String formatCompact(double value) {
  String trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  if (value >= 1e6) return '${trim(value / 1e6)}M';
  if (value >= 1e3) return '${trim(value / 1e3)}K';
  return trim(value);
}

DateTime monthOf(DateTime date) => DateTime(date.year, date.month);

DateTime addMonths(DateTime month, int count) =>
    DateTime(month.year, month.month + count);

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String formatMonth(DateTime month) => DateFormat('MMMM y').format(month);

String formatMonthName(DateTime month) => DateFormat('MMMM').format(month);

String formatDay(DateTime date) => DateFormat('EEE, MMM d').format(date);
