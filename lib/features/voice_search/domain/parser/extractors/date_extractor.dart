import '../../entities/video_search_query.dart';
import '../keyword_dictionary.dart';
import 'query_extractor.dart';

/// "aaj ki videos" / "today videos" -> today's range.
/// "kal ki videos" / "yesterday videos" -> yesterday's range.
/// "parso ki videos" -> the day before yesterday.
/// "last week ki videos" / "pichle hafte ki videos" -> last 7 days.
/// "recent videos" / "latest videos" -> last 30 days, newest first.
class DateExtractor implements QueryExtractor {
  DateExtractor({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  @override
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  ) {
    // Multi-word phrases first, so e.g. "last" isn't swallowed by a future
    // single-word rule before "last week" gets a chance to match as a pair.
    for (final phrase in VoiceKeywords.lastWeekPhrases) {
      for (var i = 0; i < tokens.length - 1; i++) {
        if (consumed[i] || consumed[i + 1]) continue;
        if (tokens[i] == phrase[0] && tokens[i + 1] == phrase[1]) {
          consumed[i] = true;
          consumed[i + 1] = true;
          final now = _now();
          return query.copyWith(
            fromDate: _startOfDay(now.subtract(const Duration(days: 7))),
            toDate: now,
          );
        }
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i]) continue;
      final t = tokens[i];

      if (VoiceKeywords.todayWords.contains(t)) {
        consumed[i] = true;
        final now = _now();
        return query.copyWith(fromDate: _startOfDay(now), toDate: now);
      }

      if (VoiceKeywords.yesterdayWords.contains(t)) {
        consumed[i] = true;
        final yesterday = _now().subtract(const Duration(days: 1));
        return query.copyWith(
          fromDate: _startOfDay(yesterday),
          toDate: _endOfDay(yesterday),
        );
      }

      if (VoiceKeywords.dayBeforeYesterdayWords.contains(t)) {
        consumed[i] = true;
        final day = _now().subtract(const Duration(days: 2));
        return query.copyWith(
          fromDate: _startOfDay(day),
          toDate: _endOfDay(day),
        );
      }

      if (VoiceKeywords.recentWords.contains(t)) {
        consumed[i] = true;
        final now = _now();
        return query.copyWith(
          fromDate: now.subtract(const Duration(days: 30)),
          sortBy: VideoSortOrder.dateDesc,
        );
      }
    }

    return query;
  }
}
