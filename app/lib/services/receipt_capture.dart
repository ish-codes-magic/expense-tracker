import 'dart:io';

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:uuid/uuid.dart';

import '../data/models.dart';

enum CaptureSource {
  /// Google's document scanner: finds the edges, straightens and crops.
  /// Its own gallery button runs saved photos through the same cleanup.
  camera,

  /// Straight to the gallery, then the scanner's crop screen.
  gallery,

  /// An e-receipt or invoice PDF; its first page becomes the photo.
  pdf,
}

/// The short side of a stored photo. Enough to read small receipt print;
/// larger photos are scaled down, smaller ones are left alone.
const _photoShortSide = 1400;
const _jpegQuality = 85;

/// Receipt photos live in the app's private storage, where other apps can't
/// see them. They are excluded from Google's automatic backup (see
/// android/app/src/main/res/xml).
Future<Directory> receiptPhotosDir() async {
  final dir = Directory('${(await getApplicationSupportDirectory()).path}/receipts');
  await dir.create(recursive: true);
  return dir;
}

/// Opens the scanner or picker and stores the result as a compressed JPEG.
/// Returns its path, or null if the user backed out.
Future<String?> captureReceipt(CaptureSource source) async {
  final target = '${(await receiptPhotosDir()).path}/${const Uuid().v4()}.jpg';

  if (source == CaptureSource.pdf) {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (file == null) return null;
    final copy = '${(await getTemporaryDirectory()).path}/${const Uuid().v4()}.pdf';
    await file.xFile.saveTo(copy);
    try {
      await _renderFirstPage(copy, target);
    } finally {
      await File(copy).delete();
    }
    return target;
  }

  final pages = await CunningDocumentScanner.getPictures(
    noOfPages: 1,
    scannerSource: source == CaptureSource.camera ? ScannerSource.cameraAndGallery : ScannerSource.gallery,
  );
  if (pages == null) return null;
  try {
    final saved = await FlutterImageCompress.compressAndGetFile(
      pages.first,
      target,
      minWidth: _photoShortSide,
      minHeight: _photoShortSide,
      quality: _jpegQuality,
    );
    if (saved == null) throw const FileSystemException("Couldn't save the photo");
  } finally {
    await CunningDocumentScanner.cleanCache();
  }
  return target;
}

Future<void> _renderFirstPage(String pdfPath, String target) async {
  final document = await PdfDocument.openFile(pdfPath);
  try {
    final page = await document.getPage(1);
    try {
      // PDF pages are measured in points (1/72 inch); scale so the width
      // matches a photo's short side.
      final scale = _photoShortSide / page.width;
      final image = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.jpeg,
        quality: _jpegQuality,
        backgroundColor: '#FFFFFF',
      );
      if (image == null) throw const FileSystemException("Couldn't read the PDF");
      await File(target).writeAsBytes(image.bytes);
    } finally {
      await page.close();
    }
  } finally {
    await document.close();
  }
}

/// Deletes stored photos no receipt points to, such as one captured just
/// before the app was closed on the Review screen. Run once at launch.
Future<void> deleteOrphanPhotos(List<Receipt> receipts, {Directory? dir}) async {
  dir ??= await receiptPhotosDir();
  // Photos have unique random names, so compare names rather than full paths,
  // which can be written differently for the same file.
  String nameOf(String path) => File(path).uri.pathSegments.last;
  final inUse = {for (final r in receipts) if (r.imagePath != null) nameOf(r.imagePath!)};
  await for (final entity in dir.list()) {
    if (entity is File && !inUse.contains(nameOf(entity.path))) {
      await entity.delete();
    }
  }
}
