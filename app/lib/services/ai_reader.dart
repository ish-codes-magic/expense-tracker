import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/gst.dart';
import '../core/receipt_parser.dart';
import '../data/models.dart';

/// The receipt reader's address and app token, set at build time with
/// `--dart-define-from-file=secrets.json`. Builds without them (including
/// tests) have no AI reading; the phone reads receipts on its own.
const _readerUrl = String.fromEnvironment('SLIP_READER_URL');
const _readerToken = String.fromEnvironment('SLIP_READER_TOKEN');

bool get aiReaderConfigured => _readerUrl.isNotEmpty && _readerToken.isNotEmpty;

/// Why an AI read didn't happen, in words for the user.
class AiReaderException implements Exception {
  const AiReaderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Sends a receipt photo to Slip's reader (a Cloudflare Worker holding the
/// OpenRouter key), which asks a cheap vision model to read it.
class AiReader {
  AiReader({required this.deviceId, http.Client? client}) : _client = client ?? http.Client();

  /// A random id for this install, so the server can limit each phone.
  final String deviceId;
  final http.Client _client;

  Future<ParsedReceipt> read(String imagePath) async {
    final image = base64Encode(await File(imagePath).readAsBytes());
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_readerUrl/read'),
            headers: {
              'Authorization': 'Bearer $_readerToken',
              'X-Slip-Device': deviceId,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'image': image,
              'mime': 'image/jpeg',
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on SocketException {
      throw const AiReaderException('No internet');
    } on http.ClientException {
      throw const AiReaderException('No internet');
    } on TimeoutException {
      throw const AiReaderException('The AI reader took too long');
    }

    if (response.statusCode != 200) {
      throw AiReaderException(switch (response.statusCode) {
        429 => 'Too many scans in a minute',
        422 => "The AI couldn't read this photo",
        _ => 'The AI reader is unavailable',
      });
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return parsedFromReader(body['receipt'] as Map<String, dynamic>);
  }
}

/// Turns the reader's answer (money in paise, checked by the server) into
/// the same shape the on-device rules produce.
ParsedReceipt parsedFromReader(Map<String, dynamic> r) {
  final total = r['totalPaise'] as int?;
  final cgst = r['cgstPaise'] as int?;
  final sgst = r['sgstPaise'] as int?;
  final igst = r['igstPaise'] as int?;

  int? gst;
  var split = TaxSplit.none;
  if ((cgst ?? 0) > 0 || (sgst ?? 0) > 0) {
    // A bill that prints only one half still implies the other.
    gst = (cgst ?? 0) > 0 && (sgst ?? 0) > 0 ? cgst! + sgst! : 2 * ((cgst ?? 0) + (sgst ?? 0));
    split = TaxSplit.cgstSgst;
  } else if ((igst ?? 0) > 0) {
    gst = igst;
    split = TaxSplit.igst;
  }

  final date = r['date'] is String ? DateTime.tryParse(r['date'] as String) : null;

  return ParsedReceipt(
    merchant: r['merchant'] as String?,
    date: date == null ? null : DateTime(date.year, date.month, date.day),
    totalPaise: total,
    gstPaise: gst,
    gstRate: r['gstRate'] as int? ?? (total != null && gst != null ? inferGstRate(total, gst) : null),
    taxSplit: split,
    gstin: r['gstin'] as String?,
    payment: switch (r['payment']) {
      'upi' => PaymentMethod.upi,
      'credit_card' => PaymentMethod.creditCard,
      'debit_card' => PaymentMethod.debitCard,
      'cash' => PaymentMethod.cash,
      'net_banking' => PaymentMethod.netBanking,
      'other' => PaymentMethod.other,
      _ => null,
    },
    categoryId: r['category'] as String?,
    items: [
      for (final item in (r['items'] as List<dynamic>? ?? const []))
        LineItem(name: item['name'] as String, amountPaise: item['amountPaise'] as int),
    ],
  );
}
