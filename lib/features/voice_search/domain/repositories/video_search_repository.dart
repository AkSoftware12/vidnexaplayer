import '../entities/media_kind.dart';
import '../entities/video_entity.dart';
import '../entities/video_search_query.dart';

/// Storage-agnostic contract for the local media index (video/photo/music).
///
/// Implemented by `VideoSearchRepositoryImpl` (data layer) on top of sqflite +
/// `photo_manager` + `on_audio_query_forked`. Kept abstract so the
/// parser/controller can be unit tested against a fake without touching real
/// plugin channels.
///
/// [id] parameters below are the *source* id (the id `photo_manager`'s
/// `AssetEntity` or `on_audio_query_forked`'s `SongModel` uses) — always
/// paired with [MediaKind] because video/photo/music ids are drawn from
/// independent MediaStore sequences and can collide numerically.
abstract class VideoSearchRepository {
  /// Runs [query] against the local index. Never touches storage/plugins
  /// directly — purely reads whatever has already been indexed.
  Future<List<VideoEntity>> search(
    VideoSearchQuery query, {
    int offset = 0,
    int limit = 40,
  });

  /// True once at least one indexing pass has completed.
  Future<bool> isIndexReady();

  /// Number of rows currently in the index (for diagnostics / rescan UI).
  Future<int> indexedCount();

  /// (Re)builds the local index from the device's videos, photos and music.
  /// Safe to call repeatedly — inserts/updates/removes are diffed against
  /// the existing index rather than wiping and rebuilding it.
  Future<void> rebuildIndex({void Function(int done, int total)? onProgress});

  /// Looks up a single indexed item by kind + id, e.g. to resolve a stale
  /// row before playback.
  Future<VideoEntity?> findById(MediaKind kind, String id);

  /// Drops a row that no longer points at a real file on disk.
  Future<void> removeStaleEntry(MediaKind kind, String id);
}
