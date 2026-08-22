import '../../entities/video_search_query.dart';

/// One unit of the voice command parsing pipeline.
///
/// Each extractor scans the token list once, claims (marks `consumed`) the
/// tokens it recognises, and returns [query] updated with whatever it found.
/// Tokens already consumed by an earlier extractor must be left alone —
/// extractors run in a fixed order (see `VoiceCommandParser`) precisely so
/// later ones never re-interpret tokens an earlier one already used.
///
/// Adding a new spoken command is: implement this interface, add one line to
/// the pipeline list in `VoiceCommandParser`.
abstract class QueryExtractor {
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  );
}

/// Shared helpers for extractors that look for "<number> se <direction>"
/// style clauses (used by size and duration).
mixin DirectionScan {
  /// Looks ahead from [start] (inclusive) for a direction word from
  /// [greaterWords] or [smallerWords], skipping over connector words
  /// (e.g. "se") and already-consumed tokens. Returns the matched word's
  /// index, or -1 if none was found within [maxLookahead] tokens.
  int findDirectionWord(
    List<String> tokens,
    List<bool> consumed,
    int start,
    Set<String> connectors,
    Set<String> greaterWords,
    Set<String> smallerWords, {
    int maxLookahead = 3,
  }) {
    var scanned = 0;
    for (var i = start; i < tokens.length && scanned < maxLookahead; i++, scanned++) {
      if (consumed[i]) continue;
      final t = tokens[i];
      if (connectors.contains(t)) continue;
      if (greaterWords.contains(t) || smallerWords.contains(t)) return i;
      // Any other real word breaks the "value <connector> direction" chain.
      return -1;
    }
    return -1;
  }
}

double? tryParseNumber(String token) => double.tryParse(token);
