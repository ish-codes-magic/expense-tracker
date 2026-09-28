import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/activity_screen.dart';
import 'features/budgets_screen.dart';
import 'features/gst_screen.dart';
import 'features/home_screen.dart';
import 'features/insights_screen.dart';
import 'features/not_built_yet_screen.dart';
import 'features/receipt_detail_screen.dart';
import 'widgets/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

NoTransitionPage<void> _tabPage(Widget child) => NoTransitionPage(child: child);

/// Screens are added here as they are built; the rest show a placeholder.
final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', pageBuilder: (context, state) => _tabPage(const HomeScreen())),
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => _tabPage(const ActivityScreen()),
        ),
        GoRoute(
          path: '/insights',
          pageBuilder: (context, state) => _tabPage(const InsightsScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _tabPage(const NotBuiltYetScreen(title: 'Settings')),
        ),
        GoRoute(
          path: '/budgets',
          builder: (context, state) => const BudgetsScreen(),
        ),
        GoRoute(
          path: '/gst',
          builder: (context, state) => const GstScreen(),
        ),
        GoRoute(
          path: '/receipt/:id',
          builder: (context, state) => ReceiptDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    ),
    GoRoute(
      path: '/processing',
      parentNavigatorKey: _rootKey,
      builder: (context, state) => const NotBuiltYetScreen(title: 'Scan', showBack: true),
    ),
  ],
);
