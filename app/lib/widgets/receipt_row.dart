import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../theme/nocturne.dart';
import 'nocturne_widgets.dart';

class ReceiptRow extends StatelessWidget {
  const ReceiptRow({super.key, required this.receipt, required this.subtitle});

  final Receipt receipt;
  final String subtitle;

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
        Text(
          inr(receipt.totalPaise, withPaise: true),
          style: const TextStyle(fontSize: 14, fontFeatures: Noc.tabular),
        ),
      ]),
    );
  }
}
