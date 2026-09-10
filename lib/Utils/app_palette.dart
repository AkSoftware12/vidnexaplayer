import 'package:flutter/material.dart';

/// Surface and text colours that follow the active theme.
///
/// Most screens in this app predate any theming and hardcode their colours —
/// white cards, near-black text — so switching the app to dark left them
/// unchanged and unreadable. Converting them all to read `Theme.of(context)`
/// directly would mean touching hundreds of call sites; pointing them at these
/// getters instead is a one-word change per colour.
///
/// [setBrightness] is called from `MaterialApp.builder`, where the theme has
/// already been resolved — that matters for `ThemeMode.system`, where the real
/// brightness comes from the platform rather than from the stored preference.
class AppPalette {
  AppPalette._();

  static bool _dark = false;

  static bool get isDark => _dark;

  /// Returns true when the value changed, so the caller can decide whether a
  /// rebuild is warranted.
  static bool setBrightness(bool dark) {
    if (_dark == dark) return false;
    _dark = dark;
    return true;
  }

  /// Call once at the top of a `build()` before reading any colour below.
  ///
  /// This does two jobs, and the second is the important one. It refreshes the
  /// stored brightness, and — because it reads `Theme.of(context)` — it
  /// registers this widget as a dependent of the theme, so Flutter rebuilds it
  /// when the theme changes.
  ///
  /// Without it the getters still return the right colours, but nothing tells
  /// the screen to repaint: static fields are not `InheritedWidget`s and have
  /// no listeners. Toggling light/dark would leave every already-built screen
  /// showing its old palette until something else happened to rebuild it —
  /// which is exactly how it looked when the switch appeared to do nothing.
  static void sync(BuildContext context) {
    _dark = Theme.of(context).brightness == Brightness.dark;
  }

  /// Page background.
  ///
  /// The dark values are the slate tones the drawer was already written
  /// against (`0xFF0F172A` / `0xFF1E293B`) rather than a neutral grey. Two
  /// different dark palettes in one app read as a bug — the drawer looked
  /// blue-black while the profile beside it looked neutral — so this is now
  /// the single source both use.
  static Color get surface =>
      _dark ? const Color(0xFF0F172A) : const Color(0xFFF0F1F6);

  /// Cards, tiles, sheets — anything raised above [surface].
  static Color get card =>
      _dark ? const Color(0xFF1E293B) : Colors.white;

  /// A second raised level, for chips and inputs sitting on a [card].
  static Color get raised =>
      _dark ? const Color(0xFF283548) : const Color(0xFFF3F4F6);

  /// Headings and primary text.
  static Color get textH => _dark ? Colors.white : const Color(0xFF111827);

  /// Body text.
  static Color get textB =>
      _dark ? Colors.white70 : const Color(0xFF374151);

  /// Secondary / caption text.
  static Color get textS =>
      _dark ? Colors.white38 : const Color(0xFF9CA3AF);

  static Color get border =>
      _dark ? Colors.white12 : const Color(0xFFE5E7EB);
}
