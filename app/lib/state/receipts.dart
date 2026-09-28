import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/sample_data.dart';
import 'database.dart';

final receiptsProvider = NotifierProvider<ReceiptsNotifier, List<Receipt>>(ReceiptsNotifier.new);

/// Newest first. Every change is written to the phone first; the list on
/// screen only changes once the write has succeeded, so what you see is
/// always what's stored.
class ReceiptsNotifier extends Notifier<List<Receipt>> {
  @override
  List<Receipt> build() => _sorted(ref.read(startupDataProvider).receipts);

  Future<void> add(Receipt receipt) async {
    await ref.read(slipDatabaseProvider).insertReceipt(receipt);
    state = _sorted([...state, receipt]);
  }

  Future<void> remove(String id) => _removeWhere((r) => r.id == id);

  Future<void> clear() => _removeWhere((_) => true);

  Future<void> removeSamples() => _removeWhere(isSampleReceipt);

  Future<void> _removeWhere(bool Function(Receipt) test) async {
    final doomed = state.where(test).toList();
    if (doomed.isEmpty) return;
    await ref.read(slipDatabaseProvider).deleteReceipts(doomed);
    state = state.where((r) => !test(r)).toList();
  }

  static List<Receipt> _sorted(List<Receipt> receipts) => [...receipts]
    ..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
}

final receiptByIdProvider = Provider.family<Receipt?, String>((ref, id) {
  for (final r in ref.watch(receiptsProvider)) {
    if (r.id == id) return r;
  }
  return null;
});
