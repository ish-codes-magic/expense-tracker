import 'package:flutter/widgets.dart';
import '../theme/phosphor.dart';

class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.monthlyLimitPaise,
  });

  final String id;
  final String name;
  final IconData icon;
  final int monthlyLimitPaise;
}

final categories = <Category>[
  Category(id: 'food', name: 'Food & drink', icon: Ph.coffee, monthlyLimitPaise: 600000),
  Category(id: 'groceries', name: 'Groceries', icon: Ph.shoppingCart, monthlyLimitPaise: 800000),
  Category(id: 'transport', name: 'Transport', icon: Ph.car, monthlyLimitPaise: 300000),
  Category(id: 'shopping', name: 'Shopping', icon: Ph.shoppingBag, monthlyLimitPaise: 500000),
  Category(id: 'utilities', name: 'Utilities', icon: Ph.lightning, monthlyLimitPaise: 500000),
  Category(id: 'health', name: 'Health', icon: Ph.firstAid, monthlyLimitPaise: 200000),
];

Category categoryById(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.first);
