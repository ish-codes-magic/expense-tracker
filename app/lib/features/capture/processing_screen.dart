import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/receipt_parser.dart';
import '../../data/models.dart';
import '../../services/receipt_reader.dart';
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

/// "Reading receipt": reads the captured photo on the phone, then opens
/// Review with whatever the rules found. Each step ticks when that stage has
/// actually finished.
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
  late final String? _photo = ref.read(draftProvider)?.imagePath;
  int _step = 0;
  bool _handedOver = false;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  Future<void> _read() async {
    final photo = _photo;
    if (photo == null) return _cancel();

    ReceiptDraft draft;
    try {
      final rows = await readReceiptRows(photo);
      if (_cancelled) return;
      final parsed = parseReceiptText(rows, today: dateOnly(DateTime.now()));
      // Parsing takes a millisecond; a short beat per step lets you see what
      // was done without slowing things down.
      for (var step = 1; step <= _steps.length; step++) {
        if (!mounted || _cancelled) return;
        setState(() => _step = step);
        await Future<void>.delayed(const Duration(milliseconds: 180));
      }
      draft = ReceiptDraft(
        merchant: parsed.merchant ?? '',
        date: parsed.date ?? dateOnly(DateTime.now()),
        payment: parsed.payment ?? PaymentMethod.upi,
        totalPaise: parsed.totalPaise,
        gstPaise: parsed.gstPaise,
        gstRate: parsed.gstRate,
        taxSplit: parsed.taxSplit,
        categoryId: parsed.categoryId ?? 'food',
        gstin: parsed.gstin ?? '',
        imagePath: photo,
      );
    } catch (error) {
      showToast("Couldn't read this one. Fill it in from the photo", icon: Ph.warningCircle);
      draft = ReceiptDraft.blank(imagePath: photo);
    }
    if (!mounted || _cancelled) return;
    ref.read(draftProvider.notifier).set(draft);
    _handedOver = true;
    context.pushReplacement('/review');
  }

  void _cancel() {
    _cancelled = true;
    ref.read(draftProvider.notifier).clear();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    // Cancelled or backed out of: the photo isn't going anywhere, so drop it.
    final photo = _photo;
    if (!_handedOver && photo != null) File(photo).delete().ignore();
    _sweep.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                CircleIconButton(icon: Ph.x, tooltip: 'Cancel', onPressed: _cancel),
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
                Positioned.fill(
                  child: photo == null
                      ? const StripedPaper()
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: ColoredBox(
                            color: Noc.surface,
                            child: Image.file(File(photo), fit: BoxFit.contain),
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
                            BoxShadow(color: Noc.accent.withValues(alpha: 0.6), blurRadius: 18, spreadRadius: 4),
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
    final icon = Icon(done ? Ph.checkCircle : (active ? Ph.circleNotch : Ph.circle), size: 18, color: Noc.accent);
    return Row(children: [
      if (active) FadeTransition(opacity: Tween(begin: 0.35, end: 1.0).animate(pulse), child: icon) else icon,
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: done || active ? Noc.text : Noc.n500))),
    ]);
  }
}
