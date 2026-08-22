import '../repositories/video_search_repository.dart';

/// (Re)builds the local video index. Used by `VideoIndexService` on a
/// background schedule and by the search page's explicit "Rescan" action —
/// never by the search flow itself, which only ever reads the index.
class IndexVideosUseCase {
  const IndexVideosUseCase(this._repository);

  final VideoSearchRepository _repository;

  Future<void> call({void Function(int done, int total)? onProgress}) {
    return _repository.rebuildIndex(onProgress: onProgress);
  }
}
