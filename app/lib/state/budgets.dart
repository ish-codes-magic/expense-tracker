import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/categories.dart';
import 'database.dart';

/// Monthly limit per category id, in paise. The overall monthly budget is
/// their sum, so the two can never disagree.
final budgetsProvider = NotifierProvider<BudgetsNotifier, Map<String, int>>(BudgetsNotifier.new);

class BudgetsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => ref.read(startupDataProvider).budgets;

  Future<void> setLimits(Map<String, int> limits) async {
    final next = {...state, ...limits};
    await ref.read(slipDatabaseProvider).saveBudgets(next);
    state = next;
  }
}

Map<String, int> defaultBudgets() => {for (final c in categories) c.id: c.defaultLimitPaise};

int totalBudget(Map<String, int> limits) => limits.values.fold(0, (sum, limit) => sum + limit);
