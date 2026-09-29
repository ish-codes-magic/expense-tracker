import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/app_lock.dart';
import '../theme/nocturne.dart';
import '../theme/phosphor.dart';
import 'nocturne_widgets.dart';

/// Wraps the whole app. Tells the lock when the app is hidden and shown, and
/// covers everything with [_LockScreen] while locked. The app underneath
/// stays alive, so a half-filled Review form is still there after unlocking.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = ref.read(appLockProvider.notifier);
    switch (state) {
      case AppLifecycleState.hidden || AppLifecycleState.paused:
        lock.appHidden();
      case AppLifecycleState.resumed:
        lock.appShown();
      case AppLifecycleState.inactive || AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(appLockProvider);
    return Stack(children: [
      // Hidden from screen readers too while locked.
      ExcludeSemantics(excluding: locked, child: widget.child),
      if (locked) const Positioned.fill(child: _LockScreen()),
    ]);
  }
}

class _LockScreen extends ConsumerStatefulWidget {
  const _LockScreen();

  @override
  ConsumerState<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<_LockScreen> {
  String? _problem;

  @override
  void initState() {
    super.initState();
    // Ask straight away; the button is there if the prompt is dismissed.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final result = await ref.read(appLockProvider.notifier).unlock();
    if (mounted) setState(() => _problem = result.problem);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Noc.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            const Spacer(flex: 3),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Noc.accent),
                boxShadow: [BoxShadow(color: Noc.accent.withValues(alpha: 0.3), blurRadius: 24)],
              ),
              child: const Icon(Ph.fingerprint, size: 30, color: Noc.accent),
            ),
            const SizedBox(height: 20),
            const Text('Slip is locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(
              _problem ?? 'Use your fingerprint, face or phone PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _problem == null ? Noc.n500 : Noc.a300),
            ),
            const Spacer(flex: 2),
            SizedBox(
              width: double.infinity,
              child: NocButton(
                padding: const EdgeInsets.symmetric(vertical: 13),
                onPressed: _unlock,
                child: const Center(child: Text('Unlock', style: TextStyle(fontSize: 15))),
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}
