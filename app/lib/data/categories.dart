import 'package:flutter/widgets.dart';
import '../theme/phosphor.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.defaultLimitPaise,
  });

  final String id;
  final String name;
  final IconData icon;
  /// Starting monthly limit; the user can change it on the Budgets screen.
  final int defaultLimitPaise;
}

final categories = <Category>[
  Category(id: 'food', name: 'Food & drink', icon: Ph.coffee, defaultLimitPaise: 600000),
  Category(id: 'groceries', name: 'Groceries', icon: Ph.shoppingCart, defaultLimitPaise: 800000),
  Category(id: 'transport', name: 'Transport', icon: Ph.car, defaultLimitPaise: 300000),
  Category(id: 'shopping', name: 'Shopping', icon: Ph.shoppingBag, defaultLimitPaise: 500000),
  Category(id: 'utilities', name: 'Utilities', icon: Ph.lightning, defaultLimitPaise: 500000),
  Category(id: 'health', name: 'Health', icon: Ph.firstAid, defaultLimitPaise: 200000),
];

Category categoryById(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.first);
