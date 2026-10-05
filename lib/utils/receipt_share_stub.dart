import 'dart:typed_data';

/// Stub implementation of shareOrDownloadReceiptImage for non-web platforms.
Future<bool> shareOrDownloadReceiptImage({
  required Uint8List bytes,
  required String filename,
  required String title,
  required String text,
}) async {
  return false;
}
