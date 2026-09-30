import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../theme/nocturne.dart';
import 'nocturne_widgets.dart';

class ReceiptRow extends StatelessWidget {
  const ReceiptRow({super.key, required this.receipt, required this.subtitle, this.amountDetail});

  final Receipt receipt;
  final String subtitle;

  /// A short line under the amount, e.g. the GST, where it has room even
  /// with large system text.
  final String? amountDetail;

  @override
  Widget build(BuildContext context) {
    return RuledRow(
      onTap: () => context.push('/receipt/${receipt.id}'),
      child: Row(children: [
        IconTile(icon: categoryById(receipt.categoryId).icon),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(receipt.merchant, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Noc.n500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            inr(receipt.totalPaise, withPaise: true),
            style: const TextStyle(fontSize: 14, fontFeatures: Noc.tabular),
          ),
          if (amountDetail != null)
            Text(amountDetail!,
                style: const TextStyle(fontSize: 11.5, color: Noc.n500, fontFeatures: Noc.tabular)),
        ]),
      ]),
    );
  }
}
