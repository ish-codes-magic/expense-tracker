/// How GST appears on a bill: none, split into CGST + SGST (same state),
/// or a single IGST line (seller in another state).
enum TaxSplit { none, cgstSgst, igst }

/// Slabs after the September 2025 GST reform. Older bills may still show
/// 12% or 28%; those are accepted but not offered as quick picks.
const standardGstRates = [0, 5, 18, 40];

/// GST contained in a tax-inclusive total.
int gstInclusive(int totalPaise, int ratePercent) {
  if (ratePercent <= 0) return 0;
  return totalPaise - (totalPaise * 100 / (100 + ratePercent)).round();
}

/// The rate whose GST, on this tax-inclusive total, matches [gstPaise] to
/// within ₹1, checking current slabs before the older 12% and 28%. Null when
/// none fit, e.g. a bill mixing several rates.
int? inferGstRate(int totalPaise, int gstPaise) {
  if (gstPaise == 0) return 0;
  for (final rate in [...standardGstRates.where((r) => r > 0), 12, 28]) {
    if ((gstInclusive(totalPaise, rate) - gstPaise).abs() <= 100) return rate;
  }
  return null;
}

final _gstinPattern = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$');
const _gstinChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';

/// Checks the GSTIN layout and its mod-36 check character, which catches
/// most single-character misreads.
bool isValidGstin(String input) {
  final gstin = input.trim().toUpperCase();
  if (!_gstinPattern.hasMatch(gstin)) return false;
  var sum = 0;
  for (var i = 0; i < 14; i++) {
    final product = _gstinChars.indexOf(gstin[i]) * (i.isOdd ? 2 : 1);
    sum += product ~/ 36 + product % 36;
  }
  return gstin[14] == _gstinChars[(36 - sum % 36) % 36];
}
