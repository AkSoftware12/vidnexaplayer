import '../../../voice_search/domain/parser/voice_command_parser.dart';
import '../entities/gallery_query.dart';

/// Turns typed or spoken text into a [GalleryQuery].
///
/// Photo-only facets — colour, orientation, source, brightness — are matched
/// and **removed** here first; whatever is left goes to
/// `VoiceCommandParser`, which already understands dates, folders, sizes and
/// extensions in English, Hindi and Hinglish and is reused wholesale rather
/// than reimplemented.
///
/// Stripping before delegating matters: `VoiceCommandParser` ends its pipeline
/// with a text extractor that claims every unrecognised token as a filename
/// search. Leave "red" in the string and a colour query turns into a hunt for
/// files named "red", which matches nothing and looks broken.
class GalleryQueryParser {
  GalleryQueryParser({DateTime Function()? now})
      : _base = VoiceCommandParser(now: now);

  final VoiceCommandParser _base;

  /// Keyword → facet, in English and Hindi/Hinglish.
  ///
  /// Multi-word keys are matched before single words, so "black and white"
  /// cannot be half-consumed by "black".
  static const Map<String, PhotoColor> _colors = {
    'red': PhotoColor.red,
    'लाल': PhotoColor.red,
    'laal': PhotoColor.red,
    'orange': PhotoColor.orange,
    'नारंगी': PhotoColor.orange,
    'yellow': PhotoColor.yellow,
    'पीला': PhotoColor.yellow,
    'peela': PhotoColor.yellow,
    'green': PhotoColor.green,
    'हरा': PhotoColor.green,
    'hara': PhotoColor.green,
    'cyan': PhotoColor.cyan,
    'teal': PhotoColor.cyan,
    'blue': PhotoColor.blue,
    'नीला': PhotoColor.blue,
    'neela': PhotoColor.blue,
    'purple': PhotoColor.purple,
    'बैंगनी': PhotoColor.purple,
    'violet': PhotoColor.purple,
    'pink': PhotoColor.pink,
    'गुलाबी': PhotoColor.pink,
    'gulabi': PhotoColor.pink,
  };

  static const Map<String, PhotoOrientation> _orientations = {
    'portrait': PhotoOrientation.portrait,
    'vertical': PhotoOrientation.portrait,
    'खड़ी': PhotoOrientation.portrait,
    'landscape': PhotoOrientation.landscape,
    'horizontal': PhotoOrientation.landscape,
    'चौड़ी': PhotoOrientation.landscape,
    'wide': PhotoOrientation.landscape,
    'square': PhotoOrientation.square,
    'चौकोर': PhotoOrientation.square,
  };

  static const Map<String, PhotoSource> _sources = {
    'screenshot': PhotoSource.screenshots,
    'screenshots': PhotoSource.screenshots,
    'स्क्रीनशॉट': PhotoSource.screenshots,
    'whatsapp': PhotoSource.whatsapp,
    'व्हाट्सएप': PhotoSource.whatsapp,
    'telegram': PhotoSource.telegram,
    'download': PhotoSource.downloads,
    'downloads': PhotoSource.downloads,
    'डाउनलोड': PhotoSource.downloads,
    'camera': PhotoSource.camera,
    'कैमरा': PhotoSource.camera,
    'selfie': PhotoSource.camera,
  };

  static const Map<String, PhotoTone> _tones = {
    'dark': PhotoTone.dark,
    'डार्क': PhotoTone.dark,
    'अंधेरा': PhotoTone.dark,
    'night': PhotoTone.dark,
    'bright': PhotoTone.bright,
    'light': PhotoTone.bright,
    'उजाला': PhotoTone.bright,
  };

  GalleryQuery parse(String rawText) {
    var remaining = ' ${rawText.toLowerCase().trim()} ';
    if (remaining.trim().isEmpty) return GalleryQuery.empty;

    PhotoColor? color;
    PhotoOrientation? orientation;
    PhotoTone? tone;
    Set<PhotoSource> sources;

    (remaining, color) = _claim(remaining, _colors);
    (remaining, orientation) = _claim(remaining, _orientations);
    // Every source keyword, not just the first. Stopping at one left the rest
    // in the string, where the delegated parser's folder extractor claimed
    // them — "whatsapp screenshots" became source=screenshots AND
    // folder=whatsapp, an intersection no photo on Android can satisfy.
    (remaining, sources) = _claimAll(remaining, _sources);
    (remaining, tone) = _claim(remaining, _tones);

    final base = _base.parse(remaining);

    return GalleryQuery(
      // `VoiceCommandParser` returns an empty string rather than null when its
      // text extractor found nothing left to claim.
      text: (base.text?.trim().isEmpty ?? true) ? null : base.text!.trim(),
      folder: base.folder,
      extension: base.extension,
      fromDate: base.fromDate,
      toDate: base.toDate,
      minSizeBytes: base.minSizeBytes,
      maxSizeBytes: base.maxSizeBytes,
      orientation: orientation,
      sources: sources,
      tone: tone,
      color: color,
    );
  }

  /// Like [_claim], but keeps going until no keyword matches — used where a
  /// facet legitimately takes several values at once.
  (String, Set<T>) _claimAll<T>(String haystack, Map<String, T> table) {
    final found = <T>{};
    var text = haystack;
    while (true) {
      final (next, match) = _claim(text, table);
      if (match == null) return (text, found);
      found.add(match);
      text = next;
    }
  }

  /// Finds the first keyword from [table] in [haystack], removes it, and
  /// returns the shortened text alongside the facet it mapped to.
  ///
  /// Longest keys first so a longer phrase always wins over a shorter one it
  /// contains. Matching is whole-word — bounded by the spaces this method's
  /// caller padded the string with — so "downloads" does not fire on
  /// "downloadsomething".
  (String, T?) _claim<T>(String haystack, Map<String, T> table) {
    final keys = table.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final key in keys) {
      final needle = ' $key ';
      final index = haystack.indexOf(needle);
      if (index < 0) continue;
      final stripped = haystack.replaceFirst(needle, ' ');
      return (stripped, table[key]);
    }
    return (haystack, null);
  }
}
