import 'package:intl/intl.dart';

final _inrWhole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inrPaise = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

/// Formats an amount held in paise, with Indian digit grouping (₹1,23,456).
String inr(int paise, {bool withPaise = false}) =>
    (withPaise ? _inrPaise : _inrWhole).format(paise / 100);

String inrThousands(int paise) => '₹${(paise / 100000).toStringAsFixed(1)}k';

/// Parses user-typed rupees ("1,234.50", "₹525") into paise.
int? parsePaise(String input) {
  final cleaned = input.replaceAll(RegExp(r'[₹,\s]'), '');
  if (cleaned.isEmpty) return null;
  final rupees = double.tryParse(cleaned);
  return rupees == null ? null : (rupees * 100).round();
}

String paiseToField(int? paise) => paise == null ? '' : (paise / 100).toStringAsFixed(2);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool sameMonth(DateTime a, DateTime b) => a.year == b.year && a.month == b.month;

/// Indian financial year starts on 1 April.
DateTime financialYearStart(DateTime d) =>
    d.month >= 4 ? DateTime(d.year, 4, 1) : DateTime(d.year - 1, 4, 1);

String financialYearLabel(DateTime d) {
  final start = financialYearStart(d).year % 100;
  String two(int n) => (n % 100).toString().padLeft(2, '0');
  return 'FY ${two(start)}–${two(start + 1)}';
}

final _short = DateFormat('d MMM');
final _long = DateFormat('d MMM y');
final _weekday = DateFormat('EEEE, d MMMM');
final _month = DateFormat('MMMM');
final _monthShort = DateFormat('MMM');
final _monthYear = DateFormat('MMMM y');

String shortDate(DateTime d) => _short.format(d);
String longDate(DateTime d) => _long.format(d);
String weekdayDate(DateTime d) => _weekday.format(d);
String monthName(DateTime d) => _month.format(d);
String monthShort(DateTime d) => _monthShort.format(d);
String monthYear(DateTime d) => _monthYear.format(d);
