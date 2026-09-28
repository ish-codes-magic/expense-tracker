import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/gst_export.dart';
import '../data/models.dart';

/// Writes [receipts] to a CSV in the app's temporary folder and opens
/// Android's share sheet, so it can go to Drive, email, WhatsApp or Files.
Future<void> shareReceiptsCsv(
  List<Receipt> receipts, {
  required String fileName,
  required String subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  // A leading byte-order mark tells Excel the file is UTF-8, so ₹ and
  // non-English merchant names survive.
  await file.writeAsString(String.fromCharCode(0xFEFF) + receiptsCsv(receipts));
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/csv')],
    subject: subject,
    title: subject,
  ));
}
