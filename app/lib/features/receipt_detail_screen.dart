import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/gst.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../state/receipts.dart';
import '../state/settings.dart';
import '../theme/nocturne.dart';
import '../theme/phosphor.dart';
import '../widgets/nocturne_widgets.dart';

class ReceiptDetailScreen extends ConsumerWidget {
  const ReceiptDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipt = ref.watch(receiptByIdProvider(id));
    final settings = ref.watch(settingsProvider);

    if (receipt == null) {
      return SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            ScreenHeader(title: 'Receipt', large: false, onBack: () => context.pop()),
            const Spacer(),
            const Text('This receipt is gone.', style: TextStyle(color: Noc.n400)),
            const Spacer(flex: 2),
          ]),
        ),
      );
    }

    final category = categoryById(receipt.categoryId);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              CircleIconButton(icon: Ph.arrowLeft, tooltip: 'Back', onPressed: () => context.pop()),
              const Expanded(
                child: Text('Receipt', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
              ),
              CircleIconButton(
                icon: Ph.trash,
                tooltip: 'Delete',
                onPressed: () => _confirmDelete(context, ref, receipt),
              ),
            ]),
          ),
          const SizedBox(height: 8),

          Column(children: [
            IconTile(icon: category.icon, size: 52, radius: 14, iconSize: 26),
            const SizedBox(height: 10),
            Text(receipt.merchant, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(
              inr(receipt.totalPaise, withPaise: true),
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.7,
                  fontFeatures: Noc.tabular),
            ),
            const SizedBox(height: 4),
            Text(
              '${longDate(receipt.date)} · ${receipt.payment.label}',
              style: const TextStyle(fontSize: 12, color: Noc.n500),
            ),
          ]),
          const SizedBox(height: 20),

          Center(child: _Photo(path: receipt.imagePath)),
          const SizedBox(height: 20),

          _DetailRow(
            label: 'Category',
            value: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Noc.a800,
                borderRadius: BorderRadius.circular(Noc.radiusMd * 0.75),
              ),
              child: Text(category.name, style: const TextStyle(fontSize: 11, color: Noc.a100)),
            ),
          ),
          if (settings.showGst) ...[
            _DetailRow(label: 'Before tax', value: _Amount(receipt.preTaxPaise)),
            _DetailRow(
              label: 'GST${receipt.gstRate == null ? '' : ' (${_rateLabel(receipt.gstRate!)})'}',
              value: _Amount(receipt.gstPaise),
            ),
            _DetailRow(label: 'Tax type', value: _PlainValue(_splitLabel(receipt))),
            _DetailRow(
              label: 'GSTIN',
              value: _PlainValue(receipt.gstin ?? '—', mono: receipt.gstin != null),
            ),
          ],

          if (receipt.items.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionLabel('Line items'),
            const SizedBox(height: 4),
            for (final item in receipt.items)
              RuledRow(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  Expanded(child: Text(item.name, style: const TextStyle(fontSize: 13, color: Noc.n300))),
                  Text(
                    inr(item.amountPaise, withPaise: true),
                    style: const TextStyle(fontSize: 13, fontFeatures: Noc.tabular),
                  ),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  static String _rateLabel(int rate) => rate == 0 ? 'exempt' : '$rate%';

  static String _splitLabel(Receipt receipt) => switch (receipt.taxSplit) {
        TaxSplit.none => 'No GST',
        TaxSplit.cgstSgst => 'CGST + SGST',
        TaxSplit.igst => 'IGST',
      };

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Receipt receipt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this receipt?', style: TextStyle(fontSize: 20)),
        content: Text(
          '${receipt.merchant} · ${inr(receipt.totalPaise)} will be removed. This cannot be undone.',
          style: const TextStyle(fontSize: 14, color: Noc.n300),
        ),
        actions: [
          NocButton(
            kind: NocButtonKind.secondary,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          NocButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    context.pop();
    ref.read(receiptsProvider.notifier).remove(receipt.id);
    showToast('Receipt deleted');
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(File(path!), width: 200, height: 260, fit: BoxFit.cover),
      );
    }
    return const SizedBox(
      width: 200,
      height: 260,
      child: StripedPaper(
        child: Center(
          child: Text('No photo', style: TextStyle(fontSize: 11, color: Noc.n500)),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) => RuledRow(
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: Noc.n500))),
          value,
        ]),
      );
}

class _Amount extends StatelessWidget {
  const _Amount(this.paise);

  final int paise;

  @override
  Widget build(BuildContext context) => Text(
        inr(paise, withPaise: true),
        style: const TextStyle(fontSize: 14, fontFeatures: Noc.tabular),
      );
}

class _PlainValue extends StatelessWidget {
  const _PlainValue(this.text, {this.mono = false});

  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(fontSize: mono ? 12 : 14, fontFeatures: mono ? Noc.tabular : null),
      );
}
