import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/nocturne.dart';
import '../widgets/nocturne_widgets.dart';

/// Stands in for screens we haven't built yet, so every tab still opens.
class NotBuiltYetScreen extends StatelessWidget {
  const NotBuiltYetScreen({super.key, required this.title, this.showBack = false});

  final String title;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: [
          ScreenHeader(title: title, onBack: showBack ? () => context.pop() : null),
          const Spacer(),
          const Text('Not built yet', style: TextStyle(fontSize: 15, color: Noc.n400)),
          const SizedBox(height: 6),
          const Text('This screen comes in a later step.',
              style: TextStyle(fontSize: 13, color: Noc.n600)),
          const Spacer(flex: 2),
        ]),
      ),
    );
  }
}
