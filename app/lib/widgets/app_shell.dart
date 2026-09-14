import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/nocturne.dart';
import 'nocturne_widgets.dart';

/// Scaffold for the tabbed screens, with the design's bottom bar and its
/// raised Scan button.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  String get _activeTab {
    if (location.startsWith('/activity')) return '/activity';
    if (location.startsWith('/insights')) return '/insights';
    if (location.startsWith('/settings')) return '/settings';
    if (location == '/' || location == '/budgets' || location == '/gst') return '/';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(color: Noc.bg),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const FadeRule(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _tab(context, '/', 'Home', PhosphorIconsRegular.house),
                _tab(context, '/activity', 'Activity', PhosphorIconsRegular.listBullets),
                Expanded(child: _ScanTab(onTap: () => context.push('/processing'))),
                _tab(context, '/insights', 'Insights', PhosphorIconsRegular.chartBar),
                _tab(context, '/settings', 'Settings', PhosphorIconsRegular.gear),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, String path, String label, IconData icon) {
    final color = _activeTab == path ? Noc.accent : Noc.n500;
    return Expanded(
      child: InkResponse(
        onTap: () => context.go(path),
        radius: 32,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 10.5, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  const _ScanTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Scan receipt',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Noc.bg,
              shape: BoxShape.circle,
              border: Border.all(color: Noc.accent),
              boxShadow: [BoxShadow(color: Noc.accent.withValues(alpha: 0.3), blurRadius: 16)],
            ),
            child: const Icon(PhosphorIconsRegular.camera, size: 22, color: Noc.accent),
          ),
          const SizedBox(height: 3),
          const Text('Scan', style: TextStyle(fontSize: 10.5, color: Noc.accent)),
        ]),
      ),
    );
  }
}
