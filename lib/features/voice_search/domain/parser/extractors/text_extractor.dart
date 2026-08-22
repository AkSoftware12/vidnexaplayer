import '../../entities/video_search_query.dart';
import '../keyword_dictionary.dart';
import 'query_extractor.dart';

/// Final pipeline step: strips filler/connector words, then whatever tokens
/// remain (e.g. "birthday", "salman") become the filename search text.
///
/// Must run last — every other extractor should get a chance to claim its
/// tokens first, otherwise a folder/date/size word that hasn't been consumed
/// yet would leak into the free-text search.
class TextExtractor implements QueryExtractor {
  @override
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  ) {
    for (var i = 0; i < tokens.length; i++) {
      if (!consumed[i] && VoiceKeywords.stopwords.contains(tokens[i])) {
        consumed[i] = true;
      }
    }

    final remaining = [
      for (var i = 0; i < tokens.length; i++)
        if (!consumed[i]) tokens[i],
    ];

    if (remaining.isEmpty) return query;
    return query.copyWith(text: remaining.join(' '));
  }
}
