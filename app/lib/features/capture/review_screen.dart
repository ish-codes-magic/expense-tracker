import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/format.dart';
import '../../core/gst.dart';
import '../../core/spending.dart';
import '../../data/categories.dart';
import '../../data/models.dart';
import '../../state/draft.dart';
import '../../state/receipts.dart';
import '../../state/settings.dart';
import '../../theme/nocturne.dart';
import '../../theme/phosphor.dart';
import '../../widgets/nocturne_widgets.dart';
import '../../widgets/photo_viewer.dart';

/// Shows what was read from the receipt so the user can correct it before
/// saving. The on-device checks from [fieldsToCheck] decide which fields get
/// a "check" mark; nothing here is saved until the user taps Save.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  late final ReceiptDraft _initial = ref.read(draftProvider) ?? demoDraft();
  late final _merchant = TextEditingController(text: _initial.merchant);
  late final _total = TextEditingController(text: paiseToField(_initial.totalPaise));
  late final _gst = TextEditingController(text: paiseToField(_initial.gstPaise));
  late final _gstin = TextEditingController(text: _initial.gstin);
  late DateTime _date = _initial.date;
  late PaymentMethod _payment = _initial.payment;
  late int? _rate = _initial.gstRate;
  late TaxSplit _split = _initial.taxSplit;
  late String _categoryId = _initial.categoryId;
  bool _categoryRemembered = false;
  bool _categoryPicked = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _rememberCategory(_initial.merchant);
  }

  /// Auto-categorise: a merchant seen before gets last time's category,
  /// unless the user has already picked one on this screen.
  void _rememberCategory(String merchant) {
    if (_categoryPicked || !ref.read(settingsProvider).autoCategorise) return;
    final remembered = lastCategoryFor(ref.read(receiptsProvider), merchant);
    if (remembered != null) _categoryId = remembered;
    _categoryRemembered = remembered != null;
  }

  @override
  void dispose() {
    // Leaving without saving (Discard, back arrow or back gesture) drops the
    // photo too, so unsaved scans don't pile up on the phone.
    final photo = _initial.imagePath;
    if (!_saved && photo != null) File(photo).delete().ignore();
    _merchant.dispose();
    _total.dispose();
    _gst.dispose();
    _gstin.dispose();
    super.dispose();
  }

  ReceiptDraft get _current => ReceiptDraft(
        merchant: _merchant.text,
        date: _date,
        payment: _payment,
        totalPaise: parsePaise(_total.text),
        gstPaise: parsePaise(_gst.text),
        gstRate: _rate,
        // Typing a GST amount without choosing the split means the common
        // case: a seller in your own state.
        taxSplit: (parsePaise(_gst.text) ?? 0) > 0 && _split == TaxSplit.none ? TaxSplit.cgstSgst : _split,
        source: _initial.source,
        categoryId: _categoryId,
        gstin: _gstin.text,
        items: _initial.items,
        imagePath: _initial.imagePath,
      );

  @override
  Widget build(BuildContext context) {
    final showGst = ref.watch(settingsProvider).showGst;
    final today = dateOnly(DateTime.now());
    final draft = _current;
    final flagged = fieldsToCheck(draft, today: today)
      ..removeAll(showGst ? const <DraftField>{} : {DraftField.gst, DraftField.gstin})
      // Empty boxes on a photo you're filling in yourself aren't mistakes;
      // Save still insists on a merchant and total.
      ..removeAll(draft.extracted ? const <DraftField>{} : {DraftField.merchant, DraftField.total});
    final gstPaise = draft.gstPaise ?? 0;

    // Offer the current slabs, plus an older rate if this bill used one.
    final rateOptions = [...standardGstRates, if (_rate != null && !standardGstRates.contains(_rate)) _rate!];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(children: [
                CircleIconButton(icon: Ph.arrowLeft, tooltip: 'Back', onPressed: _discard),
                const Expanded(
                  child: Text('Check the details',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 14)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Noc.a800,
                    borderRadius: BorderRadius.circular(Noc.radiusMd * 0.75),
                  ),
                  child: Text(
                    flagged.isNotEmpty
                        ? '${flagged.length} to check'
                        : (draft.extracted ? 'All checks passed' : 'Manual entry'),
                    style: const TextStyle(fontSize: 11, color: Noc.a100),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Thumbnail(path: draft.imagePath),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  draft.extracted
                      ? _summary(draft.source, draft.items.length, gstPaise > 0 && showGst, flagged.isEmpty)
                      : 'Type the details from the photo. Tap it to zoom in on small print.',
                  style: const TextStyle(fontSize: 12, color: Noc.n500, height: 1.6),
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _Field(
              label: 'Merchant',
              flagged: flagged.contains(DraftField.merchant),
              child: TextField(
                controller: _merchant,
                textCapitalization: TextCapitalization.words,
                onChanged: (value) => setState(() => _rememberCategory(value)),
                decoration: _decoration(flagged.contains(DraftField.merchant)),
              ),
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _Field(
                  label: 'Date',
                  flagged: flagged.contains(DraftField.date),
                  child: _Picker(
                    text: longDate(_date),
                    flagged: flagged.contains(DraftField.date),
                    onTap: _pickDate,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Field(
                  label: 'Paid via',
                  child: PopupMenuButton<PaymentMethod>(
                    initialValue: _payment,
                    onSelected: (method) => setState(() => _payment = method),
                    itemBuilder: (context) => [
                      for (final method in PaymentMethod.values)
                        PopupMenuItem(value: method, child: Text(method.label)),
                    ],
                    child: IgnorePointer(child: _Picker(text: _payment.label, onTap: () {})),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: _Field(
                  label: 'Total (₹)',
                  flagged: flagged.contains(DraftField.total),
                  child: _AmountField(
                    controller: _total,
                    flagged: flagged.contains(DraftField.total),
                    large: true,
                    onChanged: () => setState(() {}),
                  ),
                ),
              ),
              if (showGst) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _Field(
                    label: 'GST (₹)',
                    flagged: flagged.contains(DraftField.gst),
                    child: _AmountField(
                      controller: _gst,
                      flagged: flagged.contains(DraftField.gst),
                      large: true,
                      onChanged: () => setState(() {}),
                    ),
                  ),
                ),
              ],
            ]),

            if (showGst) ...[
              const SizedBox(height: 12),
              _Field(
                label: 'GST rate',
                child: Row(children: [
                  for (var i = 0; i < rateOptions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: NocChip(
                        label: rateOptions[i] == 0 ? 'Exempt' : '${rateOptions[i]}%',
                        selected: _rate == rateOptions[i],
                        expand: true,
                        onTap: () => _pickRate(rateOptions[i]),
                      ),
                    ),
                  ],
                ]),
              ),
              if (gstPaise > 0) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  NocChip(
                    label: 'CGST + SGST',
                    selected: draft.taxSplit == TaxSplit.cgstSgst,
                    onTap: () => setState(() => _split = TaxSplit.cgstSgst),
                  ),
                  NocChip(
                    label: 'IGST',
                    selected: draft.taxSplit == TaxSplit.igst,
                    onTap: () => setState(() => _split = TaxSplit.igst),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(
                  draft.taxSplit == TaxSplit.igst
                      ? 'IGST ${inr(gstPaise, withPaise: true)} · seller in another state'
                      : 'CGST ${inr(gstPaise ~/ 2, withPaise: true)} + '
                          'SGST ${inr(gstPaise - gstPaise ~/ 2, withPaise: true)} · seller in your state',
                  style: const TextStyle(fontSize: 11, color: Noc.n500),
                ),
              ],
              const SizedBox(height: 12),
              _Field(
                label: 'GSTIN',
                flagged: flagged.contains(DraftField.gstin),
                child: TextField(
                  controller: _gstin,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[0-9A-Za-z]')),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                  decoration: _decoration(flagged.contains(DraftField.gstin)).copyWith(
                    hintText: 'Not on the bill',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            _Field(
              label: _categoryRemembered ? 'Category · same as last time' : 'Category · suggested',
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final category in categories)
                  NocChip(
                    label: category.name,
                    icon: category.icon,
                    selected: _categoryId == category.id,
                    onTap: () => setState(() {
                      _categoryId = category.id;
                      _categoryRemembered = false;
                      _categoryPicked = true;
                    }),
                  ),
              ]),
            ),

            if (draft.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionLabel('Line items'),
              const SizedBox(height: 4),
              for (final item in draft.items)
                RuledRow(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(children: [
                    Expanded(
                      child: Text(item.name, style: const TextStyle(fontSize: 13, color: Noc.n300)),
                    ),
                    Text(inr(item.amountPaise, withPaise: true),
                        style: const TextStyle(fontSize: 13, fontFeatures: Noc.tabular)),
                  ]),
                ),
            ],
            const SizedBox(height: 20),

            NocButton(
              padding: const EdgeInsets.symmetric(vertical: 13),
              onPressed: _save,
              child: const Center(child: Text('Save receipt', style: TextStyle(fontSize: 15))),
            ),
            const SizedBox(height: 6),
            NocButton(
              kind: NocButtonKind.ghost,
              foreground: Noc.n500,
              padding: const EdgeInsets.symmetric(vertical: 10),
              onPressed: _discard,
              child: const Center(child: Text('Discard')),
            ),
          ],
        ),
      ),
    );
  }

  static String _summary(DraftSource source, int itemCount, bool hasGst, bool allPassed) {
    final read = [
      if (itemCount > 0) '$itemCount line ${itemCount == 1 ? 'item' : 'items'}',
      if (hasGst) 'a GST split',
    ];
    final who = source == DraftSource.ai ? 'Read with AI' : 'Read on your phone';
    final what = read.isEmpty ? '$who.' : '$who, including ${read.join(' and ')}.';
    return allPassed
        ? '$what Everything adds up — give it a quick look and save.'
        : '$what Fields marked "check" didn\'t add up or look misread — tap to fix.';
  }

  static InputDecoration _decoration(bool flagged) => flagged
      ? const InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(Noc.radiusMd)),
            borderSide: BorderSide(color: Noc.a700),
          ),
        )
      : const InputDecoration();

  /// Picking a rate recalculates the GST from the total, as the design does.
  void _pickRate(int rate) {
    setState(() {
      _rate = rate;
      final total = parsePaise(_total.text);
      if (total != null) _gst.text = paiseToField(gstInclusive(total, rate));
      if (rate == 0) {
        _split = TaxSplit.none;
      } else if (_split == TaxSplit.none) {
        _split = TaxSplit.cgstSgst;
      }
    });
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(today.year - 10),
      lastDate: today,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  Future<void> _save() async {
    final draft = _current;
    final total = draft.totalPaise;
    if (draft.merchant.trim().isEmpty) {
      showToast('Add the merchant name first', icon: Ph.warningCircle);
      return;
    }
    if (total == null || total <= 0) {
      showToast('Add the total first', icon: Ph.warningCircle);
      return;
    }
    final gst = min(max(draft.gstPaise ?? 0, 0), total);
    final gstin = draft.gstin.trim().toUpperCase();
    final receipt = Receipt(
      id: const Uuid().v4(),
      merchant: draft.merchant.trim(),
      categoryId: draft.categoryId,
      date: dateOnly(draft.date),
      totalPaise: total,
      gstPaise: gst,
      gstRate: gst == 0 ? 0 : draft.gstRate ?? inferGstRate(total, gst),
      taxSplit: gst == 0 ? TaxSplit.none : draft.taxSplit,
      payment: draft.payment,
      gstin: gstin.isEmpty ? null : gstin,
      items: draft.items,
      imagePath: draft.imagePath,
      createdAt: DateTime.now(),
    );
    final saved = await attempt(() => ref.read(receiptsProvider.notifier).add(receipt),
        failure: "Couldn't save the receipt");
    if (!saved || !mounted) return;
    _saved = true;
    ref.read(draftProvider.notifier).clear();
    context.go('/');
    showToast('Saved ${inr(total)} to ${categoryById(draft.categoryId).name}');
  }

  void _discard() {
    ref.read(draftProvider.notifier).clear();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    const size = Size(72, 96);
    if (path == null) {
      return SizedBox.fromSize(size: size, child: const StripedPaper(stripe: 6, radius: 8));
    }
    return Semantics(
      button: true,
      label: 'View receipt photo',
      child: GestureDetector(
        onTap: () => showReceiptPhoto(context, path!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(File(path!), width: size.width, height: size.height, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.flagged = false});

  final String label;
  final Widget child;
  final bool flagged;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Noc.text.withValues(alpha: 0.7))),
          ),
          if (flagged) const Text('● check', style: TextStyle(fontSize: 12, color: Noc.accent)),
        ]),
        const SizedBox(height: 5),
        child,
      ]);
}

/// A tappable box styled like a text field, for values chosen from a picker.
class _Picker extends StatelessWidget {
  const _Picker({required this.text, required this.onTap, this.flagged = false});

  final String text;
  final VoidCallback onTap;
  final bool flagged;

  @override
  Widget build(BuildContext context) => Material(
        color: Noc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Noc.radiusMd),
          side: BorderSide(color: flagged ? Noc.a700 : Noc.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Text(text, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.controller,
    required this.flagged,
    required this.onChanged,
    this.large = false,
  });

  final TextEditingController controller;
  final bool flagged;
  final VoidCallback onChanged;
  final bool large;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        onChanged: (_) => onChanged(),
        style: TextStyle(fontSize: large ? 18 : 14, fontFeatures: Noc.tabular),
        decoration: _ReviewScreenState._decoration(flagged),
      );
}
