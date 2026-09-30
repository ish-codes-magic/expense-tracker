import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/edition.dart';
import '../../services/receipt_capture.dart';
import '../../state/app_lock.dart';
import '../../state/draft.dart';
import '../../theme/nocturne.dart';
import '../../theme/phosphor.dart';
import '../../widgets/nocturne_widgets.dart';

/// Scan or import a receipt, then read it (Processing), which opens Review
/// with what it found. The free edition skips the reading and opens Review
/// as a blank form to type into.
Future<void> startCapture(BuildContext context, WidgetRef ref, CaptureSource source) async {
  final String? photo;
  try {
    photo = await ref.read(appLockProvider.notifier).whileOutside(() => captureReceipt(source));
  } catch (error) {
    showToast(
      source == CaptureSource.pdf ? "Couldn't open that PDF: $error" : "Couldn't open the scanner: $error",
      icon: Ph.warningCircle,
    );
    return;
  }
  if (photo == null || !context.mounted) return;
  ref.read(draftProvider.notifier).set(ReceiptDraft.blank(imagePath: photo));
  context.push(Edition.current == Edition.free ? '/review' : '/processing');
}

/// "Upload file" on Home: a saved photo or an e-receipt PDF.
Future<void> chooseUpload(BuildContext context, WidgetRef ref) async {
  final source = await showModalBottomSheet<CaptureSource>(
    context: context,
    useRootNavigator: true,
    backgroundColor: Noc.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Noc.radiusLg)),
      side: BorderSide(color: Noc.n800),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Upload a receipt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          _UploadOption(
            icon: Ph.images,
            label: 'Photo from gallery',
            detail: 'Cropped and straightened like a scan',
            onTap: () => Navigator.pop(context, CaptureSource.gallery),
          ),
          _UploadOption(
            icon: Ph.filePdf,
            label: 'PDF',
            detail: 'E-receipts and invoices; the first page is kept',
            onTap: () => Navigator.pop(context, CaptureSource.pdf),
          ),
        ]),
      ),
    ),
  );
  if (source != null && context.mounted) await startCapture(context, ref, source);
}

class _UploadOption extends StatelessWidget {
  const _UploadOption({required this.icon, required this.label, required this.detail, required this.onTap});

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => RuledRow(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          IconTile(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(detail, style: const TextStyle(fontSize: 11.5, color: Noc.n500)),
            ]),
          ),
          const Icon(Ph.caretRight, size: 14, color: Noc.n600),
        ]),
      );
}
