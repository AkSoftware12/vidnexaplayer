import 'package:flutter/material.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = Locale('en', '');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (!['en', 'hi'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      _locale = Locale('hi', '');
    } else {
      _locale = Locale('en', '');
    }
    notifyListeners();
  }
}