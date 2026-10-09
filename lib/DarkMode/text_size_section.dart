import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/profile_strings.dart';
import 'dark_mode.dart';
import '../WhatsNew/whats_new.dart';

/// Profile → Text size: four small steps for the whole app's text.
///
/// Laid out like the Light / Dark / System pill above it. Each option shows
/// an "A" at the size it would give, so the choice previews itself; the app
/// re-renders as soon as one is tapped.
class TextSizeSection extends StatelessWidget {
  const TextSizeSection({super.key});

  static const _keys = [
    'profile_text_size_small',
    'profile_text_size_default',
    'profile_text_size_large',
    'profile_text_size_larger',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final accent = theme.isDark ? theme.accent.onDarkSeed : theme.accent.seed;
    final textColour = Theme.of(context).textTheme.bodyMedium?.color;
    final borderColour = Theme.of(context).brightness == Brightness.dark
        ? Colors.white24
        : Colors.black26;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              ProfileStrings.t(lang, 'profile_text_size_title'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(width: 8),
            const NewBadge(NewFeature.textSize),
          ],
        ),
        SizedBox(height: 12.sp),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11.sp),
            border: Border.all(color: borderColour),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              for (var i = 0; i < ThemeProvider.textScales.length; i++)
                Expanded(
                  child: _option(
                    context,
                    scale: ThemeProvider.textScales[i],
                    label: ProfileStrings.t(lang, _keys[i]),
                    selected: theme.textScale == ThemeProvider.textScales[i],
                    accent: accent,
                    textColour: textColour,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _option(
    BuildContext context, {
    required double scale,
    required String label,
    required bool selected,
    required Color accent,
    required Color? textColour,
  }) {
    final colour = selected ? Colors.white : textColour;
    return InkWell(
      onTap: () {
        WhatsNew.instance.markSeen(NewFeature.textSize);
        context.read<ThemeProvider>().setTextScale(scale);
      },
      child: Container(
        height: 58,
        color: selected ? accent : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Unscaled on purpose: each "A" shows its own option's size, not
            // the current one multiplied again.
            Text(
              'A',
              textScaler: TextScaler.noScaling,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 15 * scale,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: colour,
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: colour,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
