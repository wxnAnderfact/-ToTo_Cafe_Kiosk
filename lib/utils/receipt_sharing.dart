import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'receipt_share_stub.dart'
    if (dart.library.html) 'receipt_share_web.dart' as platform_share;

/// Captures a [RepaintBoundary] identified by [boundaryKey] to PNG byte data.
Future<Uint8List?> captureWidgetToImage(GlobalKey boundaryKey) async {
  try {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0); // 3x high-resolution
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (e) {
    debugPrint('[Capture] Error capturing widget to image: $e');
    return null;
  }
}

/// Shares or downloads a receipt image based on platform capabilities.
Future<bool> shareOrDownloadReceipt({
  required Uint8List bytes,
  required String filename,
  required String title,
  required String text,
}) async {
  return platform_share.shareOrDownloadReceiptImage(
    bytes: bytes,
    filename: filename,
    title: title,
    text: text,
  );
}
