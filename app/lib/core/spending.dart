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
