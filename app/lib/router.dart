import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/home_screen.dart';
import 'features/not_built_yet_screen.dart';
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
          pageBuilder: (context, state) => _tabPage(const NotBuiltYetScreen(title: 'Activity')),
        ),
        GoRoute(
          path: '/insights',
          pageBuilder: (context, state) => _tabPage(const NotBuiltYetScreen(title: 'Insights')),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _tabPage(const NotBuiltYetScreen(title: 'Settings')),
        ),
        GoRoute(
          path: '/budgets',
          builder: (context, state) => const NotBuiltYetScreen(title: 'Budgets', showBack: true),
        ),
        GoRoute(
          path: '/gst',
          builder: (context, state) => const NotBuiltYetScreen(title: 'GST paid', showBack: true),
        ),
        GoRoute(
          path: '/receipt/:id',
          builder: (context, state) => const NotBuiltYetScreen(title: 'Receipt', showBack: true),
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
