import '../../entities/media_kind.dart';
import '../../entities/video_search_query.dart';
import '../keyword_dictionary.dart';
import 'query_extractor.dart';

/// Switches the search target away from the default (video) when the
/// command explicitly names a photo/image or an mp3/song.
///
/// Must run before [TextExtractor] (like every other extractor) so "photo"/
/// "mp3" don't leak into the free-text filename filter instead of setting
/// [VideoSearchQuery.mediaKind]. Runs before the extension extractor too,
/// since video extension words never overlap with these, so order between
/// the two doesn't otherwise matter.
class MediaKindExtractor implements QueryExtractor {
  @override
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  ) {
    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i]) continue;
      final t = tokens[i];

      if (VoiceKeywords.photoWords.contains(t)) {
        consumed[i] = true;
        return query.copyWith(mediaKind: MediaKind.photo);
      }
      if (VoiceKeywords.musicWords.contains(t)) {
        consumed[i] = true;
        return query.copyWith(mediaKind: MediaKind.music);
      }
    }
    return query;
  }
}
