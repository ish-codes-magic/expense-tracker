import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/data/models.dart';
import 'package:slip/data/slip_database.dart';
import 'package:slip/state/settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/sample_receipts.dart';

/// Runs the real schema and SQL against SQLite on this computer, using a
/// fresh file per test so "close the app and open it again" can be checked.
void main() {
  late Directory dir;
  late String path;

  setUpAll(sqfliteFfiInit);
  setUp(() {
    dir = Directory.systemTemp.createTempSync('slip_db_test');
    path = '${dir.path}/slip.db';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<SlipDatabase> open() => SlipDatabase.open(factory: databaseFactoryFfi, path: path);

  /// Closes and reopens, like quitting and relaunching the app.
  Future<StartupData> reopen(SlipDatabase db) async {
    await db.close();
    final again = await open();
    final data = await again.load();
    await again.close();
    return data;
  }

  final receipt = Receipt(
    id: 'r-1',
    merchant: 'Chai Point',
    categoryId: 'food',
    date: DateTime(2026, 9, 12),
    totalPaise: 52500,
    gstPaise: 2500,
    gstRate: null,
    taxSplit: TaxSplit.igst,
    payment: PaymentMethod.debitCard,
    gstin: '27AAPFU0939F1ZV',
    items: const [
      LineItem(name: 'Masala chai × 2', amountPaise: 30000),
      LineItem(name: 'Samosa', amountPaise: 20000),
    ],
    createdAt: DateTime(2026, 9, 12, 18, 30),
  );

  test('a new database starts empty, with no made-up receipts', () async {
    final db = await open();
    expect((await db.load()).receipts, isEmpty);
    expect((await reopen(db)).receipts, isEmpty);
  });

  test('receipts from an older install that seeded samples can all be removed', () async {
    final db = await open();
    for (final receipt in sampleReceipts()) {
      await db.insertReceipt(receipt);
    }
    await db.deleteReceipts(sampleReceipts());
    expect((await reopen(db)).receipts, isEmpty);
  });

  test('a saved receipt survives a restart with every field intact', () async {
    final db = await open();
    await db.insertReceipt(receipt);
    final saved = (await reopen(db)).receipts.single;

    expect(saved.id, receipt.id);
    expect(saved.merchant, receipt.merchant);
    expect(saved.categoryId, receipt.categoryId);
    expect(saved.date, receipt.date);
    expect(saved.totalPaise, receipt.totalPaise);
    expect(saved.gstPaise, receipt.gstPaise);
    expect(saved.gstRate, isNull);
    expect(saved.taxSplit, TaxSplit.igst);
    expect(saved.payment, PaymentMethod.debitCard);
    expect(saved.gstin, receipt.gstin);
    expect([for (final i in saved.items) (i.name, i.amountPaise)],
        [('Masala chai × 2', 30000), ('Samosa', 20000)]);
    expect(saved.createdAt, receipt.createdAt);
  });

  test('a deleted receipt stays deleted and its photo is removed', () async {
    final photo = File('${dir.path}/receipt.jpg')..writeAsBytesSync([1, 2, 3]);
    final db = await open();
    final withPhoto = Receipt(
      id: receipt.id,
      merchant: receipt.merchant,
      categoryId: receipt.categoryId,
      date: receipt.date,
      totalPaise: receipt.totalPaise,
      gstPaise: receipt.gstPaise,
      gstRate: receipt.gstRate,
      taxSplit: receipt.taxSplit,
      payment: receipt.payment,
      createdAt: receipt.createdAt,
      imagePath: photo.path,
    );
    await db.insertReceipt(withPhoto);
    await db.deleteReceipts([withPhoto]);

    expect(photo.existsSync(), isFalse);
    expect((await reopen(db)).receipts, isEmpty);
  });

  test('this install keeps the same random id across restarts', () async {
    final db = await open();
    final id = await db.deviceId();
    expect(id, matches(RegExp(r'^[0-9a-f-]{36}$')));
    await db.close();
    final again = await open();
    expect(await again.deviceId(), id);
    await again.close();
  });

  test('budgets and settings survive a restart; unset ones use defaults', () async {
    final db = await open();
    final fresh = await db.load();
    expect(fresh.budgets['food'], 600000);
    expect(fresh.settings.showGst, isTrue);

    await db.saveBudgets({...fresh.budgets, 'food': 750000});
    await db.saveSettings(const AppSettings(showGst: false, autoCategorise: false, aiReading: false));
    final later = await reopen(db);

    expect(later.budgets['food'], 750000);
    expect(later.budgets['groceries'], 800000);
    expect(later.settings.showGst, isFalse);
    expect(later.settings.autoCategorise, isFalse);
    expect(later.settings.aiReading, isFalse);
  });
}
