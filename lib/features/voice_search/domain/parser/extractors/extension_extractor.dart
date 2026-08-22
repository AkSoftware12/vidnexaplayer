import '../../entities/video_search_query.dart';
import '../keyword_dictionary.dart';
import 'query_extractor.dart';

/// "MP4 videos dikhao", "MKV wali videos" -> extension = mp4 / mkv.
class ExtensionExtractor implements QueryExtractor {
  @override
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  ) {
    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i]) continue;
      final ext = VoiceKeywords.extensionWords[tokens[i]];
      if (ext != null) {
        consumed[i] = true;
        return query.copyWith(extension: ext);
      }
    }
    return query;
  }
}
