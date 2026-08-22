import '../entities/video_search_query.dart';
import 'extractors/date_extractor.dart';
import 'extractors/duration_extractor.dart';
import 'extractors/extension_extractor.dart';
import 'extractors/folder_extractor.dart';
import 'extractors/media_kind_extractor.dart';
import 'extractors/query_extractor.dart';
import 'extractors/size_extractor.dart';
import 'extractors/text_extractor.dart';

/// Turns a recognised speech string (Hindi / Hinglish / English) into a
/// structured [VideoSearchQuery].
///
/// Runs a fixed pipeline of small, single-purpose extractors over the
/// tokenised input. Each extractor claims the tokens it recognises and
/// leaves the rest for the next one — that's what makes combined commands
/// ("Downloads folder me 1 GB se badi MP4 videos dikhao") work without any
/// extra combinatorial logic: every clause is just another extractor finding
/// its own tokens in the same pass.
///
/// Entirely offline — no network call, no external NLP service.
class VoiceCommandParser {
  VoiceCommandParser({DateTime Function()? now})
      : _pipeline = [
          // Runs first: decides whether this is a video/photo/music search
          // at all, before anything else can misinterpret "photo"/"mp3".
          MediaKindExtractor(),
          ExtensionExtractor(),
          // Duration before Size: "choti"/"chota" is a bare qualitative word
          // both extractors recognise (short duration vs. small file size).
          // Running Duration first lets it claim "2 minute se choti" — a
          // number+duration-unit anchored match — before Size's *bare*
          // (no-number) fallback would otherwise grab the leftover "choti".
          DurationExtractor(),
          SizeExtractor(),
          DateExtractor(now: now),
          FolderExtractor(),
          // Must run last: it strips fillers and claims whatever is left.
          TextExtractor(),
        ];

  final List<QueryExtractor> _pipeline;

  VideoSearchQuery parse(String rawText) {
    final tokens = _tokenize(rawText);
    if (tokens.isEmpty) return VideoSearchQuery.empty;

    final consumed = List<bool>.filled(tokens.length, false);
    var query = VideoSearchQuery.empty;

    for (final extractor in _pipeline) {
      query = extractor.extract(tokens, consumed, query);
    }

    return query;
  }

  static List<String> _tokenize(String rawText) {
    var normalized = rawText.toLowerCase().trim();

    // Protect decimal points inside numbers ("1.5gb") before stripping
    // punctuation, then strip everything that isn't a word char/whitespace.
    normalized = normalized
        .replaceAllMapped(
          RegExp(r'(\d)\.(\d)'),
          (m) => '${m[1]}DECIMALPOINT${m[2]}',
        )
        .replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ')
        .replaceAll('DECIMALPOINT', '.');

    return normalized
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList(growable: false);
  }
}
