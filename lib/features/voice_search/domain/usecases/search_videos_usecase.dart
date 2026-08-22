import '../entities/video_entity.dart';
import '../entities/video_search_query.dart';
import '../repositories/video_search_repository.dart';

/// Runs a parsed [VideoSearchQuery] against the local index.
class SearchVideosUseCase {
  const SearchVideosUseCase(this._repository);

  final VideoSearchRepository _repository;

  Future<List<VideoEntity>> call(
    VideoSearchQuery query, {
    int offset = 0,
    int limit = 40,
  }) {
    return _repository.search(query, offset: offset, limit: limit);
  }
}
