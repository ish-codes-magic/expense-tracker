import '../data/models.dart';
import 'gst.dart';

/// What the rules could find in a receipt's text. Anything not found is null
/// and left for the user to fill in on Review.
class ParsedReceipt {
  const ParsedReceipt({
    this.merchant,
    this.date,
    this.totalPaise,
    this.gstPaise,
    this.gstRate,
    this.taxSplit = TaxSplit.none,
    this.gstin,
    this.payment,
    this.categoryId,
    this.items = const [],
  });

  final String? merchant;
  final DateTime? date;
  final int? totalPaise;
  final int? gstPaise;

  /// Null when not found or when the bill mixes several rates.
  final int? gstRate;
  final TaxSplit taxSplit;
  final String? gstin;
  final PaymentMethod? payment;
  final String? categoryId;
  final List<LineItem> items;

  /// This reading, with gaps filled from [other]. The amounts come as a set
  /// (total, GST, rate and split together) so a total from one reading is
  /// never paired with GST from the other. A GSTIN that passes its check
  /// digit beats one that doesn't.
  ParsedReceipt filledFrom(ParsedReceipt other) {
    final amountsHere = totalPaise != null;
    String? bestGstin() {
      if (gstin != null && isValidGstin(gstin!)) return gstin;
      if (other.gstin != null && isValidGstin(other.gstin!)) return other.gstin;
      return gstin ?? other.gstin;
    }

    return ParsedReceipt(
      merchant: merchant ?? other.merchant,
      date: date ?? other.date,
      totalPaise: amountsHere ? totalPaise : other.totalPaise,
      gstPaise: amountsHere ? gstPaise : other.gstPaise,
      gstRate: amountsHere ? gstRate : other.gstRate,
      taxSplit: amountsHere ? taxSplit : other.taxSplit,
      gstin: bestGstin(),
      payment: payment ?? other.payment,
      categoryId: categoryId ?? other.categoryId,
      items: items.isNotEmpty ? items : other.items,
    );
  }
}

/// A piece of recognised text and where it sits on the photo.
typedef OcrLine = ({String text, double top, double bottom, double left});

/// Rebuilds the receipt's printed rows. Text recognition often returns a
/// row's label and its amount as separate pieces ("Grand Total" on the left,
/// "525.00" on the right); pieces whose vertical middles fall inside the same
/// band are joined left to right.
List<String> groupIntoRows(List<OcrLine> lines) {
  final sorted = [...lines]..sort((a, b) => (a.top + a.bottom).compareTo(b.top + b.bottom));
  final rows = <List<OcrLine>>[];
  for (final line in sorted) {
    final middle = (line.top + line.bottom) / 2;
    final row = rows.isEmpty ? null : rows.last;
    if (row != null && middle >= row.first.top && middle <= row.first.bottom) {
      row.add(line);
    } else {
      rows.add([line]);
    }
  }
  return [
    for (final row in rows) (row..sort((a, b) => a.left.compareTo(b.left))).map((l) => l.text).join('  '),
  ];
}

ParsedReceipt parseReceiptText(List<String> rows, {required DateTime today}) {
  final total = _findTotal(rows);
  final tax = _findGst(rows, total);
  final merchant = _findMerchant(rows);
  return ParsedReceipt(
    merchant: merchant,
    date: _findDate(rows, today),
    totalPaise: total,
    gstPaise: tax?.paise,
    gstRate: tax?.rate,
    taxSplit: tax?.split ?? TaxSplit.none,
    gstin: _findGstin(rows),
    payment: _findPayment(rows),
    // The merchant's own name counts before the rest of the header.
    categoryId: (merchant == null ? null : guessCategory(merchant)) ?? guessCategory(rows.take(8).join(' ')),
  );
}

// ─── Amounts ──────────────────────────────────────────────────────────────────

final _percent = RegExp(r'\d+(?:\.\d+)?\s*%');
final _currency = RegExp(r'₹|\b(rs|inr)\b\.?', caseSensitive: false);
final _amount = RegExp(
    r'(?<![A-Za-z\d.])(\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)(?![A-Za-z\d%])');
final _decimalAmount = RegExp(r'(?<![A-Za-z\d.])(\d{1,3}(?:,\d{2,3})*\.\d{2}|\d+\.\d{2})(?![A-Za-z\d%])');

/// Every amount in a row, in paise. Percentages ("CGST @2.5%"), and numbers
/// stuck to letters (GSTINs, "x2" quantities), are not amounts.
List<int> amountsIn(String row) => _paise(_amount, row);

/// Only amounts written with paise ("525.00"), for guessing without a label.
List<int> _decimalAmountsIn(String row) => _paise(_decimalAmount, row);

List<int> _paise(RegExp pattern, String row) => [
      for (final m in pattern.allMatches(row.replaceAll(_percent, ' ').replaceAll(_currency, ' ')))
        (double.parse(m.group(1)!.replaceAll(',', '')) * 100).round(),
    ];

// ─── Total ────────────────────────────────────────────────────────────────────

final _strongTotal = RegExp(
    r'grand\s*total|net\s*(amount|amt|payable|total)|amount\s*(payable|due)|total\s*(amount|amt|payable|due|inr|rs|\(inr\))|bill\s*(amount|amt|total)|invoice\s*(total|value|amount)|to\s*pay',
    caseSensitive: false);
final _plainTotal = RegExp(r'\btotal\b', caseSensitive: false);
final _notTheTotal = RegExp(
    r'sub\s*-?\s*total|qty|quantity|\bitems?\b|sav(ed|ing|ings)|discount|mrp|total\s*(tax|gst|cgst|sgst|igst)|tax\s*total',
    caseSensitive: false);
final _paymentLine = RegExp(r'\b(cash|tender(ed)?|change|balance|received|paid)\b', caseSensitive: false);

/// The bill total: a strongly worded total line ("Grand Total", "Net
/// Amount"), then a plain "Total", then the largest decimal amount that isn't
/// cash handed over or change.
int? _findTotal(List<String> rows) {
  int? fromLabel(RegExp label) {
    int? found;
    for (var i = 0; i < rows.length; i++) {
      if (!label.hasMatch(rows[i]) || (label == _plainTotal && _notTheTotal.hasMatch(rows[i]))) continue;
      var amounts = amountsIn(rows[i]);
      // The amount sometimes lands on the row below its label.
      if (amounts.isEmpty && i + 1 < rows.length) amounts = amountsIn(rows[i + 1]);
      // The last matching line wins: "Total" is often followed by rounding
      // and then the final "Net Amount".
      if (amounts.isNotEmpty && amounts.last > 0) found = amounts.last;
    }
    return found;
  }

  final labelled = fromLabel(_strongTotal) ?? fromLabel(_plainTotal);
  if (labelled != null) return labelled;

  final candidates = [
    for (final row in rows)
      if (!_paymentLine.hasMatch(row)) ..._decimalAmountsIn(row),
  ];
  return candidates.isEmpty ? null : candidates.reduce((a, b) => a > b ? a : b);
}

// ─── GST ──────────────────────────────────────────────────────────────────────

final _cgst = RegExp(r'\bc\.?\s*gst\b', caseSensitive: false);
final _sgst = RegExp(r'\b(s|ut)\.?\s*gst\b', caseSensitive: false);
final _igst = RegExp(r'\bi\.?\s*gst\b', caseSensitive: false);
final _anyGst = RegExp(r'total\s*(gst|tax)|\bgst\s*(amount|amt|total)?\b|tax\s*amount', caseSensitive: false);
final _ratePercent = RegExp(r'(\d+(?:\.\d+)?)\s*%');
final _gstNumber = RegExp(r'gstin|gst\s*(no|num|number|reg)', caseSensitive: false);

typedef _Tax = ({int paise, int? rate, TaxSplit split});

/// CGST + SGST lines, or IGST lines, or a single GST/tax line. The rate comes
/// from the percentages printed beside them; several different rates mean a
/// mixed bill, so no single rate is reported.
_Tax? _findGst(List<String> rows, int? total) {
  var cgst = 0, sgst = 0, igst = 0;
  final rates = <double>{};

  void collect(String row, void Function(int) add, {required double rateFactor}) {
    final amounts = amountsIn(row);
    if (amounts.isEmpty) return;
    add(amounts.last);
    final rate = _ratePercent.firstMatch(row);
    if (rate != null) rates.add(double.parse(rate.group(1)!) * rateFactor);
  }

  for (final row in rows) {
    final c = _cgst.hasMatch(row), s = _sgst.hasMatch(row), i = _igst.hasMatch(row);
    // A row naming both CGST and SGST is a table header or summary; its
    // amounts can't be told apart, so it's skipped.
    if (c && !s) collect(row, (v) => cgst += v, rateFactor: 2);
    if (s && !c) collect(row, (v) => sgst += v, rateFactor: 2);
    if (i && !c && !s) collect(row, (v) => igst += v, rateFactor: 1);
  }

  _Tax? checked(int paise, TaxSplit split) {
    if (paise <= 0 || (total != null && paise >= total)) return null;
    // No rate printed: work it out from the amounts. Several rates printed:
    // a mixed bill, which has no single rate.
    final rate = rates.isEmpty
        ? (total == null ? null : inferGstRate(total, paise))
        : (rates.length == 1 ? rates.single.round() : null);
    return (paise: paise, rate: rate, split: split);
  }

  if (cgst > 0 || sgst > 0) {
    // A receipt that shows only one half still implies the other.
    return checked(cgst > 0 && sgst > 0 ? cgst + sgst : 2 * (cgst + sgst), TaxSplit.cgstSgst);
  }
  if (igst > 0) return checked(igst, TaxSplit.igst);

  for (final row in rows) {
    if (!_anyGst.hasMatch(row) || _gstNumber.hasMatch(row)) continue;
    final amounts = _decimalAmountsIn(row);
    if (amounts.isNotEmpty) {
      final rate = _ratePercent.firstMatch(row);
      if (rate != null) rates.add(double.parse(rate.group(1)!));
      return checked(amounts.last, TaxSplit.cgstSgst);
    }
  }
  return null;
}

// ─── GSTIN ────────────────────────────────────────────────────────────────────

const _toDigit = {'O': '0', 'Q': '0', 'D': '0', 'I': '1', 'L': '1', 'S': '5', 'B': '8', 'Z': '2', 'G': '6'};
const _toLetter = {'0': 'O', '1': 'I', '5': 'S', '8': 'B', '2': 'Z', '6': 'G'};
// Which of a GSTIN's 15 positions are digits (state code, PAN digits) and
// which are letters (PAN letters, the fixed "Z").
const _digitPositions = {0, 1, 7, 8, 9, 10};
const _letterPositions = {2, 3, 4, 5, 6, 11, 13};

/// The first GSTIN on the receipt, usually the seller's. Common misreads (O
/// for 0, S for 5 …) are corrected where the GSTIN's layout says a digit or a
/// letter must be, and a candidate that passes the check digit is preferred.
String? _findGstin(List<String> rows) {
  String? fallback;
  for (final row in rows) {
    final chars = row.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
    for (var start = 0; start + 15 <= chars.length; start++) {
      final fixed = StringBuffer();
      for (var i = 0; i < 15; i++) {
        final ch = chars[start + i];
        fixed.write(_digitPositions.contains(i)
            ? (_toDigit[ch] ?? ch)
            : _letterPositions.contains(i)
                ? (_toLetter[ch] ?? ch)
                : ch);
      }
      final candidate = fixed.toString();
      if (!RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(candidate)) continue;
      if (isValidGstin(candidate)) return candidate;
      fallback ??= candidate;
    }
  }
  // Shown on Review with a "check" mark, since its check digit fails.
  return fallback;
}

// ─── Date ─────────────────────────────────────────────────────────────────────

const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
final _numericDate = RegExp(r'\b(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{2,4})\b');
final _isoDate = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b');
final _namedDate = RegExp(r"\b(\d{1,2})(?:st|nd|rd|th)?[\s\-/.]*([a-z]{3})[a-z]*[\s\-/.,']*(\d{2,4})\b",
    caseSensitive: false);

/// The first believable date: not in the future and not more than two years
/// old. Indian bills write the day first, so 05/09/2026 is 5 September.
DateTime? _findDate(List<String> rows, DateTime today) {
  DateTime? make(int year, int month, int day) {
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final date = DateTime(year, month, day);
    if (date.month != month) return null; // 31 September and the like.
    if (date.isAfter(today) || date.isBefore(DateTime(today.year - 2, today.month, today.day))) {
      return null;
    }
    return date;
  }

  for (final row in rows) {
    for (final m in _isoDate.allMatches(row)) {
      final d = make(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
      if (d != null) return d;
    }
    for (final m in _numericDate.allMatches(row)) {
      final a = int.parse(m[1]!), b = int.parse(m[2]!), year = int.parse(m[3]!);
      final d = make(year, b, a) ?? make(year, a, b);
      if (d != null) return d;
    }
    for (final m in _namedDate.allMatches(row)) {
      final month = _months.indexOf(m[2]!.toLowerCase().substring(0, 3)) + 1;
      if (month == 0) continue;
      final d = make(int.parse(m[3]!), month, int.parse(m[1]!));
      if (d != null) return d;
    }
  }
  return null;
}

// ─── Payment ──────────────────────────────────────────────────────────────────

PaymentMethod? _findPayment(List<String> rows) {
  final text = rows.join(' ').toLowerCase();
  bool has(String pattern) => RegExp(pattern).hasMatch(text);
  if (has(r'\bupi\b|gpay|google\s*pay|phonepe|paytm|bhim|\bvpa\b')) return PaymentMethod.upi;
  if (has(r'debit\s*card|\bdebit\b|rupay')) return PaymentMethod.debitCard;
  if (has(r'credit\s*card|\bcredit\b|\bvisa\b|master\s*card|\bamex\b|\bcard\b')) return PaymentMethod.creditCard;
  if (has(r'net\s*banking|netbanking|\bneft\b|\bimps\b')) return PaymentMethod.netBanking;
  if (has(r'\bcash\b')) return PaymentMethod.cash;
  return null;
}

// ─── Merchant ─────────────────────────────────────────────────────────────────

final _notAName = RegExp(
    r'invoice|receipt|\bbill\b|gstin|\bgst\b|phone|\bph\b|\bmob|\btel\b|e-?mail|@|www|\.com|\bdate\b|\btime\b|cashier|\border\b|\btable\b|\btoken\b|welcome|thank|fssai|\bcin\b|\bpan\b|original|duplicate|\bcopy\b|customer',
    caseSensitive: false);
final _sellerPrefix = RegExp(r'^\s*(sold\s*by|seller|merchant)\s*[:\-]?\s*', caseSensitive: false);

/// The first line near the top that reads like a name: mostly letters, not a
/// heading like "Tax Invoice", not an address or phone number.
String? _findMerchant(List<String> rows) {
  for (final raw in rows.take(8)) {
    final row = raw.replaceFirst(_sellerPrefix, '').split('  ').first.trim();
    if (row.isEmpty || _notAName.hasMatch(row)) continue;
    final letters = RegExp('[A-Za-z]').allMatches(row).length;
    final digits = RegExp(r'\d').allMatches(row).length;
    if (letters < 3 || digits > letters / 3) continue;
    if (RegExp(r'\b\d{6}\b').hasMatch(row)) continue; // A PIN code: part of the address.
    final name = row.replaceAll(RegExp(r"^[^A-Za-z0-9]+|[^A-Za-z0-9).']+$"), '');
    return name == name.toUpperCase() ? _titleCase(name) : name;
  }
  return null;
}

String _titleCase(String text) => text
    .toLowerCase()
    .split(' ')
    .map((word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
    .join(' ');

// ─── Category ─────────────────────────────────────────────────────────────────

/// Checked in order, so a pharmacy inside a mall counts as Health.
const _categoryWords = [
  ('health', r'pharma|medical|medico|chemist|apollo|medplus|hospital|clinic|diagnostic|\blab\b|netmeds|1mg'),
  ('transport', r'petrol|fuel|filling\s*station|hpcl|bpcl|indian\s*oil|iocl|\bshell\b|uber|\bola\b|rapido|parking|toll|metro|fastag'),
  ('utilities', r'electricity|\bpower\b|broadband|internet|airtel|\bjio\b|vodafone|\bbsnl\b|recharge|\bgas\b|water\s*bill|\bdth\b|tata\s*play'),
  ('groceries', r'super\s*market|supermart|\bmart\b|grocery|groceries|kirana|provision|bigbasket|dmart|reliance\s*fresh|spencer|nature.?s\s*basket|blinkit|zepto|instamart|vegetable|dairy'),
  ('food', r'restaurant|\bcaf[eé]\b|coffee|bakery|bakers|kitchen|dhaba|biryani|pizza|burger|swiggy|zomato|\bfood|eatery|sweets|\bchai\b|\btea\b|\bbar\b|bistro|dosa|idli'),
  ('shopping', r'fashion|apparel|clothing|garment|footwear|lifestyle|trends|\bzara\b|h\s*&\s*m|myntra|amazon|flipkart|electronics|\bmall\b|appario'),
];

String? guessCategory(String text) {
  final lower = text.toLowerCase();
  for (final (id, pattern) in _categoryWords) {
    if (RegExp(pattern).hasMatch(lower)) return id;
  }
  return null;
}
