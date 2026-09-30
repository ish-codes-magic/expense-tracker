import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/data/models.dart';
import 'package:slip/services/receipt_capture.dart';

void main() {
  test('launch cleanup deletes only photos no receipt uses', () async {
    final dir = Directory.systemTemp.createTempSync('slip_photos');
    addTearDown(() => dir.deleteSync(recursive: true));
    final kept = File('${dir.path}/kept.jpg')..writeAsBytesSync([1]);
    final orphan = File('${dir.path}/orphan.jpg')..writeAsBytesSync([2]);

    await deleteOrphanPhotos([
      Receipt(
        id: 'r1',
        merchant: 'DMart',
        categoryId: 'groceries',
        date: DateTime(2026, 9, 1),
        totalPaise: 10000,
        gstPaise: 0,
        gstRate: 0,
        taxSplit: TaxSplit.none,
        payment: PaymentMethod.upi,
        createdAt: DateTime(2026, 9, 1),
        imagePath: kept.path,
      ),
    ], dir: dir);

    expect(kept.existsSync(), isTrue);
    expect(orphan.existsSync(), isFalse);
  });
}
