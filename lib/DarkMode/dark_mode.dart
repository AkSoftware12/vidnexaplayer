import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoplayer/DarkMode/styles/theme_data_style.dart';

/// Holds the light/dark choice and persists it.
///
/// Previously the theme always reset to light on every launch, and the toggle
/// in the bottom-nav drawer only wrote a `SharedPreferences` flag without ever
/// telling this provider — so nothing on screen changed.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'isDarkMode';

  bool _isDark = false;

  bool get isDark => _isDark;

  ThemeData get themeDataStyle =>
      _isDark ? ThemeDataStyle.dark : ThemeDataStyle.light;

  ThemeData get lightTheme => ThemeDataStyle.light;

  ThemeData get darkTheme => ThemeDataStyle.dark;

  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  /// Reads the stored preference. Call once during app start-up.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_prefsKey) ?? false;
      notifyListeners();
    } catch (_) {
      // Keep the default (light) if prefs are unavailable.
    }
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (_) {
      // Non-fatal: the theme still changed for this session.
    }
  }

  Future<void> toggleTheme() => setDark(!_isDark);

  /// Kept for backwards compatibility with existing call sites.
  void changeTheme() => toggleTheme();
}
