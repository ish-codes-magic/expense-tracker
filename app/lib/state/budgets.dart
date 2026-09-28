import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/categories.dart';

/// Monthly limit per category id, in paise. The overall monthly budget is
/// their sum, so the two can never disagree.
final budgetsProvider = NotifierProvider<BudgetsNotifier, Map<String, int>>(BudgetsNotifier.new);

class BudgetsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {for (final c in categories) c.id: c.defaultLimitPaise};

  void setLimits(Map<String, int> limits) => state = {...state, ...limits};
}

int totalBudget(Map<String, int> limits) => limits.values.fold(0, (sum, limit) => sum + limit);
