import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/phosphor.dart';

import '../core/format.dart';
import '../core/spending.dart';
import '../data/categories.dart';
import '../state/receipts.dart';
import '../state/settings.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';
import '../widgets/receipt_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider);
    final settings = ref.watch(settingsProvider);
    final today = dateOnly(DateTime.now());

    final thisMonth = inMonth(receipts, today).toList();
    final spent = totalOf(thisMonth);
    final budget = settings.monthlyBudgetPaise;
    final left = budget - spent;
    final byCategory = spendByCategory(thisMonth);
    final nearLimit = categories
        .where((c) => (byCategory[c.id] ?? 0) >= c.monthlyLimitPaise * 0.9)
        .length;
    final financialYearGst = gstOf(sinceDate(receipts, financialYearStart(today)));
    final recent = receipts.take(4).toList();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(weekdayDate(today), style: const TextStyle(fontSize: 12, color: Noc.n500)),
                Text(_greeting(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
              ]),
            ),
            CircleIconButton(
              icon: Ph.user,
              size: 38,
              tooltip: 'Settings',
              onPressed: () => context.go('/settings'),
            ),
          ]),
          const SizedBox(height: 20),

          Kicker('${monthName(today)} spend'),
          const SizedBox(height: 4),
          Text(
            inr(spent),
            style: const TextStyle(
                fontSize: 40, fontWeight: FontWeight.w500, letterSpacing: -0.8, height: 1.1),
          ),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              left >= 0 ? '${inr(left)} left of ${inr(budget)}' : '${inr(-left)} over ${inr(budget)}',
              style: const TextStyle(fontSize: 12, color: Noc.n500),
            ),
            Text('${_percent(spent, budget)}%', style: const TextStyle(fontSize: 12, color: Noc.n500)),
          ]),
          const SizedBox(height: 6),
          GlowBar(fraction: budget == 0 ? 0 : spent / budget, glow: spent >= budget * 0.9),
          if (settings.showGst) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Text('GST paid this month ', style: TextStyle(fontSize: 12, color: Noc.n500)),
              Text(inr(gstOf(thisMonth), withPaise: true),
                  style: const TextStyle(fontSize: 12, color: Noc.n300, fontFeatures: Noc.tabular)),
            ]),
          ],
          const SizedBox(height: 20),

          Row(children: [
            Expanded(
              child: NocButton(
                onPressed: () => context.push('/processing'),
                radius: Noc.radiusLg,
                padding: const EdgeInsets.all(14),
                child: const _ActionContent(icon: Ph.camera, label: 'Scan receipt'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: NocButton(
                onPressed: () => context.push('/processing'),
                kind: NocButtonKind.secondary,
                radius: Noc.radiusLg,
                padding: const EdgeInsets.all(14),
                child: const _ActionContent(
                  icon: Ph.uploadSimple,
                  label: 'Upload file',
                  iconColor: Noc.n400,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),

          Row(children: [
            Expanded(
              child: _SummaryCard(
                label: 'Budgets',
                value: nearLimit == 0 ? 'All on track' : '$nearLimit of ${categories.length} near limit',
                link: 'Categories',
                onTap: () => context.push('/budgets'),
              ),
            ),
            if (settings.showGst) ...[
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryCard(
                  label: 'GST · ${financialYearLabel(today)}',
                  value: inr(financialYearGst),
                  link: 'Tax summary',
                  onTap: () => context.push('/gst'),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 20),

          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(child: SectionLabel('Recent')),
            NocButton(
              kind: NocButtonKind.ghost,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onPressed: () => context.go('/activity'),
              child: const Text('See all', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 6),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No receipts yet. Scan one to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Noc.n500),
              ),
            )
          else
            for (final receipt in recent)
              ReceiptRow(
                receipt: receipt,
                subtitle: '${categoryById(receipt.categoryId).name} · ${shortDate(receipt.date)}',
              ),
        ],
      ),
    );
  }

  static String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _percent(int part, int whole) =>
      whole == 0 ? '0' : ((part / whole) * 100).clamp(0, 100).toStringAsFixed(0);
}

class _ActionContent extends StatelessWidget {
  const _ActionContent({required this.icon, required this.label, this.iconColor});

  final IconData icon;
  final String label;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(height: 8),
          Text(label),
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard(
      {required this.label, required this.value, required this.link, required this.onTap});

  final String label;
  final String value;
  final String link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SurfaceCard(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Noc.n500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
          const SizedBox(height: 4),
          Row(children: [
            Flexible(
              child: Text(link,
                  style: const TextStyle(fontSize: 11, color: Noc.a300),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 4),
            const Icon(Ph.arrowRight, size: 12, color: Noc.a300),
          ]),
        ]),
      );
}
