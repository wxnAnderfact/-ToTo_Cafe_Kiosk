import 'package:flutter/material.dart';

class LocaleProvider extends ChangeNotifier {
  bool _isThai = true;
  bool get isThai => _isThai;

  void toggle() {
    _isThai = !_isThai;
    notifyListeners();
  }

  // Helper: returns thaiText or englishText based on current locale
  String t(String thaiText, String englishText) {
    return _isThai ? thaiText : englishText;
  }
}
