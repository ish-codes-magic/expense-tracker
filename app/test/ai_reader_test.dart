import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/core/receipt_parser.dart';
import 'package:slip/data/models.dart';
import 'package:slip/services/ai_reader.dart';

void main() {
  group('parsedFromReader', () {
    test('CGST and SGST become one GST amount with the split kept', () {
      final parsed = parsedFromReader({
        'merchant': 'Third Wave Coffee',
        'date': '2026-09-12',
        'totalPaise': 52500,
        'cgstPaise': 1250,
        'sgstPaise': 1250,
        'igstPaise': null,
        'gstRate': 5,
        'gstin': '29AAECT4478M1ZK',
        'payment': 'upi',
        'category': 'food',
        'items': [
          {'name': 'Cappuccino x2', 'amountPaise': 34000},
        ],
      });
      expect(parsed.gstPaise, 2500);
      expect(parsed.taxSplit, TaxSplit.cgstSgst);
      expect(parsed.date, DateTime(2026, 9, 12));
      expect(parsed.payment, PaymentMethod.upi);
      expect(parsed.items.single.amountPaise, 34000);
    });

    test('IGST keeps its split, and a missing rate is worked out', () {
      final parsed = parsedFromReader({'totalPaise': 499000, 'igstPaise': 76119, 'payment': 'credit_card'});
      expect(parsed.gstPaise, 76119);
      expect(parsed.taxSplit, TaxSplit.igst);
      expect(parsed.gstRate, 18);
      expect(parsed.payment, PaymentMethod.creditCard);
    });
  });

  test('the AI reading comes first; the phone fills its gaps, amounts as a set', () {
    const ai = ParsedReceipt(merchant: 'Third Wave Coffee', gstin: '29AAECT4478M1ZB');
    final phone = ParsedReceipt(
      merchant: 'THIRD WAVE',
      date: DateTime(2026, 9, 12),
      totalPaise: 52500,
      gstPaise: 2500,
      gstRate: 5,
      taxSplit: TaxSplit.cgstSgst,
      gstin: '29AAECT4478M1ZK',
      payment: PaymentMethod.upi,
    );
    final merged = ai.filledFrom(phone);
    expect(merged.merchant, 'Third Wave Coffee');
    expect(merged.date, DateTime(2026, 9, 12));
    expect(merged.totalPaise, 52500);
    expect(merged.gstPaise, 2500, reason: 'GST comes with the total it belongs to');
    expect(merged.gstin, '29AAECT4478M1ZK', reason: 'the GSTIN that passes its check digit wins');
  });

  group('AiReader', () {
    late File photo;

    setUp(() {
      final dir = Directory.systemTemp.createTempSync('slip_ai');
      addTearDown(() => dir.deleteSync(recursive: true));
      photo = File('${dir.path}/r.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    });

    AiReader readerReplying(int status, Object body, {void Function(http.Request)? onRequest}) => AiReader(
          deviceId: '123e4567-e89b-42d3-a456-426614174000',
          client: MockClient((request) async {
            onRequest?.call(request);
            return http.Response(jsonEncode(body), status);
          }),
        );

    test('sends the photo and this phone\'s id, and reads the answer', () async {
      late http.Request sent;
      final reader = readerReplying(200, {
        'receipt': {'merchant': 'DMart', 'totalPaise': 174500},
      }, onRequest: (request) => sent = request);

      final parsed = await reader.read(photo.path);

      expect(parsed.merchant, 'DMart');
      expect(sent.headers['X-Slip-Device'], '123e4567-e89b-42d3-a456-426614174000');
      expect(jsonDecode(sent.body)['image'], base64Encode([0xFF, 0xD8, 0xFF]));
    });

    test('server refusals become plain-language reasons', () async {
      expect(
        () => readerReplying(429, {'error': 'rate_limited'}).read(photo.path),
        throwsA(isA<AiReaderException>().having((e) => e.message, 'message', 'Too many scans in a minute')),
      );
      expect(
        () => readerReplying(502, {'error': 'reader_failed'}).read(photo.path),
        throwsA(isA<AiReaderException>().having((e) => e.message, 'message', 'The AI reader is unavailable')),
      );
    });
  });
}
