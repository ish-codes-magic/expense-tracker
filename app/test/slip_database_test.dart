import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/data/models.dart';
import 'package:slip/data/sample_data.dart';
import 'package:slip/data/slip_database.dart';
import 'package:slip/state/settings.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  Future<SlipDatabase> open({bool seed = false}) =>
      SlipDatabase.open(factory: databaseFactoryFfi, path: path, seedSamples: seed);

  /// Closes and reopens, like quitting and relaunching the app.
  Future<StartupData> reopen(SlipDatabase db) async {
    await db.close();
    final again = await open(seed: true);
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

  test('a new database starts with the sample receipts, once', () async {
    final db = await open(seed: true);
    final first = await db.load();
    expect(first.receipts, hasLength(sampleReceipts().length));
    expect(first.receipts.every(isSampleReceipt), isTrue);

    await db.deleteReceipts(first.receipts);
    final later = await reopen(db);
    expect(later.receipts, isEmpty, reason: 'samples must not come back after being removed');
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

  test('budgets and settings survive a restart; unset ones use defaults', () async {
    final db = await open();
    final fresh = await db.load();
    expect(fresh.budgets['food'], 600000);
    expect(fresh.settings.showGst, isTrue);

    await db.saveBudgets({...fresh.budgets, 'food': 750000});
    await db.saveSettings(const AppSettings(showGst: false, autoCategorise: false));
    final later = await reopen(db);

    expect(later.budgets['food'], 750000);
    expect(later.budgets['groceries'], 800000);
    expect(later.settings.showGst, isFalse);
    expect(later.settings.autoCategorise, isFalse);
  });
}
