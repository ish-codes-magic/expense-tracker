import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slip/features/activity_screen.dart';
import 'package:slip/features/budgets_screen.dart';
import 'package:slip/features/gst_screen.dart';
import 'package:slip/features/home_screen.dart';
import 'package:slip/features/insights_screen.dart';
import 'package:slip/features/receipt_detail_screen.dart';
import 'package:slip/features/settings_screen.dart';

/// Lays out every screen on a narrow phone with large system text and fails on
/// any overflow. The window is tall so list items below the fold are built too.
void main() {
  final screens = <String, Widget>{
    'Home': const HomeScreen(),
    'Activity': const ActivityScreen(),
    'Receipt detail': const ReceiptDetailScreen(id: 's1'),
    'Budgets': const BudgetsScreen(),
    'GST summary': const GstScreen(),
    'Insights': const InsightsScreen(),
    'Settings': const SettingsScreen(),
  };

  for (final textScale in [1.0, 1.3]) {
    for (final MapEntry(key: name, value: screen) in screens.entries) {
      testWidgets('$name fits 360dp wide at ${textScale}x text', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = const Size(360, 3200);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            // The real theme fetches Inter over the network; tests use the default font.
            theme: ThemeData.dark(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: Scaffold(body: screen),
          ),
        ));
        await tester.pump();

        expect(tester.takeException(), isNull);
      });
    }
  }
}
