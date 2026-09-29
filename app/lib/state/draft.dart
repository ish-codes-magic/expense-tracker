import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/gst.dart';
import '../data/models.dart';

/// What extraction produced, before the user confirms it.
class ReceiptDraft {
  const ReceiptDraft({
    required this.merchant,
    required this.date,
    required this.payment,
    required this.totalPaise,
    required this.gstPaise,
    required this.gstRate,
    required this.taxSplit,
    required this.categoryId,
    this.gstin = '',
    this.items = const [],
    this.imagePath,
    this.source = DraftSource.phone,
  });

  /// A photo waiting for the details to be typed in by hand.
  ReceiptDraft.blank({required String this.imagePath})
      : merchant = '',
        date = dateOnly(DateTime.now()),
        payment = PaymentMethod.upi,
        totalPaise = null,
        gstPaise = null,
        gstRate = null,
        taxSplit = TaxSplit.none,
        categoryId = 'food',
        gstin = '',
        items = const [],
        source = DraftSource.manual;

  final String merchant;
  final DateTime date;
  final PaymentMethod payment;
  final int? totalPaise;
  final int? gstPaise;
  final int? gstRate;
  final TaxSplit taxSplit;
  final String categoryId;
  final String gstin;
  final List<LineItem> items;
  final String? imagePath;

  final DraftSource source;

  /// Whether the values were read from the receipt (and so worth checking)
  /// rather than left for the user to type.
  bool get extracted => source != DraftSource.manual;
}

/// Who filled in a draft: nobody yet, the on-device reader, or the AI.
enum DraftSource { manual, phone, ai }

enum DraftField { merchant, date, total, gst, gstin }

/// Free on-device checks that decide which fields get a "check" mark.
Set<DraftField> fieldsToCheck(ReceiptDraft d, {required DateTime today}) {
  final flagged = <DraftField>{};
  if (d.merchant.trim().isEmpty) flagged.add(DraftField.merchant);
  if (dateOnly(d.date).isAfter(today)) flagged.add(DraftField.date);

  final total = d.totalPaise;
  final gst = d.gstPaise ?? 0;
  if (total == null || total <= 0) {
    flagged.add(DraftField.total);
  } else if (gst < 0 || gst >= total) {
    flagged.add(DraftField.gst);
  } else if (d.gstRate != null) {
    // Allow ₹1 of rounding between the printed GST and the rate.
    if ((gstInclusive(total, d.gstRate!) - gst).abs() > 100) flagged.add(DraftField.gst);
  }

  if (d.gstin.trim().isNotEmpty && !isValidGstin(d.gstin)) flagged.add(DraftField.gstin);
  return flagged;
}

/// Stand-in extraction result until the real reader is connected.
ReceiptDraft demoDraft() => ReceiptDraft(
      merchant: 'Third Wave Coffee',
      date: dateOnly(DateTime.now()),
      payment: PaymentMethod.upi,
      totalPaise: 52500,
      gstPaise: 2500,
      gstRate: 5,
      taxSplit: TaxSplit.cgstSgst,
      categoryId: 'food',
      gstin: '29AAECT4478M1ZK',
      items: const [
        LineItem(name: 'Cappuccino × 2', amountPaise: 34000),
        LineItem(name: 'Almond croissant', amountPaise: 16000),
      ],
    );

final draftProvider = NotifierProvider<DraftNotifier, ReceiptDraft?>(DraftNotifier.new);

class DraftNotifier extends Notifier<ReceiptDraft?> {
  @override
  ReceiptDraft? build() => null;

  void set(ReceiptDraft draft) => state = draft;
  void clear() => state = null;
}
