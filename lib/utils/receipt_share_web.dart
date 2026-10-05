// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Web implementation of smart receipt sharing.
///
/// Uses Web Share API (mobile devices) with automatic fallback to direct PNG download.
Future<bool> shareOrDownloadReceiptImage({
  required Uint8List bytes,
  required String filename,
  required String title,
  required String text,
}) async {
  final blob = html.Blob([bytes], 'image/png');
  final file = html.File([blob], filename, {'type': 'image/png'});

  bool shared = false;

  // 1. Try Web Share API (native share sheet on iOS Safari, Android Chrome, LINE LIFF)
  try {
    final nav = js.context['navigator'];
    if (nav != null && nav.hasProperty('canShare')) {
      final shareData = js.JsObject.jsify({
        'files': [file],
        'title': title,
        'text': text,
      });
      if (nav.callMethod('canShare', [shareData]) == true) {
        final promise = nav.callMethod('share', [shareData]);
        if (promise != null && promise.hasProperty('then')) {
          await promise;
        }
        shared = true;
      }
    }
  } catch (e) {
    debugPrint('[ReceiptShare] Web Share API not available or dismissed: $e');
  }

  // 2. Fallback: Direct Download of PNG image file
  if (!shared) {
    try {
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      shared = true;
    } catch (e) {
      debugPrint('[ReceiptShare] Download fallback error: $e');
      return false;
    }
  }

  return shared;
}
