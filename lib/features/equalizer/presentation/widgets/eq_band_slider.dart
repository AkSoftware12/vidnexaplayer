import 'package:material_ui/material_ui.dart';

/// One vertical band slider with its dB readout and frequency label.
///
/// Built on a rotated [Slider] rather than a hand-rolled gesture widget so it
/// inherits Flutter's drag physics, keyboard handling and semantics — a custom
/// pan detector here reads fine but is unusable with TalkBack.
class EqBandSlider extends StatelessWidget {
  const EqBandSlider({
    super.key,
    required this.label,
    required this.valueDb,
    required this.minDb,
    required this.maxDb,
    required this.onChanged,
    required this.accent,
    required this.trackColor,
    required this.labelColor,
    this.enabled = true,
    this.height = 150,
  });

  final String label;
  final double valueDb;
  final double minDb;
  final double maxDb;
  final ValueChanged<double> onChanged;
  final Color accent;
  final Color trackColor;
  final Color labelColor;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dimmed = enabled ? 1.0 : 0.4;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Readout above, so the value stays visible while the thumb is under
        // the user's finger.
        Text(
          '${valueDb >= 0 ? '+' : ''}${valueDb.toStringAsFixed(1)}',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: (valueDb.abs() < 0.05 ? labelColor : accent)
                .withValues(alpha: dimmed),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: height,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                activeTrackColor: accent.withValues(alpha: dimmed),
                inactiveTrackColor: trackColor.withValues(alpha: dimmed * 0.6),
                thumbColor: accent.withValues(alpha: dimmed),
                overlayColor: accent.withValues(alpha: 0.12),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                // No divisions: an EQ that snaps in 1 dB steps feels broken
                // under the finger.
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(
                value: valueDb.clamp(minDb, maxDb),
                min: minDb,
                max: maxDb,
                onChanged: enabled ? onChanged : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: labelColor.withValues(alpha: dimmed),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

/// Horizontal 0..max control used for bass boost, virtualizer and loudness.
class EqValueSlider extends StatelessWidget {
  const EqValueSlider({
    super.key,
    required this.title,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.accent,
    required this.titleColor,
    required this.subtitleColor,
    this.icon,
    this.trailing,
    this.subtitle,
    this.warning,
    this.enabled = true,
  });

  final String title;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final Color accent;
  final Color titleColor;
  final Color subtitleColor;
  final IconData? icon;
  final String? trailing;
  final String? subtitle;

  /// Shown in amber below the slider — clipping / hearing-safety notes.
  final String? warning;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dimmed = enabled ? 1.0 : 0.4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: accent.withValues(alpha: dimmed)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: titleColor.withValues(alpha: dimmed),
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: accent.withValues(alpha: dimmed),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: EdgeInsets.only(left: icon != null ? 24 : 0, top: 2),
            child: Text(
              subtitle!,
              style: TextStyle(
                fontSize: 11,
                color: subtitleColor.withValues(alpha: dimmed),
              ),
            ),
          ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: accent.withValues(alpha: dimmed),
            inactiveTrackColor: subtitleColor.withValues(alpha: dimmed * 0.25),
            thumbColor: accent.withValues(alpha: dimmed),
            overlayColor: accent.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value.clamp(0, max),
            min: 0,
            max: max,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 13, color: Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    warning!,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.35,
                      color: Color(0xFFB45309),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
