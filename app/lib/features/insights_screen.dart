import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/spending.dart';
import '../data/categories.dart';
import '../state/budgets.dart';
import '../state/receipts.dart';
import '../state/settings.dart';
import '../theme/nocturne.dart';
import '../theme/phosphor.dart';
import '../widgets/nocturne_widgets.dart';

typedef _CategoryShare = ({Category category, int paise});

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider);
    final limits = ref.watch(budgetsProvider);
    final showGst = ref.watch(settingsProvider).showGst;
    final today = dateOnly(DateTime.now());

    final months = [
      for (var back = 5; back >= 0; back--) DateTime(today.year, today.month - back),
    ];
    final monthTotals = [for (final m in months) totalOf(inMonth(receipts, m))];

    // Compare month-to-date with the same days last month; a part month
    // against a whole one would always look like a drop.
    final lastMonth = months[months.length - 2];
    final comparableDay = min(today.day, DateUtils.getDaysInMonth(lastMonth.year, lastMonth.month));
    final lastMonthToDate = totalOf(inMonth(receipts, lastMonth)
        .where((r) => r.date.day <= comparableDay));
    final thisMonthTotal = monthTotals.last;

    final thisMonth = inMonth(receipts, today).toList();
    final byCategory = spendByCategory(thisMonth);
    final shares = <_CategoryShare>[
      for (final c in categories)
        if ((byCategory[c.id] ?? 0) > 0) (category: c, paise: byCategory[c.id]!),
    ];
    final bySize = [...shares]..sort((a, b) => b.paise.compareTo(a.paise));
    final bySlot = [...shares]..sort((a, b) => a.category.chartSlot.compareTo(b.category.chartSlot));

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('Insights',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: -0.3)),
          const SizedBox(height: 18),

          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Expanded(child: SectionLabel('Monthly spend')),
            _Trend(
              thisMonthToDate: thisMonthTotal,
              lastMonthToDate: lastMonthToDate,
              lastMonth: lastMonth,
              comparableDay: comparableDay,
            ),
          ]),
          const SizedBox(height: 14),
          _MonthlyColumns(months: months, totals: monthTotals),
          const SizedBox(height: 26),

          SectionLabel('Where it went · ${monthName(today)}'),
          const SizedBox(height: 10),
          if (shares.isEmpty)
            const Text('Nothing spent yet this month.',
                style: TextStyle(fontSize: 13, color: Noc.n500))
          else ...[
            _ShareBar(shares: bySlot),
            const SizedBox(height: 6),
            for (final share in bySize)
              _ShareRow(share: share, totalPaise: thisMonthTotal),
          ],
          const SizedBox(height: 18),

          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Kicker('Noticed'),
              const SizedBox(height: 4),
              Text(
                _noticed(bySize, thisMonthTotal, byCategory, limits, monthName(today)),
                style: const TextStyle(fontSize: 13, height: 1.5, color: Noc.n300),
              ),
            ]),
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(child: _LinkButton(label: 'Budgets', onTap: () => context.push('/budgets'))),
            if (showGst) ...[
              const SizedBox(width: 10),
              Expanded(child: _LinkButton(label: 'GST paid', onTap: () => context.push('/gst'))),
            ],
          ]),
        ],
      ),
    );
  }

  /// A plain-language summary: the biggest category, then budget status.
  static String _noticed(List<_CategoryShare> bySize, int totalPaise, Map<String, int> byCategory,
      Map<String, int> limits, String month) {
    if (totalPaise == 0) return 'No receipts yet this month. Scan one and this fills in.';

    final top = bySize.first;
    final share = (top.paise / totalPaise * 100).round();
    final sentences = ['${top.category.name} is $share% of $month so far.'];

    final over = [
      for (final c in categories)
        if ((limits[c.id] ?? 0) > 0 && (byCategory[c.id] ?? 0) > limits[c.id]!) c.name,
    ];
    final near = [
      for (final c in categories)
        if (isNearLimit(byCategory[c.id] ?? 0, limits[c.id] ?? 0) && !over.contains(c.name)) c.name,
    ];
    if (over.isNotEmpty) {
      sentences.add('${_listNames(over)} ${over.length == 1 ? 'is' : 'are'} over budget.');
    } else if (near.isNotEmpty) {
      sentences.add('${_listNames(near)} ${near.length == 1 ? 'is' : 'are'} close to the limit.');
    } else {
      sentences.add('Every category is within budget.');
    }
    return sentences.join(' ');
  }

  static String _listNames(List<String> names) => names.length == 1
      ? names.single
      : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
}

class _Trend extends StatelessWidget {
  const _Trend({
    required this.thisMonthToDate,
    required this.lastMonthToDate,
    required this.lastMonth,
    required this.comparableDay,
  });

  final int thisMonthToDate;
  final int lastMonthToDate;
  final DateTime lastMonth;
  final int comparableDay;

  @override
  Widget build(BuildContext context) {
    if (lastMonthToDate == 0) return const SizedBox.shrink();
    final change = ((thisMonthToDate - lastMonthToDate) / lastMonthToDate * 100).round();
    final sign = change > 0 ? '+' : '';
    return Text(
      '$sign$change% vs 1–$comparableDay ${monthShort(lastMonth)}',
      // Spending more is the direction worth noticing.
      style: TextStyle(fontSize: 12, color: change > 0 ? Noc.a300 : Noc.n500),
    );
  }
}

/// Six months of spend. The current month is the story, so it alone takes the
/// accent; earlier months are context in grey. With no y-axis, each column
/// carries its own compact value.
class _MonthlyColumns extends StatelessWidget {
  const _MonthlyColumns({required this.months, required this.totals});

  final List<DateTime> months;
  final List<int> totals;

  static const _barArea = 104.0;
  static const _barWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final maxTotal = totals.fold(0, max);
    Widget column(int i) {
      final current = i == totals.length - 1;
      final height = maxTotal == 0 ? 0.0 : max(totals[i] > 0 ? 2.0 : 0.0, _barArea * totals[i] / maxTotal);
      return Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            totals[i] == 0 ? '—' : inrThousands(totals[i]),
            style: TextStyle(fontSize: 10.5, color: current ? Noc.text : Noc.n500),
          ),
          const SizedBox(height: 6),
          Container(
            width: _barWidth,
            height: height,
            decoration: BoxDecoration(
              color: current ? Noc.accent : Noc.n700,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              boxShadow: current
                  ? [BoxShadow(color: Noc.accent.withValues(alpha: 0.45), blurRadius: 14)]
                  : null,
            ),
          ),
        ]),
      );
    }

    return Column(children: [
      // No fixed height: the row grows with the value labels, so large system
      // text can't push them out of the chart.
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < totals.length; i++) column(i),
      ]),
      Container(height: 1, color: Noc.n800),
      const SizedBox(height: 6),
      Row(children: [
        for (var i = 0; i < months.length; i++)
          Expanded(
            child: Text(
              monthShort(months[i]),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: i == months.length - 1 ? Noc.text : Noc.n500),
            ),
          ),
      ]),
    ]);
  }
}

/// Part-to-whole bar. Segments follow chart-slot order, not size, so the
/// colours that sit next to each other are the ones checked as distinguishable.
class _ShareBar extends StatelessWidget {
  const _ShareBar({required this.shares});

  final List<_CategoryShare> shares;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 6,
          child: Row(children: [
            for (var i = 0; i < shares.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                flex: shares[i].paise,
                child: ColoredBox(color: shares[i].category.chartColor),
              ),
            ],
          ]),
        ),
      );
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({required this.share, required this.totalPaise});

  final _CategoryShare share;
  final int totalPaise;

  @override
  Widget build(BuildContext context) => RuledRow(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: share.category.chartColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(share.category.name, style: const TextStyle(fontSize: 13))),
          Text('${(share.paise / totalPaise * 100).round()}%',
              style: const TextStyle(fontSize: 13, color: Noc.n500, fontFeatures: Noc.tabular)),
          SizedBox(
            width: 84,
            child: Text(
              inr(share.paise),
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontFeatures: Noc.tabular),
            ),
          ),
        ]),
      );
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NocButton(
        kind: NocButtonKind.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onPressed: onTap,
        child: Row(children: [
          Expanded(child: Text(label)),
          const Icon(Ph.arrowRight, size: 14),
        ]),
      );
}
