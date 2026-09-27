import 'package:flutter_test/flutter_test.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/core/gst_export.dart';
import 'package:slip/data/models.dart';

Receipt _receipt({
  String merchant = 'Blue Tokai',
  int total = 64000,
  int gst = 3048,
  int? rate = 5,
  TaxSplit split = TaxSplit.cgstSgst,
}) =>
    Receipt(
      id: 'r1',
      merchant: merchant,
      categoryId: 'food',
      date: DateTime(2026, 9, 5),
      totalPaise: total,
      gstPaise: gst,
      gstRate: rate,
      taxSplit: split,
      payment: PaymentMethod.upi,
      createdAt: DateTime(2026, 9, 5),
    );

void main() {
  group('isValidGstin', () {
    test('accepts real GSTINs', () {
      expect(isValidGstin('27AAPFU0939F1ZV'), isTrue);
      expect(isValidGstin('27AAACR5055K1Z7'), isTrue);
      expect(isValidGstin(' 27aapfu0939f1zv '), isTrue, reason: 'trims and ignores case');
    });

    test('rejects a single misread character', () {
      expect(isValidGstin('27AAPFU0939F1ZW'), isFalse);
      expect(isValidGstin('27AAPFU0989F1ZV'), isFalse);
    });

    test('rejects the wrong shape', () {
      expect(isValidGstin(''), isFalse);
      expect(isValidGstin('27AAPFU0939F1V'), isFalse);
    });
  });

  test('gstInclusive extracts the tax from a tax-inclusive total', () {
    expect(gstInclusive(52500, 5), 2500);
    expect(gstInclusive(11800, 18), 1800);
    expect(gstInclusive(10000, 0), 0);
  });

  group('gstComponents', () {
    test('splits same-state GST in half, odd paisa to SGST', () {
      final parts = gstComponents(_receipt(gst: 3049));
      expect(parts.cgst, 1524);
      expect(parts.sgst, 1525);
      expect(parts.igst, 0);
    });

    test('puts inter-state GST in IGST', () {
      final parts = gstComponents(_receipt(split: TaxSplit.igst));
      expect(parts, (cgst: 0, sgst: 0, igst: 3048));
    });
  });

  test('gstCsv writes a header, rupee amounts and quotes awkward names', () {
    final lines = gstCsv([_receipt(merchant: 'Chai, "Point"')]).split('\r\n');
    expect(lines, hasLength(2));
    expect(lines[0], startsWith('Date,Merchant,GSTIN'));
    expect(lines[1],
        '2026-09-05,"Chai, ""Point""",,Food & drink,UPI,5%,609.52,15.24,15.24,0.00,30.48,640.00');
  });
}
