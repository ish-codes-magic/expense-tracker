import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/spending.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../state/receipts.dart';
import '../state/settings.dart';
import '../theme/nocturne.dart';
import '../theme/phosphor.dart';
import '../widgets/nocturne_widgets.dart';
import '../widgets/receipt_row.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  String? _categoryId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final receipts = ref.watch(receiptsProvider);
    final settings = ref.watch(settingsProvider);

    final matches = receipts.where(_matches).toList();
    final months = _groupByMonth(matches);

    return SafeArea(
      bottom: false,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Expanded(
                child: Text('Activity',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: -0.3)),
              ),
              Text('${matches.length} receipts',
                  style: const TextStyle(fontSize: 12, color: Noc.n500)),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search merchants, categories, GSTIN',
                prefixIcon: const Icon(Ph.magnifyingGlass, size: 16, color: Noc.n500),
                prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Ph.x, size: 14, color: Noc.n500),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length + 1,
            separatorBuilder: (context, index) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == 0) {
                return NocChip(
                  label: 'All',
                  selected: _categoryId == null,
                  onTap: () => setState(() => _categoryId = null),
                );
              }
              final category = categories[index - 1];
              return NocChip(
                label: category.name,
                icon: category.icon,
                selected: _categoryId == category.id,
                onTap: () => setState(
                    () => _categoryId = _categoryId == category.id ? null : category.id),
              );
            },
          ),
        ),
        Expanded(
          child: matches.isEmpty
              ? const Center(
                  child: Text('Nothing matches.',
                      style: TextStyle(fontSize: 13, color: Noc.n500)),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  children: [
                    for (final month in months) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(children: [
                          Expanded(child: SectionLabel(monthYear(month.month))),
                          Text(inr(totalOf(month.receipts)),
                              style: const TextStyle(
                                  fontSize: 12, color: Noc.n500, fontFeatures: Noc.tabular)),
                        ]),
                      ),
                      for (final receipt in month.receipts)
                        ReceiptRow(
                          receipt: receipt,
                          subtitle: '${categoryById(receipt.categoryId).name} · ${shortDate(receipt.date)}',
                          amountDetail: settings.showGst && receipt.gstPaise > 0
                              ? 'GST ${inr(receipt.gstPaise, withPaise: true)}'
                              : null,
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }

  bool _matches(Receipt receipt) {
    if (_categoryId != null && receipt.categoryId != _categoryId) return false;
    if (_query.isEmpty) return true;
    final haystack = [
      receipt.merchant,
      categoryById(receipt.categoryId).name,
      receipt.gstin ?? '',
      receipt.payment.label,
    ].join(' ').toLowerCase();
    return haystack.contains(_query);
  }

  static List<({DateTime month, List<Receipt> receipts})> _groupByMonth(List<Receipt> receipts) {
    final groups = <DateTime, List<Receipt>>{};
    for (final receipt in receipts) {
      final month = DateTime(receipt.date.year, receipt.date.month);
      groups.putIfAbsent(month, () => []).add(receipt);
    }
    final months = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final month in months) (month: month, receipts: groups[month]!)];
  }
}
