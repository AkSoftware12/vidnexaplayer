import '../../domain/entities/media_kind.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_search_query.dart';
import '../../domain/repositories/video_search_repository.dart';
import '../datasources/audio_scanner_datasource.dart';
import '../datasources/photo_scanner_datasource.dart';
import '../datasources/video_index_database.dart';
import '../datasources/video_scanner_datasource.dart';
import '../models/video_index_entry.dart';

/// Shape shared by every scanner's `scan()` method — lets [VideoSearchRepositoryImpl]
/// drive all three (video/photo/music) through one helper instead of
/// duplicating the scan-then-diff logic three times.
typedef _ScanFn = Future<Set<String>?> Function({
  required Future<void> Function(List<VideoIndexEntry> entries) onBatch,
  void Function(int done, int total)? onProgress,
});

class VideoSearchRepositoryImpl implements VideoSearchRepository {
  VideoSearchRepositoryImpl({
    VideoIndexDatabase? database,
    VideoScannerDatasource? videoScanner,
    PhotoScannerDatasource? photoScanner,
    AudioScannerDatasource? audioScanner,
  })  : _database = database ?? VideoIndexDatabase(),
        _videoScanner = videoScanner ?? VideoScannerDatasource(),
        _photoScanner = photoScanner ?? PhotoScannerDatasource(),
        _audioScanner = audioScanner ?? AudioScannerDatasource();

  final VideoIndexDatabase _database;
  final VideoScannerDatasource _videoScanner;
  final PhotoScannerDatasource _photoScanner;
  final AudioScannerDatasource _audioScanner;

  @override
  Future<List<VideoEntity>> search(
    VideoSearchQuery query, {
    int offset = 0,
    int limit = 40,
  }) async {
    final rows = await _database.search(query, offset: offset, limit: limit);
    return rows.map((row) => row.toEntity()).toList();
  }

  @override
  Future<bool> isIndexReady() async => (await _database.count()) > 0;

  @override
  Future<int> indexedCount() => _database.count();

  @override
  Future<void> rebuildIndex({void Function(int done, int total)? onProgress}) async {
    // Each kind is scanned and diffed independently — one kind having no
    // permission (`scan` returns `null`) or throwing must neither stop the
    // others from indexing nor make its own untouched rows look "removed".
    await _syncKind(MediaKind.video, _videoScanner.scan, onProgress);
    await _syncKind(MediaKind.photo, _photoScanner.scan, onProgress);
    await _syncKind(MediaKind.music, _audioScanner.scan, onProgress);
  }

  Future<void> _syncKind(
    MediaKind kind,
    _ScanFn scan,
    void Function(int done, int total)? onProgress,
  ) async {
    final seenIds = await scan(
      onBatch: (entries) => _database.upsertAll(entries),
      onProgress: onProgress,
    );
    if (seenIds == null) return;

    final existingIds = await _database.allIds(kind: kind);
    final removed = existingIds.difference(seenIds);
    if (removed.isNotEmpty) await _database.deleteByIds(removed);
  }

  @override
  Future<VideoEntity?> findById(MediaKind kind, String id) async {
    final row = await _database.findById(kind, id);
    return row?.toEntity();
  }

  @override
  Future<void> removeStaleEntry(MediaKind kind, String id) =>
      _database.deleteByIds([VideoIndexEntry.compositeId(kind, id)]);
}
