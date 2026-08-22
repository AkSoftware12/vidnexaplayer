import '../../entities/video_search_query.dart';
import '../keyword_dictionary.dart';
import 'query_extractor.dart';

/// "1 GB se badi videos" -> minSizeBytes = 1GB.
/// "500 MB se choti videos" -> maxSizeBytes = 500MB.
/// "badi videos" (no number) -> minSizeBytes = 100MB default threshold.
class SizeExtractor with DirectionScan implements QueryExtractor {
  @override
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  ) {
    // Numeric form: "<number> <gb|mb|kb> [se] [badi|choti|...]".
    for (var i = 0; i < tokens.length - 1; i++) {
      if (consumed[i] || consumed[i + 1]) continue;
      final value = tryParseNumber(tokens[i]);
      if (value == null) continue;
      final unit = VoiceKeywords.sizeUnits[tokens[i + 1]];
      if (unit == null) continue;

      consumed[i] = true;
      consumed[i + 1] = true;

      final bytes = (value * VoiceKeywords.sizeUnitToBytes[unit]!).round();

      final directionIndex = findDirectionWord(
        tokens,
        consumed,
        i + 2,
        VoiceKeywords.directionConnector,
        VoiceKeywords.sizeGreaterWords,
        VoiceKeywords.sizeSmallerWords,
      );

      if (directionIndex != -1) {
        consumed[directionIndex] = true;
        final isSmaller = VoiceKeywords.sizeSmallerWords.contains(tokens[directionIndex]);
        return isSmaller
            ? query.copyWith(maxSizeBytes: bytes)
            : query.copyWith(minSizeBytes: bytes);
      }

      // No explicit direction word ("1 GB videos") — treat as "at least".
      return query.copyWith(minSizeBytes: bytes);
    }

    // Bare qualitative form: "badi videos" / "choti videos" — no number at all.
    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i]) continue;
      final t = tokens[i];
      if (VoiceKeywords.sizeGreaterWords.contains(t)) {
        consumed[i] = true;
        return query.copyWith(minSizeBytes: VoiceKeywords.defaultSizeThresholdBytes);
      }
      if (VoiceKeywords.sizeSmallerWords.contains(t)) {
        consumed[i] = true;
        return query.copyWith(maxSizeBytes: VoiceKeywords.defaultSizeThresholdBytes);
      }
    }

    return query;
  }
}
