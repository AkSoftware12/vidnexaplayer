import '../../entities/video_search_query.dart';
import '../keyword_dictionary.dart';
import 'query_extractor.dart';

/// "5 minute se zyada videos" / "5 minute se lambi videos" -> minDuration = 5m.
/// "2 minute se choti videos" -> maxDuration = 2m.
/// "lambi videos" (no number) -> minDuration = 10 minutes default threshold.
class DurationExtractor with DirectionScan implements QueryExtractor {
  static const _secondsPerUnit = {'s': 1, 'm': 60, 'h': 3600};

  @override
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  ) {
    for (var i = 0; i < tokens.length - 1; i++) {
      if (consumed[i] || consumed[i + 1]) continue;
      final value = tryParseNumber(tokens[i]);
      if (value == null) continue;
      final unit = VoiceKeywords.durationUnits[tokens[i + 1]];
      if (unit == null) continue;

      consumed[i] = true;
      consumed[i + 1] = true;

      final seconds = (value * _secondsPerUnit[unit]!).round();
      final duration = Duration(seconds: seconds);

      final directionIndex = findDirectionWord(
        tokens,
        consumed,
        i + 2,
        VoiceKeywords.directionConnector,
        VoiceKeywords.durationGreaterWords,
        VoiceKeywords.durationSmallerWords,
      );

      if (directionIndex != -1) {
        consumed[directionIndex] = true;
        final isSmaller =
            VoiceKeywords.durationSmallerWords.contains(tokens[directionIndex]);
        return isSmaller
            ? query.copyWith(maxDuration: duration)
            : query.copyWith(minDuration: duration);
      }

      // No explicit direction word ("5 minute videos") — treat as "at least".
      return query.copyWith(minDuration: duration);
    }

    // Bare qualitative form: "lambi videos" — duration-specific words only;
    // "choti"/"chota" are deliberately NOT treated as duration here since the
    // size extractor (which runs first) already claims them for file size.
    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i]) continue;
      if (VoiceKeywords.durationGreaterWords.contains(tokens[i])) {
        consumed[i] = true;
        return query.copyWith(minDuration: VoiceKeywords.defaultDurationThreshold);
      }
    }

    return query;
  }
}
