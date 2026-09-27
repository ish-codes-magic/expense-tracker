import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/spending.dart';
import '../data/categories.dart';
import '../state/budgets.dart';
import '../state/receipts.dart';
import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(receiptsProvider);
    final limits = ref.watch(budgetsProvider);
    final today = dateOnly(DateTime.now());

    final thisMonth = inMonth(receipts, today).toList();
    final byCategory = spendByCategory(thisMonth);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          ScreenHeader(
            title: 'Budgets',
            onBack: () => context.canPop() ? context.pop() : context.go('/'),
            trailing: NocButton(
              kind: NocButtonKind.ghost,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              onPressed: () => _openEditor(context, ref),
              child: const Text('Edit', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${monthName(today)} · ${inr(totalOf(thisMonth))} of ${inr(totalBudget(limits))} '
            'across ${categories.length} categories. Bars glow when a budget passes 90%.',
            style: const TextStyle(fontSize: 12, color: Noc.n500),
          ),
          const SizedBox(height: 8),
          for (final category in categories)
            _BudgetRow(
              category: category,
              spentPaise: byCategory[category.id] ?? 0,
              limitPaise: limits[category.id] ?? 0,
              onTap: () => _openEditor(context, ref),
            ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    final updated = await showModalBottomSheet<Map<String, int>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Noc.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Noc.radiusLg)),
        side: BorderSide(color: Noc.n800),
      ),
      builder: (context) => _BudgetEditor(limits: ref.read(budgetsProvider)),
    );
    if (updated == null) return;
    ref.read(budgetsProvider.notifier).setLimits(updated);
    showToast('Budgets updated');
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.category,
    required this.spentPaise,
    required this.limitPaise,
    required this.onTap,
  });

  final Category category;
  final int spentPaise;
  final int limitPaise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hot = isNearLimit(spentPaise, limitPaise);
    final left = limitPaise - spentPaise;
    final String note;
    if (limitPaise == 0) {
      note = 'No budget set';
    } else if (left >= 0) {
      note = '${inr(left)} left · ${(spentPaise / limitPaise * 100).round()}% used';
    } else {
      note = '${inr(-left)} over budget';
    }

    return RuledRow(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(category.icon, size: 18, color: Noc.a300),
          const SizedBox(width: 10),
          Expanded(child: Text(category.name, style: const TextStyle(fontSize: 14))),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: inr(spentPaise)),
              if (limitPaise > 0)
                TextSpan(text: ' / ${inr(limitPaise)}', style: const TextStyle(color: Noc.n600)),
            ]),
            style: const TextStyle(fontSize: 13, fontFeatures: Noc.tabular),
          ),
        ]),
        if (limitPaise > 0)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 10),
            child: GlowBar(
              fraction: spentPaise / limitPaise,
              color: hot ? Noc.a300 : Noc.accent,
              glow: hot,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 28, top: 6),
          child: Text(note, style: TextStyle(fontSize: 11, color: hot ? Noc.a300 : Noc.n500)),
        ),
      ]),
    );
  }
}

/// Bottom sheet for setting every category's monthly limit at once.
/// Returns the new limits in paise, or null if cancelled.
class _BudgetEditor extends StatefulWidget {
  const _BudgetEditor({required this.limits});

  final Map<String, int> limits;

  @override
  State<_BudgetEditor> createState() => _BudgetEditorState();
}

class _BudgetEditorState extends State<_BudgetEditor> {
  late final Map<String, TextEditingController> _controllers = {
    for (final c in categories)
      c.id: TextEditingController(text: ((widget.limits[c.id] ?? 0) ~/ 100).toString()),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, int> get _parsed => {
        for (final entry in _controllers.entries)
          entry.key: (parsePaise(entry.value.text) ?? 0).clamp(0, 1 << 40),
      };

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Expanded(
                child: Text('Monthly budgets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              ),
              Text('Total ${inr(totalBudget(_parsed))}',
                  style: const TextStyle(fontSize: 12, color: Noc.n400, fontFeatures: Noc.tabular)),
            ]),
            const SizedBox(height: 4),
            const Text('Set a category to 0 to track it without a limit.',
                style: TextStyle(fontSize: 12, color: Noc.n500)),
            const SizedBox(height: 14),
            for (final category in categories)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(category.icon, size: 18, color: Noc.a300),
                  const SizedBox(width: 10),
                  Expanded(child: Text(category.name, style: const TextStyle(fontSize: 14))),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _controllers[category.id],
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 14, fontFeatures: Noc.tabular),
                      decoration: const InputDecoration(prefixText: '₹ '),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: NocButton(
                  kind: NocButtonKind.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => Navigator.pop(context),
                  child: const Center(child: Text('Cancel')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: NocButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => Navigator.pop(context, _parsed),
                  child: const Center(child: Text('Save')),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
