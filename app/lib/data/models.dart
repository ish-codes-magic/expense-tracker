import '../core/gst.dart';

enum PaymentMethod {
  upi('UPI'),
  creditCard('Credit card'),
  debitCard('Debit card'),
  cash('Cash'),
  netBanking('Net banking'),
  other('Other');

  const PaymentMethod(this.label);
  final String label;
}

class LineItem {
  const LineItem({required this.name, required this.amountPaise});

  final String name;
  final int amountPaise;
}

class Receipt {
  const Receipt({
    required this.id,
    required this.merchant,
    required this.categoryId,
    required this.date,
    required this.totalPaise,
    required this.gstPaise,
    required this.gstRate,
    required this.taxSplit,
    required this.payment,
    required this.createdAt,
    this.gstin,
    this.items = const [],
    this.imagePath,
  });

  final String id;
  final String merchant;
  final String categoryId;
  final DateTime date;
  final int totalPaise;
  final int gstPaise;

  /// Null when a bill mixes several rates.
  final int? gstRate;
  final TaxSplit taxSplit;
  final PaymentMethod payment;
  final String? gstin;
  final List<LineItem> items;
  final String? imagePath;
  final DateTime createdAt;

  int get preTaxPaise => totalPaise - gstPaise;
}
