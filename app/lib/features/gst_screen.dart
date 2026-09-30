import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/gst_export.dart';
import '../core/spending.dart';
import '../data/models.dart';
import '../services/share_csv.dart';
import '../state/app_lock.dart';
import '../state/receipts.dart';
import '../theme/nocturne.dart';
import '../theme/phosphor.dart';
import '../widgets/nocturne_widgets.dart';

enum _Period { thisMonth, lastMonth, financialYear }

class GstScreen extends ConsumerStatefulWidget {
  const GstScreen({super.key});

  @override
  ConsumerState<GstScreen> createState() => _GstScreenState();
}

class _GstScreenState extends ConsumerState<GstScreen> {
  _Period _period = _Period.thisMonth;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptsProvider);
    final today = dateOnly(DateTime.now());
    final lastMonth = DateTime(today.year, today.month - 1);
    final yearStart = financialYearStart(today);

    final inPeriod = switch (_period) {
      _Period.thisMonth => inMonth(receipts, today),
      _Period.lastMonth => inMonth(receipts, lastMonth),
      _Period.financialYear => sinceDate(receipts, yearStart),
    };
    final periodLabel = switch (_period) {
      _Period.thisMonth => monthYear(today),
      _Period.lastMonth => monthYear(lastMonth),
      _Period.financialYear => 'since ${longDate(yearStart)}',
    };
    final fileSuffix = switch (_period) {
      _Period.thisMonth => _yearMonth(today),
      _Period.lastMonth => _yearMonth(lastMonth),
      _Period.financialYear => financialYearLabel(today).replaceAll(' ', '-').replaceAll('–', '-'),
    };

    final taxed = inPeriod.where((r) => r.gstPaise > 0).toList();
    final total = gstOf(taxed);
    var cgst = 0, sgst = 0, igst = 0;
    final byRate = <int?, int>{};
    for (final r in taxed) {
      final parts = gstComponents(r);
      cgst += parts.cgst;
      sgst += parts.sgst;
      igst += parts.igst;
      byRate[r.gstRate] = (byRate[r.gstRate] ?? 0) + r.gstPaise;
    }
    // Numeric rates in ascending order, "Mixed" last.
    final rates = byRate.keys.toList()
      ..sort((a, b) => a == null ? 1 : b == null ? -1 : a.compareTo(b));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ScreenHeader(
            title: 'GST paid',
            onBack: () => context.canPop() ? context.pop() : context.go('/'),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 6, runSpacing: 6, children: [
            NocChip(
              label: monthShort(today),
              selected: _period == _Period.thisMonth,
              onTap: () => setState(() => _period = _Period.thisMonth),
            ),
            NocChip(
              label: monthShort(lastMonth),
              selected: _period == _Period.lastMonth,
              onTap: () => setState(() => _period = _Period.lastMonth),
            ),
            NocChip(
              label: financialYearLabel(today),
              selected: _period == _Period.financialYear,
              onTap: () => setState(() => _period = _Period.financialYear),
            ),
          ]),
          const SizedBox(height: 18),

          Text(
            inr(total, withPaise: true),
            style: const TextStyle(
                fontSize: 40, fontWeight: FontWeight.w500, letterSpacing: -0.8, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            'across ${taxed.length} ${taxed.length == 1 ? 'receipt' : 'receipts'} with GST · $periodLabel',
            style: const TextStyle(fontSize: 12, color: Noc.n500),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _Component(label: 'CGST', paise: cgst)),
            Expanded(child: _Component(label: 'SGST', paise: sgst)),
            Expanded(child: _Component(label: 'IGST', paise: igst)),
          ]),
          const SizedBox(height: 24),

          const SectionLabel('By rate'),
          const SizedBox(height: 10),
          if (rates.isEmpty)
            const Text('No GST in this period.', style: TextStyle(fontSize: 13, color: Noc.n500))
          else
            for (final rate in rates)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  SizedBox(
                    width: 48,
                    child: Text(gstRateLabel(rate), style: const TextStyle(fontSize: 13, color: Noc.n300)),
                  ),
                  Expanded(child: GlowBar(fraction: total == 0 ? 0 : byRate[rate]! / total)),
                  SizedBox(
                    width: 90,
                    child: Text(
                      inr(byRate[rate]!, withPaise: true),
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 13, fontFeatures: Noc.tabular),
                    ),
                  ),
                ]),
              ),
          const SizedBox(height: 16),

          Row(children: [
            const Expanded(child: SectionLabel('Receipts')),
            NocButton(
              kind: NocButtonKind.ghost,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              onPressed: taxed.isEmpty || _exporting
                  ? null
                  : () => _export(taxed, periodLabel, fileSuffix),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Ph.export, size: 14),
                SizedBox(width: 4),
                Text('Export CSV', style: TextStyle(fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 4),
          for (final receipt in taxed) _GstReceiptRow(receipt: receipt),
        ],
      ),
    );
  }

  static String _yearMonth(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _export(List<Receipt> receipts, String periodLabel, String fileSuffix) async {
    setState(() => _exporting = true);
    try {
      await ref.read(appLockProvider.notifier).whileOutside(() => shareReceiptsCsv(
            receipts,
            fileName: 'slip-gst-$fileSuffix.csv',
            subject: 'GST paid · $periodLabel',
          ));
    } catch (error) {
      showToast("Couldn't export: $error", icon: Ph.warningCircle);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}

class _Component extends StatelessWidget {
  const _Component({required this.label, required this.paise});

  final String label;
  final int paise;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Noc.n500, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(
          inr(paise, withPaise: true),
          style: TextStyle(
              fontSize: 14, color: paise == 0 ? Noc.n600 : Noc.text, fontFeatures: Noc.tabular),
        ),
      ]);
}

class _GstReceiptRow extends StatelessWidget {
  const _GstReceiptRow({required this.receipt});

  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final rate = receipt.gstRate == null ? 'mixed' : '${receipt.gstRate}%';
    return RuledRow(
      onTap: () => context.push('/receipt/${receipt.id}'),
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(receipt.merchant,
                style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              receipt.gstin ?? 'No GSTIN',
              style: const TextStyle(fontSize: 11, color: Noc.n500, fontFamily: 'monospace'),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(inr(receipt.gstPaise, withPaise: true),
              style: const TextStyle(fontSize: 14, fontFeatures: Noc.tabular)),
          Text('$rate on ${inr(receipt.totalPaise, withPaise: true)}',
              style: const TextStyle(fontSize: 11, color: Noc.n500)),
        ]),
      ]),
    );
  }
}
