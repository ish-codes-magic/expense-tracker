import 'package:flutter_test/flutter_test.dart';
import 'package:slip/core/format.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/core/spending.dart';
import 'package:slip/data/models.dart';
import 'package:slip/state/draft.dart';

ReceiptDraft _draft({
  String merchant = 'Third Wave Coffee',
  DateTime? date,
  int? total = 52500,
  int? gst = 2500,
  int? rate = 5,
  String gstin = '29AAECT4478M1ZK',
}) =>
    ReceiptDraft(
      merchant: merchant,
      date: date ?? DateTime(2026, 9, 12),
      payment: PaymentMethod.upi,
      totalPaise: total,
      gstPaise: gst,
      gstRate: rate,
      taxSplit: TaxSplit.cgstSgst,
      categoryId: 'food',
      gstin: gstin,
    );

Receipt _receipt(String id, String merchant, String categoryId) => Receipt(
      id: id,
      merchant: merchant,
      categoryId: categoryId,
      date: DateTime(2026, 9, 1),
      totalPaise: 10000,
      gstPaise: 0,
      gstRate: 0,
      taxSplit: TaxSplit.none,
      payment: PaymentMethod.cash,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  final today = DateTime(2026, 9, 29);

  group('fieldsToCheck', () {
    test('a consistent receipt passes every check', () {
      expect(fieldsToCheck(_draft(), today: today), isEmpty);
      expect(fieldsToCheck(demoDraft(), today: dateOnly(DateTime.now())), isEmpty,
          reason: 'the sample shown before real scanning must not look broken');
    });

    test('flags a missing merchant and a missing total', () {
      expect(fieldsToCheck(_draft(merchant: '  '), today: today), {DraftField.merchant});
      expect(fieldsToCheck(_draft(total: null), today: today), {DraftField.total});
    });

    test('flags a date in the future', () {
      expect(fieldsToCheck(_draft(date: DateTime(2026, 9, 30)), today: today), {DraftField.date});
    });

    test('flags GST that does not match the rate, allowing ₹1 of rounding', () {
      expect(fieldsToCheck(_draft(gst: 3000), today: today), {DraftField.gst});
      expect(fieldsToCheck(_draft(gst: 2580), today: today), isEmpty);
      expect(fieldsToCheck(_draft(gst: 52500), today: today), {DraftField.gst},
          reason: 'GST can never be the whole bill');
    });

    test('flags a misread GSTIN but not a missing one', () {
      expect(fieldsToCheck(_draft(gstin: '29AAECT4478M1ZB'), today: today), {DraftField.gstin});
      expect(fieldsToCheck(_draft(gstin: ''), today: today), isEmpty);
    });
  });

  group('lastCategoryFor', () {
    final receipts = [
      _receipt('new', 'Blue Tokai', 'groceries'),
      _receipt('old', 'Blue Tokai', 'food'),
    ];

    test('uses the newest matching receipt, ignoring case and spaces', () {
      expect(lastCategoryFor(receipts, '  blue tokai '), 'groceries');
    });

    test('returns nothing for unknown or blank merchants', () {
      expect(lastCategoryFor(receipts, 'Chaayos'), isNull);
      expect(lastCategoryFor(receipts, ''), isNull);
    });
  });
}
