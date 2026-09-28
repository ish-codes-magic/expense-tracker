import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/draft.dart';
import '../../theme/nocturne.dart';
import '../../theme/phosphor.dart';
import '../../widgets/nocturne_widgets.dart';

const _steps = [
  'Reading text',
  'Finding merchant & GSTIN',
  'Extracting total and GST split',
  'Suggesting a category',
];

/// The "Reading receipt" screen: a scan line sweeps the photo while the steps
/// tick off. For now it hands the Review screen a sample draft on a timer;
/// the receipt reader will replace the timer with the real result.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key});

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> with TickerProviderStateMixin {
  late final _sweep = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
    ..repeat(reverse: true);
  final _timers = <Timer>[];
  int _step = 0;

  @override
  void initState() {
    super.initState();
    for (var i = 1; i <= _steps.length; i++) {
      _timers.add(Timer(Duration(milliseconds: 650 * i), () => setState(() => _step = i)));
    }
    _timers.add(Timer(const Duration(milliseconds: 3100), _finish));
  }

  void _finish() {
    ref.read(draftProvider.notifier).set(demoDraft());
    context.pushReplacement('/review');
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _sweep.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                CircleIconButton(icon: Ph.x, tooltip: 'Cancel', onPressed: () => context.pop()),
                const Expanded(
                  child: Text('Reading receipt', textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 36),
              ]),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              height: 300,
              child: Stack(children: [
                const Positioned.fill(
                  child: StripedPaper(
                    child: Center(
                      child: Text('Sample receipt',
                          style: TextStyle(fontSize: 11, color: Noc.n500, fontFamily: 'monospace')),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _sweep,
                  builder: (context, _) {
                    final t = Curves.easeInOut.transform(_sweep.value);
                    return Positioned(
                      left: 0,
                      right: 0,
                      top: 300 * (0.06 + 0.84 * t),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: Noc.accent,
                          boxShadow: [
                            BoxShadow(
                              color: Noc.accent.withValues(alpha: 0.6),
                              blurRadius: 18,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ]),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StepRow(label: _steps[i], done: _step > i, active: _step == i, pulse: _pulse),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.done, required this.active, required this.pulse});

  final String label;
  final bool done;
  final bool active;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      done ? Ph.checkCircle : (active ? Ph.circleNotch : Ph.circle),
      size: 18,
      color: Noc.accent,
    );
    return Row(children: [
      if (active)
        FadeTransition(opacity: Tween(begin: 0.35, end: 1.0).animate(pulse), child: icon)
      else
        icon,
      const SizedBox(width: 12),
      Expanded(
        child: Text(label, style: TextStyle(fontSize: 14, color: done || active ? Noc.text : Noc.n500)),
      ),
    ]);
  }
}
