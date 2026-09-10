/// Typefaces offered by the text editor.
///
/// Every face here now ships in the APK (`assets/fonts/*.ttf`, declared in
/// pubspec) and renders offline.
///
/// The picker used to offer Anton / Bebas Neue / Lobster / Noto Sans
/// Devanagari through `google_fonts`, which downloads a face on first use.
/// That download is what produced the `_httpFetchFontAndSaveToDevice ->
/// Exception: Failed to load font` and `_HttpClient.getUrl -> SocketException`
/// crashes: on a slow or absent connection the fetch throws inside a build,
/// and there is no catch that can save a widget mid-paint. Nothing is fetched
/// at runtime any more — see `GoogleFonts.config.allowRuntimeFetching = false`
/// in main.dart, which turns any missed call site into a silent fallback
/// instead of a crash.
///
/// [bundled] is kept (rather than deleted) because the picker still reads it,
/// and a future face added from the network would need the flag again.
///
/// [supportsDevanagari] drives the picker: this app ships Hindi, and a font
/// without the script renders tofu boxes. Offering a face that cannot draw
/// what the user typed is worse than offering fewer faces. Poppins covers
/// Devanagari; the three Latin-only faces below do not, so a Hindi overlay is
/// simply not offered them.
enum OverlayFont {
  poppinsBold('PoppinsBold', bundled: true, supportsDevanagari: true),
  poppinsSemiBold('PoppinsSemiBold', bundled: true, supportsDevanagari: true),
  poppinsMedium('PoppinsMedium', bundled: true, supportsDevanagari: true),
  poppinsRegular('PoppinsRegular', bundled: true, supportsDevanagari: true),
  outfit('Outfit', bundled: true, supportsDevanagari: false),
  openSans('OpenSans', bundled: true, supportsDevanagari: false),
  radioCanada('RadioCanada', bundled: true, supportsDevanagari: false);

  const OverlayFont(
    this.family, {
    required this.bundled,
    required this.supportsDevanagari,
  });

  /// Font family name — the pubspec family for bundled faces, the Google
  /// Fonts name for the rest.
  final String family;

  final bool bundled;
  final bool supportsDevanagari;

  String get label => switch (this) {
        OverlayFont.poppinsBold => 'Poppins Bold',
        OverlayFont.poppinsSemiBold => 'Poppins Semi',
        OverlayFont.poppinsMedium => 'Poppins Medium',
        OverlayFont.poppinsRegular => 'Poppins',
        OverlayFont.outfit => 'Outfit',
        OverlayFont.openSans => 'Open Sans',
        OverlayFont.radioCanada => 'Radio Canada',
      };
}

/// One piece of text placed on a photo.
///
/// Position is stored as a fraction of the photo, not in pixels: the editor
/// shows the photo scaled to fit the screen and exports it at full source
/// resolution, and only a normalised position survives that change of scale
/// unchanged.
///
/// Plain fields, no Flutter types — [colorValue] and [strokeColorValue] are
/// ARGB ints rather than `Color` for the same reason the other entities avoid
/// plugin types.
class TextOverlay {
  const TextOverlay({
    required this.id,
    required this.text,
    this.dx = 0.5,
    this.dy = 0.5,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.colorValue = 0xFFFFFFFF,
    this.font = OverlayFont.poppinsBold,
    this.fontSize = 28.0,
    this.strokeWidth = 0.0,
    this.strokeColorValue = 0xFF000000,
    this.hasShadow = true,
    this.opacity = 1.0,
  });

  final String id;
  final String text;

  /// Centre of the text, 0..1 across the photo.
  final double dx;
  final double dy;

  final double scale;

  /// Radians.
  final double rotation;

  final int colorValue;
  final OverlayFont font;

  /// Base size in logical pixels at [scale] 1, measured against the editor's
  /// on-screen photo. Export multiplies it along with everything else.
  final double fontSize;

  final double strokeWidth;
  final int strokeColorValue;
  final bool hasShadow;
  final double opacity;

  /// True when the text contains Devanagari, so the font picker can hide faces
  /// that would render it as tofu.
  bool get needsDevanagari => RegExp(r'[ऀ-ॿ]').hasMatch(text);

  TextOverlay copyWith({
    String? text,
    double? dx,
    double? dy,
    double? scale,
    double? rotation,
    int? colorValue,
    OverlayFont? font,
    double? fontSize,
    double? strokeWidth,
    int? strokeColorValue,
    bool? hasShadow,
    double? opacity,
  }) =>
      TextOverlay(
        id: id,
        text: text ?? this.text,
        dx: dx ?? this.dx,
        dy: dy ?? this.dy,
        scale: scale ?? this.scale,
        rotation: rotation ?? this.rotation,
        colorValue: colorValue ?? this.colorValue,
        font: font ?? this.font,
        fontSize: fontSize ?? this.fontSize,
        strokeWidth: strokeWidth ?? this.strokeWidth,
        strokeColorValue: strokeColorValue ?? this.strokeColorValue,
        hasShadow: hasShadow ?? this.hasShadow,
        opacity: opacity ?? this.opacity,
      );
}
