/// The one-tap looks offered by the filter tool.
///
/// Each is a fixed recipe of the same handful of colour operations — there is
/// no magic here, and naming them after the look rather than the maths is the
/// point. [hdr] is the one worth being careful about: it is a *look* built
/// from lifted shadows, local contrast and extra saturation, not real high
/// dynamic range, because a JPEG has already thrown that away.
enum PhotoFilter {
  original,
  blackWhite,
  mono,
  sepia,
  hdr,
  vivid,
  warm,
  cool,
  dark,
  bright,
  fade,
  vintage;

  String get labelKey => 'gallery_filter_$name';
}

/// Manual adjustments applied on top of whichever [PhotoFilter] is chosen.
///
/// Stored in a friendly −100…100 range rather than the image library's own
/// units, so the sliders mean the same thing to a person as they do in the
/// code. The worker maps them to real multipliers.
class FilterAdjustments {
  const FilterAdjustments({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.warmth = 0,
  });

  static const none = FilterAdjustments();

  /// −100 (dark) … 0 (unchanged) … 100 (bright).
  final int brightness;

  /// −100 (flat) … 0 … 100 (punchy).
  final int contrast;

  /// −100 (grey) … 0 … 100 (vivid).
  final int saturation;

  /// −100 (cool/blue) … 0 … 100 (warm/orange).
  final int warmth;

  bool get isNeutral =>
      brightness == 0 && contrast == 0 && saturation == 0 && warmth == 0;

  FilterAdjustments copyWith({
    int? brightness,
    int? contrast,
    int? saturation,
    int? warmth,
  }) =>
      FilterAdjustments(
        brightness: brightness ?? this.brightness,
        contrast: contrast ?? this.contrast,
        saturation: saturation ?? this.saturation,
        warmth: warmth ?? this.warmth,
      );
}
