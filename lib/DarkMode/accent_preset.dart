import 'package:flutter/material.dart';

/// The app's selectable accent colours.
///
/// [seed] is the solid colour everything is tinted with; [gradient] is only
/// for the swatch in the settings UI, which reads far better as a gradient
/// than as a flat square.
///
/// [ultra] is the default and its seed is the app's original brand purple, so
/// an existing user who never opens the picker sees exactly what they saw
/// before.
enum AccentPreset {
  aurora(
    'Aurora',
    Color(0xFF14B8A6),
    [Color(0xFF2DD4BF), Color(0xFF6366F1)],
  ),
  ember(
    'Ember',
    Color(0xFFF97316),
    [Color(0xFFFB923C), Color(0xFFEF4444)],
  ),
  ultra(
    'Ultra',
    Color(0xFF4E14D1),
    [Color(0xFF6366F1), Color(0xFF3B82F6)],
  ),
  mono(
    'Mono',
    Color(0xFF4B5563),
    [Color(0xFFD1D5DB), Color(0xFF9CA3AF)],
  );

  const AccentPreset(this.label, this.seed, this.gradient);

  final String label;
  final Color seed;
  final List<Color> gradient;

  /// A lifted version for dark surfaces. The seeds are chosen to read on white;
  /// on a near-black ground the darker ones lose contrast, so anything used as
  /// text or an icon in dark mode takes this instead.
  Color get onDarkSeed => switch (this) {
        AccentPreset.aurora => const Color(0xFF5EEAD4),
        AccentPreset.ember => const Color(0xFFFDBA74),
        AccentPreset.ultra => const Color(0xFFB79CF7),
        AccentPreset.mono => const Color(0xFFD1D5DB),
      };

  static AccentPreset fromName(String? name) => AccentPreset.values.firstWhere(
        (preset) => preset.name == name,
        orElse: () => AccentPreset.ultra,
      );
}
