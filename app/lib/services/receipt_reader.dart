import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/receipt_parser.dart';

/// Reads a receipt photo with Google's on-device text recognition: free,
/// offline, and the photo never leaves the phone. Returns the printed rows,
/// top to bottom, ready for [parseReceiptText].
Future<List<String>> readReceiptRows(String imagePath) async {
  final recognizer = TextRecognizer();
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
    final rows = groupIntoRows([
      for (final block in result.blocks)
        for (final line in block.lines)
          (
            text: line.text,
            top: line.boundingBox.top,
            bottom: line.boundingBox.bottom,
            left: line.boundingBox.left,
          ),
    ]);
    // Development builds log what was read, to tune the rules on real
    // receipts. Release builds never do.
    if (kDebugMode) debugPrint('Slip read ${rows.length} rows:\n${rows.join('\n')}');
    return rows;
  } finally {
    await recognizer.close();
  }
}
