import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../core/gst.dart';
import '../state/settings.dart';
import 'categories.dart';
import 'models.dart';
import 'sample_data.dart';

/// Everything the app needs on launch, loaded once in main() so every screen
/// can read it straight away.
typedef StartupData = ({
  List<Receipt> receipts,
  Map<String, int> budgets,
  AppSettings settings,
});

/// The app's one SQLite file on the phone: receipts, budgets and settings.
///
/// Money is stored in whole paise and dates as yyyy-mm-dd text. Every receipt
/// has a random id plus created/updated times, and deletions leave a
/// tombstone, so a cloud sync can be added later without reshaping the data.
class SlipDatabase {
  SlipDatabase._(this._db);

  final Database _db;

  static const _schemaVersion = 1;

  /// Opens (or on first launch, creates) the database. A new database starts
  /// with the sample receipts so the screens have something to show.
  static Future<SlipDatabase> open({
    DatabaseFactory? factory,
    String? path,
    bool seedSamples = true,
  }) async {
    factory ??= databaseFactory;
    path ??= '${await factory.getDatabasesPath()}/slip.db';
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: (db, version) async {
          await _createTables(db);
          if (seedSamples) {
            final batch = db.batch();
            for (final receipt in sampleReceipts()) {
              batch.insert('receipts', _receiptRow(receipt));
            }
            await batch.commit(noResult: true);
          }
        },
      ),
    );
    return SlipDatabase._(db);
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE receipts (
        id           TEXT PRIMARY KEY,
        merchant     TEXT NOT NULL,
        category_id  TEXT NOT NULL,
        date         TEXT NOT NULL,     -- yyyy-mm-dd, the date printed on the bill
        total_paise  INTEGER NOT NULL,
        gst_paise    INTEGER NOT NULL,
        gst_rate     INTEGER,           -- NULL when the bill mixes rates
        tax_split    TEXT NOT NULL,     -- none | cgstSgst | igst
        payment      TEXT NOT NULL,
        gstin        TEXT,
        items_json   TEXT NOT NULL,     -- line items as a JSON list
        image_path   TEXT,
        created_at   INTEGER NOT NULL,  -- milliseconds since 1970, UTC
        updated_at   INTEGER NOT NULL
      )''');
    await db.execute('CREATE INDEX receipts_by_date ON receipts (date)');
    // Only the id and time of a deleted receipt; the receipt itself is erased.
    await db.execute('''
      CREATE TABLE deleted_receipts (
        id          TEXT PRIMARY KEY,
        deleted_at  INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE budgets (
        category_id  TEXT PRIMARY KEY,
        limit_paise  INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE settings (
        key    TEXT PRIMARY KEY,
        value  TEXT NOT NULL
      )''');
  }

  Future<StartupData> load() async {
    final receiptRows = await _db.query('receipts', orderBy: 'date DESC, created_at DESC');
    final budgetRows = await _db.query('budgets');
    final settingRows = await _db.query('settings');

    final storedBudgets = {
      for (final row in budgetRows) row['category_id'] as String: row['limit_paise'] as int,
    };
    final values = {for (final row in settingRows) row['key'] as String: row['value'] as String};
    const defaults = AppSettings();
    bool flag(String key, bool fallback) => values[key] == null ? fallback : values[key] == '1';

    return (
      receipts: [for (final row in receiptRows) _receiptFromRow(row)],
      // Categories added in a later version start at their default limit.
      budgets: {for (final c in categories) c.id: storedBudgets[c.id] ?? c.defaultLimitPaise},
      settings: AppSettings(
        showGst: flag('show_gst', defaults.showGst),
        autoCategorise: flag('auto_categorise', defaults.autoCategorise),
        appLock: flag('app_lock', defaults.appLock),
      ),
    );
  }

  Future<void> insertReceipt(Receipt receipt) =>
      _db.insert('receipts', _receiptRow(receipt), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> deleteReceipts(Iterable<Receipt> receipts) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction((txn) async {
      for (final receipt in receipts) {
        await txn.delete('receipts', where: 'id = ?', whereArgs: [receipt.id]);
        await txn.insert('deleted_receipts', {'id': receipt.id, 'deleted_at': now},
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    // Photos go too once their rows are gone. A photo that fails to delete
    // is only wasted space, so it doesn't undo the deletion.
    for (final receipt in receipts) {
      final path = receipt.imagePath;
      if (path == null) continue;
      try {
        await File(path).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  Future<void> saveBudgets(Map<String, int> limits) => _db.transaction((txn) async {
        for (final MapEntry(key: categoryId, value: limit) in limits.entries) {
          await txn.insert('budgets', {'category_id': categoryId, 'limit_paise': limit},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

  Future<void> saveSettings(AppSettings settings) => _db.transaction((txn) async {
        final values = {
          'show_gst': settings.showGst,
          'auto_categorise': settings.autoCategorise,
          'app_lock': settings.appLock,
        };
        for (final MapEntry(:key, :value) in values.entries) {
          await txn.insert('settings', {'key': key, 'value': value ? '1' : '0'},
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });

  Future<void> close() => _db.close();

  static Map<String, Object?> _receiptRow(Receipt r) => {
        'id': r.id,
        'merchant': r.merchant,
        'category_id': r.categoryId,
        'date': _dateText(r.date),
        'total_paise': r.totalPaise,
        'gst_paise': r.gstPaise,
        'gst_rate': r.gstRate,
        'tax_split': r.taxSplit.name,
        'payment': r.payment.name,
        'gstin': r.gstin,
        'items_json': jsonEncode([
          for (final item in r.items) {'name': item.name, 'amount_paise': item.amountPaise},
        ]),
        'image_path': r.imagePath,
        'created_at': r.createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      };

  static Receipt _receiptFromRow(Map<String, Object?> row) => Receipt(
        id: row['id'] as String,
        merchant: row['merchant'] as String,
        categoryId: row['category_id'] as String,
        date: DateTime.parse(row['date'] as String),
        totalPaise: row['total_paise'] as int,
        gstPaise: row['gst_paise'] as int,
        gstRate: row['gst_rate'] as int?,
        taxSplit: _byName(TaxSplit.values, row['tax_split'] as String, TaxSplit.none),
        payment: _byName(PaymentMethod.values, row['payment'] as String, PaymentMethod.other),
        gstin: row['gstin'] as String?,
        items: [
          for (final item in jsonDecode(row['items_json'] as String) as List<dynamic>)
            LineItem(name: item['name'] as String, amountPaise: item['amount_paise'] as int),
        ],
        imagePath: row['image_path'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int, isUtc: true).toLocal(),
      );

  /// An unknown stored name (say, from a newer app version) falls back
  /// instead of crashing the app on launch.
  static T _byName<T extends Enum>(List<T> values, String name, T fallback) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }

  static String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
