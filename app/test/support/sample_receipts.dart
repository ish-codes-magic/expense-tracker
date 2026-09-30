import 'package:slip/core/format.dart';
import 'package:slip/core/gst.dart';
import 'package:slip/data/models.dart';

/// The design's demo receipts, dated relative to today, for tests that need
/// realistic data. Ids start with "sample-" like the ones early installs got.
List<Receipt> sampleReceipts() {
  final today = dateOnly(DateTime.now());

  Receipt receipt(String id, String merchant, String categoryId, DateTime date, int rupees,
      int rate, String? gstin, PaymentMethod payment) {
    final total = rupees * 100;
    return Receipt(
      id: id,
      merchant: merchant,
      categoryId: categoryId,
      date: date,
      totalPaise: total,
      gstPaise: gstInclusive(total, rate),
      gstRate: rate,
      taxSplit: rate == 0 ? TaxSplit.none : TaxSplit.cgstSgst,
      gstin: gstin,
      payment: payment,
      createdAt: date,
    );
  }

  DateTime daysAgo(int n) => today.subtract(Duration(days: n));

  final list = [
    receipt('sample-1', 'Blue Tokai Coffee Roasters', 'food', daysAgo(2), 640, 5, '07AAECB4321K1Z5', PaymentMethod.upi),
    receipt('sample-2', 'BigBasket', 'groceries', daysAgo(3), 2318, 5, '29AABCS1234F1ZP', PaymentMethod.creditCard),
    receipt('sample-3', 'Uber', 'transport', daysAgo(3), 284, 5, '27AABCU6223H1ZS', PaymentMethod.upi),
    receipt('sample-4', 'Apollo Pharmacy', 'health', daysAgo(5), 1120, 5, '36AAACA5443N1ZW', PaymentMethod.debitCard),
    receipt('sample-5', 'Tata Power', 'utilities', daysAgo(9), 3460, 0, null, PaymentMethod.netBanking),
    receipt('sample-6', 'Zara', 'shopping', daysAgo(10), 4990, 18, '07AADCI9876B1ZQ', PaymentMethod.creditCard),
    receipt('sample-7', 'Swiggy', 'food', daysAgo(11), 812, 5, '29AAFCB7707D1ZR', PaymentMethod.upi),
    receipt('sample-8', 'Airtel', 'utilities', daysAgo(12), 999, 18, '07AAACB2894G1ZL', PaymentMethod.upi),
    receipt('sample-9', 'Rapido', 'transport', daysAgo(13), 96, 5, '29AAFCR2245P1ZN', PaymentMethod.upi),
    receipt('sample-10', 'DMart', 'groceries', daysAgo(15), 1745, 5, '27AAACA8432H1ZD', PaymentMethod.cash),
    receipt('sample-11', 'Indian Oil', 'transport', daysAgo(18), 2200, 0, null, PaymentMethod.creditCard),
    receipt('sample-12', "Nature's Basket", 'groceries', daysAgo(21), 1560, 5, '27AABCG1122R1ZK', PaymentMethod.upi),
  ];

  const pastMonthTotals = [19875, 24110, 16430, 21860, 18240];
  const mix = [
    ('groceries', 'DMart', 0.32, 5, PaymentMethod.upi),
    ('food', 'Swiggy', 0.20, 5, PaymentMethod.upi),
    ('transport', 'Uber', 0.14, 5, PaymentMethod.upi),
    ('shopping', 'Myntra', 0.16, 18, PaymentMethod.creditCard),
    ('utilities', 'Tata Power', 0.13, 0, PaymentMethod.netBanking),
    ('health', 'Apollo Pharmacy', 0.05, 5, PaymentMethod.debitCard),
  ];
  for (var back = 1; back <= pastMonthTotals.length; back++) {
    final monthTotal = pastMonthTotals[back - 1];
    var remaining = monthTotal;
    for (var i = 0; i < mix.length; i++) {
      final (categoryId, merchant, share, rate, payment) = mix[i];
      final rupees = i == mix.length - 1 ? remaining : (monthTotal * share).round();
      remaining -= rupees;
      final date = DateTime(today.year, today.month - back, 3 + i * 4);
      list.add(receipt('sample-past-$back-$i', merchant, categoryId, date, rupees, rate, null, payment));
    }
  }
  return list;
}
