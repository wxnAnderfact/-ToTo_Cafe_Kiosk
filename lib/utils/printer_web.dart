// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web implementation of printReceipt using window.print().
void printReceipt() {
  html.window.print();
}
