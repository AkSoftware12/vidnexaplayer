import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/equalizer_strings.dart';
import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../domain/eq_models.dart';
import '../../domain/eq_presets.dart';
import '../../domain/eq_profile.dart';

/// Horizontal preset strip. Video presets (Movie / Dialogue Clarity / Night /
/// Podcast) sort to the front for the video player — dialogue intelligibility
/// is the thing this player is meant to be good at, and it should not be
/// buried between Jazz and Metal.
class PresetCarousel extends StatelessWidget {
  const PresetCarousel({
    super.key,
    required this.mediaType,
    required this.selectedId,
    required this.onSelect,
    required this.accent,
    required this.cardColor,
    required this.textColor,
    required this.subtleColor,
    this.profiles = const [],
    this.onSelectProfile,
    this.enabled = true,
  });

  final MediaType mediaType;
  final String selectedId;
  final ValueChanged<EqPreset> onSelect;
  final Color accent;
  final Color cardColor;
  final Color textColor;
  final Color subtleColor;

  /// Saved profiles are shown first, ahead of the built-ins — the user's own
  /// "Gym" is what they reach for, not "Classical".
  final List<EqProfile> profiles;
  final ValueChanged<EqProfile>? onSelectProfile;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final presets = EqPresets.orderedFor(mediaType);
    // Preset names live in the string table, not on the model — resolve once
    // per build rather than per chip.
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => EqStrings.t(lang, key);

    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        children: [
          for (final profile in profiles)
            _Chip(
              icon: Icons.bookmark_rounded,
              label: profile.name,
              subtitle: t('eq_saved'),
              selected: selectedId == profile.id,
              accent: accent,
              cardColor: cardColor,
              textColor: textColor,
              subtleColor: subtleColor,
              enabled: enabled,
              onTap: () => onSelectProfile?.call(profile),
            ),
          if (profiles.isNotEmpty)
            Container(
              width: 1,
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 18),
              color: subtleColor.withValues(alpha: 0.25),
            ),
          for (final preset in presets)
            _Chip(
              icon: preset.icon,
              label: t(preset.nameKey),
              subtitle: preset.hasSubtitle ? t(preset.subtitleKey) : null,
              highlighted: preset.category == PresetCategory.video &&
                  mediaType == MediaType.video,
              selected: selectedId == preset.id,
              accent: accent,
              cardColor: cardColor,
              textColor: textColor,
              subtleColor: subtleColor,
              enabled: enabled,
              onTap: () => onSelect(preset),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.accent,
    required this.cardColor,
    required this.textColor,
    required this.subtleColor,
    required this.onTap,
    required this.enabled,
    this.subtitle,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool selected;
  final bool highlighted;
  final Color accent;
  final Color cardColor;
  final Color textColor;
  final Color subtleColor;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final dim = enabled ? 1.0 : 0.45;

    return Opacity(
      opacity: dim,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        child: Material(
          color: selected ? accent.withValues(alpha: 0.14) : cardColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            child: Container(
              width: 92,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected
                      ? accent
                      : highlighted
                          ? accent.withValues(alpha: 0.35)
                          : subtleColor.withValues(alpha: 0.18),
                  width: selected ? 1.6 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 19,
                    color: selected ? accent : textColor.withValues(alpha: 0.75),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      height: 1.1,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? accent : textColor,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8.5,
                        height: 1.2,
                        color: subtleColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
