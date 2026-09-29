import 'package:flutter_test/flutter_test.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/core/receipt_parser.dart';
import 'package:slip/data/models.dart';

/// Receipt text as it comes out of text recognition, one printed row per line
/// (labels and amounts joined by two spaces), including typical misreads.
List<String> rows(String text) =>
    text.trim().split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();

void main() {
  final today = DateTime(2026, 9, 29);

  test('a café bill with CGST and SGST', () {
    final parsed = parseReceiptText(rows('''
      THIRD WAVE COFFEE ROASTERS
      80 Feet Road, Koramangala, Bengaluru 560034
      GSTIN: 29AAECT4478M1ZK
      TAX INVOICE
      Bill No: 4412  Date: 12/09/2026  Time: 10:42
      Cappuccino x2  340.00
      Almond Croissant  160.00
      Sub Total  500.00
      CGST @2.5%  12.50
      SGST @2.5%  12.50
      Grand Total  525.00
      Paid via UPI
      Thank you, visit again!
    '''), today: today);

    expect(parsed.merchant, 'Third Wave Coffee Roasters');
    expect(parsed.date, DateTime(2026, 9, 12));
    expect(parsed.totalPaise, 52500);
    expect(parsed.gstPaise, 2500);
    expect(parsed.gstRate, 5);
    expect(parsed.taxSplit, TaxSplit.cgstSgst);
    expect(parsed.gstin, '29AAECT4478M1ZK');
    expect(parsed.payment, PaymentMethod.upi);
    expect(parsed.categoryId, 'food');
  });

  test('a supermarket bill with misreads, mixed rates and cash handed over', () {
    final parsed = parseReceiptText(rows('''
      AVENUE SUPERMARTS LTD
      Ph: 022-33400500
      GSTIN 27AAPFUO939F1ZV
      Invoice Dt: 05-Sep-26
      Atta 5kg  245.00
      Detergent  390.00
      Total Qty: 7
      Total Savings  64.00
      CGST 2.5%  30.00
      SGST 2.5%  30.00
      CGST 9%  45.00
      SGST 9%  45.00
      Net Amount  Rs. 1,745.00
      Cash  2,000.00
      Change  255.00
    '''), today: today);

    expect(parsed.merchant, 'Avenue Supermarts Ltd');
    expect(parsed.date, DateTime(2026, 9, 5));
    expect(parsed.totalPaise, 174500, reason: 'Net Amount, not the cash handed over');
    expect(parsed.gstPaise, 15000);
    expect(parsed.gstRate, isNull, reason: 'a bill mixing 5% and 18% has no single rate');
    expect(parsed.gstin, '27AAPFU0939F1ZV', reason: 'the O misread as 0 is corrected');
    expect(parsed.payment, PaymentMethod.cash);
    expect(parsed.categoryId, 'groceries');
  });

  test('an online invoice with IGST from another state', () {
    final parsed = parseReceiptText(rows('''
      Tax Invoice/Bill of Supply
      Sold By: Appario Retail Private Ltd
      GSTIN: 27AAACR5055K1Z7
      Invoice Date: 2026-09-02
      Wireless Headphones  4,228.81
      IGST 18%  761.19
      Invoice Total  ₹4,990.00
      Payment: Credit Card
    '''), today: today);

    expect(parsed.merchant, 'Appario Retail Private Ltd');
    expect(parsed.date, DateTime(2026, 9, 2));
    expect(parsed.totalPaise, 499000);
    expect(parsed.gstPaise, 76119);
    expect(parsed.gstRate, 18);
    expect(parsed.taxSplit, TaxSplit.igst);
    expect(parsed.payment, PaymentMethod.creditCard);
    expect(parsed.categoryId, 'shopping');
  });

  test('a total that mentions tax is still the total; an unprinted rate is worked out', () {
    final parsed = parseReceiptText(rows('''
      Apollo Pharmacy
      Paracetamol 650  30.00
      Total (incl. of all taxes)  1,120.00
      GST Amount  53.33
    '''), today: today);

    expect(parsed.totalPaise, 112000);
    expect(parsed.gstPaise, 5333);
    expect(parsed.gstRate, 5);
    expect(parsed.categoryId, 'health');
  });

  test('nothing believable is invented', () {
    final parsed = parseReceiptText(rows('''
      ~ .:, ~
      Il |
      Date: 31/09/2026
      Due 12/12/2031
    '''), today: today);

    expect(parsed.merchant, isNull);
    expect(parsed.date, isNull, reason: '31 September does not exist; 2031 is in the future');
    expect(parsed.totalPaise, isNull);
    expect(parsed.gstPaise, isNull);
    expect(parsed.gstin, isNull);
    expect(parsed.payment, isNull);
  });

  test('amounts ignore percentages, quantities and GSTINs', () {
    expect(amountsIn('Cappuccino x2  340.00'), [34000]);
    expect(amountsIn('CGST @2.5% on 500.00  12.50'), [50000, 1250]);
    expect(amountsIn('GSTIN 29AABCS1234F1ZP'), isEmpty);
    expect(amountsIn('Total Rs.1,23,456.50'), [12345650]);
  });

  test('pieces on the same printed row are joined left to right', () {
    expect(
      groupIntoRows([
        (text: '525.00', top: 100, bottom: 120, left: 300),
        (text: 'Grand Total', top: 102, bottom: 121, left: 10),
        (text: 'Paid via UPI', top: 140, bottom: 160, left: 10),
      ]),
      ['Grand Total  525.00', 'Paid via UPI'],
    );
  });
}
