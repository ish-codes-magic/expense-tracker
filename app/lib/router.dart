import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/activity_screen.dart';
import 'features/budgets_screen.dart';
import 'features/capture/processing_screen.dart';
import 'features/capture/review_screen.dart';
import 'features/gst_screen.dart';
import 'features/home_screen.dart';
import 'features/insights_screen.dart';
import 'features/receipt_detail_screen.dart';
import 'features/settings_screen.dart';
import 'widgets/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

NoTransitionPage<void> _tabPage(Widget child) => NoTransitionPage(child: child);

final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (context, state) => _tabPage(const HomeScreen())),
        GoRoute(path: '/activity', pageBuilder: (context, state) => _tabPage(const ActivityScreen())),
        GoRoute(path: '/insights', pageBuilder: (context, state) => _tabPage(const InsightsScreen())),
        GoRoute(path: '/settings', pageBuilder: (context, state) => _tabPage(const SettingsScreen())),
        GoRoute(path: '/budgets', builder: (context, state) => const BudgetsScreen()),
        GoRoute(path: '/gst', builder: (context, state) => const GstScreen()),
        GoRoute(
          path: '/receipt/:id',
          builder: (context, state) => ReceiptDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/processing',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const ProcessingScreen(),
    ),
    GoRoute(
      path: '/review',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const ReviewScreen(),
    ),
  ],
);

/// Pops when there is somewhere to go back to, otherwise returns home.
void goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/');
  }
}
