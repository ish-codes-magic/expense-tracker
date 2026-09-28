import '../data/categories.dart';
import '../data/models.dart';
import 'gst.dart';

/// How a receipt's GST divides into CGST, SGST and IGST, in paise.
/// On a same-state bill CGST and SGST are each half; an odd paisa goes to SGST.
({int cgst, int sgst, int igst}) gstComponents(Receipt receipt) => switch (receipt.taxSplit) {
      TaxSplit.none => (cgst: 0, sgst: 0, igst: 0),
      TaxSplit.cgstSgst => (
          cgst: receipt.gstPaise ~/ 2,
          sgst: receipt.gstPaise - receipt.gstPaise ~/ 2,
          igst: 0,
        ),
      TaxSplit.igst => (cgst: 0, sgst: 0, igst: receipt.gstPaise),
    };

String gstRateLabel(int? rate) => rate == null ? 'Mixed' : '$rate%';

/// One row per receipt, amounts in rupees with two decimals, dates as
/// yyyy-mm-dd so spreadsheets sort them correctly.
String receiptsCsv(Iterable<Receipt> receipts) {
  final rows = <List<String>>[
    ['Date', 'Merchant', 'GSTIN', 'Category', 'Paid via', 'GST rate',
     'Before tax', 'CGST', 'SGST', 'IGST', 'GST', 'Total'],
    for (final r in receipts)
      [
        _isoDate(r.date),
        r.merchant,
        r.gstin ?? '',
        categoryById(r.categoryId).name,
        r.payment.label,
        gstRateLabel(r.gstRate),
        _rupees(r.preTaxPaise),
        _rupees(gstComponents(r).cgst),
        _rupees(gstComponents(r).sgst),
        _rupees(gstComponents(r).igst),
        _rupees(r.gstPaise),
        _rupees(r.totalPaise),
      ],
  ];
  return rows.map((row) => row.map(_csvField).join(',')).join('\r\n');
}

String _rupees(int paise) => (paise / 100).toStringAsFixed(2);

String _isoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _csvField(String value) =>
    value.contains(RegExp(r'[",\r\n]')) ? '"${value.replaceAll('"', '""')}"' : value;
