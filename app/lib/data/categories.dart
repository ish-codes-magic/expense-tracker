import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
  Category(id: 'food', name: 'Food & drink', icon: PhosphorIconsRegular.coffee, monthlyLimitPaise: 600000),
  Category(id: 'groceries', name: 'Groceries', icon: PhosphorIconsRegular.shoppingCart, monthlyLimitPaise: 800000),
  Category(id: 'transport', name: 'Transport', icon: PhosphorIconsRegular.car, monthlyLimitPaise: 300000),
  Category(id: 'shopping', name: 'Shopping', icon: PhosphorIconsRegular.shoppingBag, monthlyLimitPaise: 500000),
  Category(id: 'utilities', name: 'Utilities', icon: PhosphorIconsRegular.lightning, monthlyLimitPaise: 500000),
  Category(id: 'health', name: 'Health', icon: PhosphorIconsRegular.firstAid, monthlyLimitPaise: 200000),
];

Category categoryById(String id) =>
    categories.firstWhere((c) => c.id == id, orElse: () => categories.first);
