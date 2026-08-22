import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

/// Holds the selected app locale and persists it.
///
/// The locale used to reset to English on every launch because nothing was
/// ever written to storage.
class LocaleProvider with ChangeNotifier {
  static const String _prefsKey = 'app_locale';

  /// Locales the app declares in `MaterialApp.supportedLocales` — one per
  /// entry in the language picker (see [kAppLanguages]), so every language a
  /// user can pick is one Flutter's own widgets actually recognize.
  static final List<Locale> supported =
      kAppLanguages.map((l) => Locale(l.code)).toList();

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  static bool _isSupported(String code) =>
      supported.any((l) => l.languageCode == code);

  /// Reads the stored preference. Call once during app start-up.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefsKey);
      if (code != null && _isSupported(code)) {
        _locale = Locale(code);
        notifyListeners();
      }
    } catch (_) {
      // Keep the default locale.
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isSupported(locale.languageCode)) return;
    if (_locale.languageCode == locale.languageCode) return;

    _locale = Locale(locale.languageCode);
    notifyListeners();
    await _persist();
  }

  Future<void> toggleLanguage() =>
      setLocale(Locale(_locale.languageCode == 'en' ? 'hi' : 'en'));

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _locale.languageCode);
    } catch (_) {
      // Non-fatal.
    }
  }
}
