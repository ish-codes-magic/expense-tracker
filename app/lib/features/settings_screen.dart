import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../services/share_csv.dart';
import '../state/budgets.dart';
import '../state/receipts.dart';
import '../state/settings.dart';
import '../theme/nocturne.dart';
import '../theme/phosphor.dart';
import '../widgets/nocturne_widgets.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final receiptCount = ref.watch(receiptsProvider).length;
    final monthlyBudget = totalBudget(ref.watch(budgetsProvider));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('Settings',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: -0.3)),
          const SizedBox(height: 16),
          SurfaceCard(
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: Noc.a900, shape: BoxShape.circle),
                child: const Icon(Ph.receipt, size: 20, color: Noc.a300),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Stored on this phone', style: TextStyle(fontSize: 14)),
                  Text(
                    '$receiptCount ${receiptCount == 1 ? 'receipt' : 'receipts'} · no account needed',
                    style: const TextStyle(fontSize: 11.5, color: Noc.n500),
                  ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),

          const _Group(title: 'Money'),
          const _SettingsRow(icon: Ph.currencyInr, label: 'Currency', value: 'INR · ₹'),
          _SettingsRow(
            icon: Ph.receipt,
            label: 'Track GST',
            detail: 'Tax splits, rates and the GST summary',
            onTap: notifier.toggleShowGst,
            trailing: NocToggle(value: settings.showGst, onChanged: (_) => notifier.toggleShowGst()),
          ),
          _SettingsRow(
            icon: Ph.wallet,
            label: 'Monthly budget',
            value: inr(monthlyBudget),
            onTap: () => context.push('/budgets'),
            trailing: const _Chevron(),
          ),
          const SizedBox(height: 22),

          const _Group(title: 'Capture'),
          _SettingsRow(
            icon: Ph.sparkle,
            label: 'Auto-categorise',
            detail: 'Reuse the category you last picked for a merchant',
            onTap: notifier.toggleAutoCategorise,
            trailing: NocToggle(
              value: settings.autoCategorise,
              onChanged: (_) => notifier.toggleAutoCategorise(),
            ),
          ),
          const SizedBox(height: 22),

          const _Group(title: 'Your data'),
          _SettingsRow(
            icon: Ph.export,
            label: 'Export all receipts',
            value: 'CSV',
            enabled: receiptCount > 0,
            onTap: () => _exportAll(ref),
            trailing: const _Chevron(),
          ),
          _SettingsRow(
            icon: Ph.trash,
            label: 'Delete all receipts',
            enabled: receiptCount > 0,
            onTap: () => _confirmDeleteAll(context, ref, receiptCount),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAll(WidgetRef ref) async {
    final receipts = ref.read(receiptsProvider);
    try {
      final today = dateOnly(DateTime.now());
      final stamp = '${today.year}-${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      await shareReceiptsCsv(receipts, fileName: 'slip-receipts-$stamp.csv', subject: 'Slip receipts');
    } catch (error) {
      showToast("Couldn't export: $error", icon: Ph.warningCircle);
    }
  }

  Future<void> _confirmDeleteAll(BuildContext context, WidgetRef ref, int count) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete all receipts?', style: TextStyle(fontSize: 20)),
        content: Text(
          'All $count receipts will be removed from this phone. Export them first if you '
          'want a copy. This cannot be undone.',
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
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(receiptsProvider.notifier).clear();
    showToast('All receipts deleted');
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 2), child: SectionLabel(title));
}

/// One settings line: icon, label (with optional detail underneath), an
/// optional value on the right, then a toggle or chevron. A row that is
/// temporarily unavailable (e.g. export with no receipts) passes enabled: false.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    this.detail,
    this.value,
    this.onTap,
    this.trailing,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final String? detail;
  final String? value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: RuledRow(
        onTap: enabled ? onTap : null,
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(children: [
          Icon(icon, size: 18, color: Noc.n400),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              if (detail != null)
                Text(detail!, style: const TextStyle(fontSize: 11.5, color: Noc.n500)),
            ]),
          ),
          if (value != null) ...[
            const SizedBox(width: 8),
            Text(value!, style: const TextStyle(fontSize: 12, color: Noc.n500)),
          ],
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ]),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) => const Icon(Ph.caretRight, size: 14, color: Noc.n600);
}
