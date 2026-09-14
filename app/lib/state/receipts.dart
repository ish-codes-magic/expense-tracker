import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models.dart';
import '../data/sample_data.dart';

final receiptsProvider = NotifierProvider<ReceiptsNotifier, List<Receipt>>(ReceiptsNotifier.new);

/// Newest first. Held in memory for now; the local database replaces this.
class ReceiptsNotifier extends Notifier<List<Receipt>> {
  @override
  List<Receipt> build() => _sorted(sampleReceipts());

  void add(Receipt receipt) => state = _sorted([...state, receipt]);

  void remove(String id) => state = state.where((r) => r.id != id).toList();

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
