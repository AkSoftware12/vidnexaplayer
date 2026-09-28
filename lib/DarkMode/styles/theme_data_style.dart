import 'package:material_ui/material_ui.dart';

import '../accent_preset.dart';

/// App themes.
///
/// Convention used across the codebase:
///  * `colorScheme.surface`   → scaffold / app-bar background
///  * `colorScheme.secondary` → primary text colour
///
/// The old dark theme had `background: Colors.white` together with
/// `secondary: Colors.white`, i.e. white text on a white background — the whole
/// UI was invisible in dark mode.
///
/// Both themes are now built from an [AccentPreset] rather than being
/// constants, so changing the accent in settings re-tints every themed widget
/// — switches, sliders, progress indicators, flat buttons — in one step.
class ThemeDataStyle {
  ThemeDataStyle._();

  static const Color _darkSurface = Color(0xFF121212);
  static const Color _darkElevated = Color(0xFF1E1E1E);

  /// App-wide default typeface. Declared in pubspec with all four weights, so
  /// `fontWeight` on a TextStyle still resolves to the right .ttf.
  static const String _fontFamily = 'Poppins';

  /// Foreground for flat buttons, set explicitly per theme.
  ///
  /// A `TextButton` with no style takes its foreground from
  /// `colorScheme.primary`. This app uses `primary` as a *surface* colour —
  /// white in the light theme, near-black in the dark one — so every unstyled
  /// `TextButton` rendered white-on-white or dark-on-dark and looked missing.
  /// Dialog actions were the worst of it: "Cancel" and "Delete" were both
  /// invisible on a confirmation that permanently deletes photos.
  ///
  /// Setting it here fixes every flat button in the app at once, including the
  /// ones that are not styled individually.
  static ThemeData light(AccentPreset accent) {
    final seed = accent.seed;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      // Bundled family (pubspec `fonts:`), applied theme-wide so any widget
      // that does NOT pass an explicit style still gets Poppins instead of
      // Roboto. Previously the look came from per-widget GoogleFonts.poppins()
      // calls, which downloaded the face at runtime and crashed offline users.
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: Colors.grey.shade100,
      colorScheme: ColorScheme.light(
        surface: Colors.grey.shade100,
        onSurface: Colors.black87,
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Colors.black,
        onSecondary: Colors.white,
        tertiary: seed,
      ),
      textButtonTheme: _textButtons(seed),
      switchTheme: _switches(seed),
      sliderTheme: _sliders(seed),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: seed),
      radioTheme: _radios(seed),
      checkboxTheme: _checkboxes(seed),
      tabBarTheme: TabBarThemeData(indicatorColor: seed),
    );
  }

  static ThemeData dark(AccentPreset accent) {
    final seed = accent.onDarkSeed;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: _darkSurface,
      cardColor: _darkElevated,
      colorScheme: ColorScheme.dark(
        surface: _darkSurface,
        onSurface: Colors.white,
        primary: _darkElevated,
        onPrimary: Colors.white,
        secondary: Colors.white,
        onSecondary: Colors.black,
        tertiary: seed,
      ),
      textButtonTheme: _textButtons(seed),
      switchTheme: _switches(seed),
      sliderTheme: _sliders(seed),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: seed),
      radioTheme: _radios(seed),
      checkboxTheme: _checkboxes(seed),
      tabBarTheme: TabBarThemeData(indicatorColor: seed),
    );
  }

  static TextButtonThemeData _textButtons(Color foreground) =>
      TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: foreground),
      );

  static SwitchThemeData _switches(Color accent) => SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : null,
        ),
      );

  static SliderThemeData _sliders(Color accent) => SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        overlayColor: accent.withValues(alpha: 0.16),
      );

  static RadioThemeData _radios(Color accent) => RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : null,
        ),
      );

  static CheckboxThemeData _checkboxes(Color accent) => CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? accent : null,
        ),
      );
}
