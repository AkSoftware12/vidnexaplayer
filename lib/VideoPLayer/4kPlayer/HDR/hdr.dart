import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../NotifyListeners/LanguageProvider/video_strings.dart';

/// The player's colour-filter picker, as a full-width bottom sheet.
///
/// Used to be a small centred dialog with a radio list of names — "Neon",
/// "Sepia" — that left the user guessing what each did. Every filter is now
/// a designed preview picture of that look (assets/vidnexa_*_preview.webp),
/// two to a row, so the choice is visual. The pictures carry their own name
/// labels, so the cards add none. Edge to edge: the default Material
/// bottom-sheet width cap (640 dp) is lifted, so there is no gap at the sides
/// in landscape either.
class FilterPopup {
  /// Filters in display order: key, label key (read out by screen readers;
  /// the picture shows the name) and preview picture.
  static const List<(String, String, String)> _filters = [
    ('normal', 'hdr_filter_normal', 'assets/vidnexa_normal_preview.webp'),
    ('hdr', 'hdr_filter_hdr', 'assets/vidnexa_hdr_plus_preview_v2 (1).webp'),
    ('warm', 'hdr_filter_warm', 'assets/vidnexa_warm_hdr_preview.webp'),
    ('dark', 'hdr_filter_dark', 'assets/vidnexa_dark_preview.webp'),
    ('blue', 'hdr_filter_blue', 'assets/vidnexa_blue_effect_preview.webp'),
    ('sepia', 'hdr_filter_sepia', 'assets/vidnexa_sepia_preview.webp'),
    ('neon', 'hdr_filter_neon', 'assets/vidnexa_neon_city_preview.webp'),
    ('green', 'hdr_filter_green',
        'assets/vidnexa_green_effect_card_preview.webp'),
  ];

  /// Shows the sheet. [hdrLocked] marks HDR and Warm HDR as needing an ad — picking it still goes through
  /// [onSelected], which applies the gate.
  static Future<void> show(
    BuildContext context, {
    required String selectedKey,
    required void Function(String key) onSelected,
    bool hdrLocked = false,
  }) {
    final lang =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      // Material caps sheets at 640 dp wide; lift it so the sheet runs edge
      // to edge in landscape too.
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (sheetContext) => _FilterSheet(
        lang: lang,
        selectedKey: selectedKey,
        hdrLocked: hdrLocked,
        onPick: (key) {
          Navigator.pop(sheetContext);
          if (key != selectedKey) onSelected(key);
        },
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.lang,
    required this.selectedKey,
    required this.hdrLocked,
    required this.onPick,
  });

  final String lang;
  final String selectedKey;
  final bool hdrLocked;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    String t(String key) => VideoStrings.t(lang, key);
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    // Selected key "" (HDR just switched off) means the normal picture.
    final selected = selectedKey.isEmpty ? 'normal' : selectedKey;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 8, 6),
            child: Row(
              children: [
                const Icon(Icons.palette_rounded,
                    color: Color(0xFFFF8A00), size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t('player_action_filters'),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('filter_sheet_sub'),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white60,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              // Clear of the gesture bar / nav buttons, plus breathing room
              // so the last row never sits on the screen's bottom edge.
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                // Fixed gap: the full-screen player can hide the nav bar, which
                // zeroes viewPadding, so the gap must not rely on it alone.
                44 + media.viewPadding.bottom,
              ),
              // Two to a row; landscape is wide enough for four.
              crossAxisCount: landscape ? 4 : 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              // Wide, short cards.
              childAspectRatio: 2.8,
              children: [
                for (final (key, labelKey, asset) in FilterPopup._filters)
                  _FilterTile(
                    label: t(labelKey),
                    asset: asset,
                    selected: key == selected,
                    // HDR and Warm HDR share one rewarded unlock.
                    locked: (key == 'hdr' || key == 'warm') && hdrLocked,
                    adLabel: t('filter_ad_tag'),
                    onTap: () => onPick(key),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.label,
    required this.asset,
    required this.selected,
    required this.locked,
    required this.adLabel,
    required this.onTap,
  });

  final String label;
  final String asset;
  final bool selected;
  final bool locked;
  final String adLabel;
  final VoidCallback onTap;

  static const _accent = Color(0xFFFF8A00);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _accent : Colors.white12,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The previews are 2:1 with their name label near the bottom;
              // anchoring to the bottom keeps that label in view on these
              // wider cards. Decoded at card size, not 1774 px, so the eight
              // pictures cost a few MB of memory instead of ~50.
              LayoutBuilder(
                builder: (context, box) => Image.asset(
                  asset,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                  cacheWidth: (box.maxWidth *
                          MediaQuery.of(context).devicePixelRatio)
                      .round()
                      .clamp(200, 900),
                  semanticLabel: label,
                ),
              ),
              if (selected)
                const Positioned(
                  top: 5,
                  right: 5,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: _accent,
                    child: Icon(Icons.check_rounded,
                        size: 13, color: Colors.white),
                  ),
                ),
              if (locked)
                Positioned(
                  top: 5,
                  left: 5,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow_rounded,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          adLabel,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
