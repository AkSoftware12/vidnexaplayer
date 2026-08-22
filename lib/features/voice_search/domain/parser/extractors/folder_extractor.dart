import '../../entities/video_search_query.dart';
import '../keyword_dictionary.dart';
import 'query_extractor.dart';

/// "Downloads folder ki videos" / "WhatsApp ki videos" / "Camera videos"
/// -> folder = the canonical folder key, matched later via
/// `folder_name_lower LIKE '%key%'`.
class FolderExtractor implements QueryExtractor {
  @override
  VideoSearchQuery extract(
    List<String> tokens,
    List<bool> consumed,
    VideoSearchQuery query,
  ) {
    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i]) continue;
      final folder = VoiceKeywords.folderAliases[tokens[i]];
      if (folder != null) {
        consumed[i] = true;
        return query.copyWith(folder: folder);
      }
    }
    return query;
  }
}
