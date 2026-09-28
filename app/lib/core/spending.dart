import '../data/models.dart';
import 'format.dart';

Iterable<Receipt> inMonth(Iterable<Receipt> receipts, DateTime month) =>
    receipts.where((r) => sameMonth(r.date, month));

Iterable<Receipt> sinceDate(Iterable<Receipt> receipts, DateTime start) =>
    receipts.where((r) => !r.date.isBefore(start));

int totalOf(Iterable<Receipt> receipts) => receipts.fold(0, (sum, r) => sum + r.totalPaise);

int gstOf(Iterable<Receipt> receipts) => receipts.fold(0, (sum, r) => sum + r.gstPaise);

Map<String, int> spendByCategory(Iterable<Receipt> receipts) {
  final totals = <String, int>{};
  for (final r in receipts) {
    totals[r.categoryId] = (totals[r.categoryId] ?? 0) + r.totalPaise;
  }
  return totals;
}

/// A budget counts as near its limit from 90% spent; a zero limit means "no budget".
bool isNearLimit(int spentPaise, int limitPaise) => limitPaise > 0 && spentPaise >= limitPaise * 0.9;

/// The category of the newest receipt from the same merchant (ignoring case
/// and surrounding spaces), for auto-categorising. [receipts] is newest first.
String? lastCategoryFor(Iterable<Receipt> receipts, String merchant) {
  final key = merchant.trim().toLowerCase();
  if (key.isEmpty) return null;
  for (final r in receipts) {
    if (r.merchant.trim().toLowerCase() == key) return r.categoryId;
  }
  return null;
}
