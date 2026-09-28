import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videoplayer/DarkMode/accent_preset.dart';
import 'package:videoplayer/DarkMode/styles/theme_data_style.dart';
import 'package:videoplayer/Utils/color.dart';

/// Holds the theme choice — light / dark / follow the system — and the accent
/// colour, and persists both.
///
/// Previously this only stored a light-or-dark bool, so "follow system" was
/// not expressible at all and the app ignored the device's own dark setting.
class ThemeProvider extends ChangeNotifier {
  static const String _modeKey = 'themeMode';
  static const String _accentKey = 'themeAccent';

  /// The pre-existing light/dark flag. Read once on upgrade so a user who had
  /// chosen dark keeps it instead of being reset to light.
  static const String _legacyDarkKey = 'isDarkMode';

  ThemeMode _mode = ThemeMode.light;
  AccentPreset _accent = AccentPreset.ultra;

  ThemeMode get themeMode => _mode;

  AccentPreset get accent => _accent;

  /// Whether dark is *currently* being shown, system setting included.
  ///
  /// Kept because existing screens read it. Under [ThemeMode.system] it
  /// reflects the platform, which is why it needs the window's brightness
  /// rather than just the stored choice.
  bool get isDark => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };

  ThemeData get lightTheme => ThemeDataStyle.light(_accent);

  ThemeData get darkTheme => ThemeDataStyle.dark(_accent);

  ThemeData get themeDataStyle => isDark ? darkTheme : lightTheme;

  /// Reads the stored preferences. Call once during app start-up.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final storedMode = prefs.getString(_modeKey);
      if (storedMode != null) {
        _mode = ThemeMode.values.firstWhere(
          (mode) => mode.name == storedMode,
          orElse: () => ThemeMode.light,
        );
      } else {
        // First run after the upgrade: carry the old boolean across.
        _mode = (prefs.getBool(_legacyDarkKey) ?? false)
            ? ThemeMode.dark
            : ThemeMode.light;
      }

      _accent = AccentPreset.fromName(prefs.getString(_accentKey));
      _applyAccent();
      notifyListeners();
    } catch (_) {
      // Keep the defaults if prefs are unavailable.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_modeKey, mode.name);
      // Keep the legacy flag roughly in step for anything still reading it.
      await prefs.setBool(_legacyDarkKey, mode == ThemeMode.dark);
    } catch (_) {
      // Non-fatal: the theme still changed for this session.
    }
  }

  Future<void> setAccent(AccentPreset accent) async {
    if (_accent == accent) return;
    _accent = accent;
    _applyAccent();
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accentKey, accent.name);
    } catch (_) {
      // Non-fatal.
    }
  }

  /// Pushes the accent into [ColorSelect], which ~116 call sites read directly
  /// rather than going through `Theme.of(context)`.
  ///
  /// A static bridge rather than a refactor of every one of those call sites:
  /// changing it here and then calling [notifyListeners] rebuilds `MaterialApp`
  /// and with it the whole tree, so the next build reads the new value. The
  /// long-term fix is for those screens to read `colorScheme.tertiary`; until
  /// then this is what makes the picker actually change the app.
  void _applyAccent() {
    ColorSelect.maineColor = _accent.seed;
  }

  Future<void> setDark(bool value) =>
      setMode(value ? ThemeMode.dark : ThemeMode.light);

  Future<void> toggleTheme() => setDark(!isDark);

  /// Kept for backwards compatibility with existing call sites.
  void changeTheme() => toggleTheme();
}
