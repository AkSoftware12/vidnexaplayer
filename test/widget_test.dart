// Unit tests for the pure logic that used to be the source of real bugs.
//
// The previous contents were Flutter's untouched "Counter increments smoke
// test" template — it looked for an `Icons.add` button this app has never had,
// and pumped `MyApp()` without its Providers, so it could only ever fail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:videoplayer/DarkMode/dark_mode.dart';
import 'package:videoplayer/NotifyListeners/LanguageProvider/language_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeProvider', () {
    test('defaults to light', () {
      expect(ThemeProvider().isDark, isFalse);
    });

    test('toggle flips and persists the choice', () async {
      final provider = ThemeProvider();
      await provider.toggleTheme();

      expect(provider.isDark, isTrue);
      expect(provider.themeMode, ThemeMode.dark);

      // A fresh provider must read the persisted value back — the old
      // implementation never wrote it, so dark mode reset on every launch.
      final reloaded = ThemeProvider();
      await reloaded.load();
      expect(reloaded.isDark, isTrue);
    });

    test('notifies listeners on change', () async {
      final provider = ThemeProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      await provider.toggleTheme();
      expect(notifications, 1);

      // Setting the same value again must not notify.
      await provider.setDark(true);
      expect(notifications, 1);
    });
  });

  group('LocaleProvider', () {
    test('defaults to English', () {
      expect(LocaleProvider().locale.languageCode, 'en');
    });

    test('ignores unsupported locales', () async {
      final provider = LocaleProvider();
      await provider.setLocale(const Locale('fr'));
      expect(provider.locale.languageCode, 'en');
    });

    test('persists the selected locale', () async {
      final provider = LocaleProvider();
      await provider.setLocale(const Locale('hi'));
      expect(provider.locale.languageCode, 'hi');

      final reloaded = LocaleProvider();
      await reloaded.load();
      expect(reloaded.locale.languageCode, 'hi');
    });

    test('toggle round-trips between en and hi', () async {
      final provider = LocaleProvider();
      await provider.toggleLanguage();
      expect(provider.locale.languageCode, 'hi');

      await provider.toggleLanguage();
      expect(provider.locale.languageCode, 'en');
    });
  });
}
