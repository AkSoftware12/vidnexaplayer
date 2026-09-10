import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import 'accent_preset.dart';
import 'dark_mode.dart';

/// The Theme block: light / dark / follow-system, plus the accent swatches.
///
/// One widget used from both the drawer and the profile screen, so the two can
/// never drift apart or disagree about what is selected — both read the same
/// [ThemeProvider], and a change made in one is visible in the other
/// immediately.
class ThemeSettingsSection extends StatelessWidget {
  const ThemeSettingsSection({super.key, this.showHeader = true});

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.isDark ? theme.accent.onDarkSeed : theme.accent.seed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Container(
                width: 4.sp,
                height: 15.sp,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2.sp),
                ),
              ),
              SizedBox(width: 9.sp),
              Text(
                'Theme',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.sp),
        ],
        _ModeSelector(current: theme.themeMode, accent: accent),
        SizedBox(height: 12.sp),
        _AccentRow(selected: theme.accent, accent: accent),
      ],
    );
  }
}

/// Light / Dark / System as one segmented pill.
///
/// Three options rather than a switch, because "follow the system" is a real
/// third choice — a toggle can only ever express two, which is why the app
/// used to ignore the device's own dark setting entirely.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.current, required this.accent});

  final ThemeMode current;
  final Color accent;

  static const _options = [
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
    (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ThemeProvider>();
    final borderColour = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.black26;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11.sp),
        border: Border.all(color: borderColour),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          for (final (mode, label, icon) in _options)
            Expanded(
              child: InkWell(
                onTap: () => provider.setMode(mode),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 11.sp),
                  color: mode == current ? accent : Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        mode == current ? Icons.check : icon,
                        size: 15.sp,
                        color: mode == current
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      SizedBox(width: 6.sp),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                            fontWeight: mode == current
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: mode == current
                                ? Colors.white
                                : Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccentRow extends StatelessWidget {
  const _AccentRow({required this.selected, required this.accent});

  final AccentPreset selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ThemeProvider>();

    return Row(
      children: [
        for (final preset in AccentPreset.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => provider.setAccent(preset),
              child: Container(
                height: 58.sp,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: preset.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10.sp),
                  border: Border.all(
                    color: preset == selected
                        ? Colors.white
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                padding: EdgeInsets.all(7.sp),
                alignment: Alignment.bottomLeft,
                child: Text(
                  preset.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5.sp,
                    fontWeight: FontWeight.w500,
                    // Fixed dark text: every gradient here is light enough at
                    // the bottom-left corner that white would disappear.
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
          if (preset != AccentPreset.values.last) SizedBox(width: 8.sp),
        ],
      ],
    );
  }
}
