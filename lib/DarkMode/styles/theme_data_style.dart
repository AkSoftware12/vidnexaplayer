import 'package:flutter/material.dart';

/// App themes.
///
/// Convention used across the codebase:
///  * `colorScheme.surface`   → scaffold / app-bar background
///  * `colorScheme.secondary` → primary text colour
///
/// The old dark theme had `background: Colors.white` together with
/// `secondary: Colors.white`, i.e. white text on a white background — the whole
/// UI was invisible in dark mode.
class ThemeDataStyle {
  ThemeDataStyle._();

  static const Color _darkSurface = Color(0xFF121212);
  static const Color _darkElevated = Color(0xFF1E1E1E);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.grey.shade100,
    colorScheme: ColorScheme.light(
      surface: Colors.grey.shade100,
      onSurface: Colors.black87,
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Colors.black,
      onSecondary: Colors.white,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkSurface,
    cardColor: _darkElevated,
    colorScheme: const ColorScheme.dark(
      surface: _darkSurface,
      onSurface: Colors.white,
      primary: _darkElevated,
      onPrimary: Colors.white,
      secondary: Colors.white,
      onSecondary: Colors.black,
    ),
  );
}
