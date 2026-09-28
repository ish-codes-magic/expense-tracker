import 'package:flutter/widgets.dart';

import '../theme/nocturne.dart';
import '../theme/phosphor.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.defaultLimitPaise,
    required this.chartSlot,
  });

  final String id;
  final String name;
  final IconData icon;
  /// Starting monthly limit; the user can change it on the Budgets screen.
  final int defaultLimitPaise;

  /// Index into [Noc.chartSlots]. Groceries sits between the two slots that
  /// clash (2 and 4) because it is almost never zero in a month.
  final int chartSlot;

  Color get chartColor => Noc.chartSlots[chartSlot];
}

final categories = <Category>[
  Category(id: 'food', name: 'Food & drink', icon: Ph.coffee, defaultLimitPaise: 600000, chartSlot: 1),
  Category(id: 'groceries', name: 'Groceries', icon: Ph.shoppingCart, defaultLimitPaise: 800000, chartSlot: 3),
  Category(id: 'transport', name: 'Transport', icon: Ph.car, defaultLimitPaise: 300000, chartSlot: 2),
  Category(id: 'shopping', name: 'Shopping', icon: Ph.shoppingBag, defaultLimitPaise: 500000, chartSlot: 0),
  Category(id: 'utilities', name: 'Utilities', icon: Ph.lightning, defaultLimitPaise: 500000, chartSlot: 5),
  Category(id: 'health', name: 'Health', icon: Ph.firstAid, defaultLimitPaise: 200000, chartSlot: 4),
];

Category categoryById(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.first);
