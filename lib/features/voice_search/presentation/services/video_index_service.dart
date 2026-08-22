import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/audio_scanner_datasource.dart';
import '../../data/datasources/photo_scanner_datasource.dart';
import '../../data/datasources/video_scanner_datasource.dart';
import '../../data/repositories/video_search_repository_impl.dart';
import '../../domain/repositories/video_search_repository.dart';
import '../../domain/usecases/index_videos_usecase.dart';

/// App-level singleton that schedules background indexing.
///
/// Not a `ChangeNotifier` — nothing observes it directly, it just keeps the
/// local index reasonably fresh. Called once (fire-and-forget) from
/// `home_bottomNavigation.dart`'s `initState`, and again, explicitly, from
/// the search page's "Rescan" action. Voice search itself never triggers a
/// scan — it only ever reads whatever this has already indexed.
class VideoIndexService {
  VideoIndexService._();

  static final VideoIndexService instance = VideoIndexService._();

  static const _lastScanKey = 'voice_search_last_full_scan_epoch_ms';
  static const _throttle = Duration(hours: 6);

  /// Shared with `VoiceSearchPage` so both read/write the same index.
  final VideoSearchRepository repository = VideoSearchRepositoryImpl();

  late final IndexVideosUseCase _indexUseCase = IndexVideosUseCase(repository);
  final VideoScannerDatasource _videoScanner = VideoScannerDatasource();
  final PhotoScannerDatasource _photoScanner = PhotoScannerDatasource();
  final AudioScannerDatasource _audioScanner = AudioScannerDatasource();

  bool _running = false;

  /// Builds the index if it's empty; otherwise only resyncs when the
  /// device's video/photo/song count has drifted or the last scan is older
  /// than [_throttle]. Never throws, never blocks the caller — safe to call
  /// from `initState`.
  Future<void> ensureIndexed() async {
    if (_running) return;
    _running = true;
    try {
      final indexedCount = await repository.indexedCount();
      if (indexedCount == 0) {
        await _runScan();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastScanMs = prefs.getInt(_lastScanKey);
      final stale = lastScanMs == null ||
          DateTime.now().difference(
                DateTime.fromMillisecondsSinceEpoch(lastScanMs),
              ) >
              _throttle;

      final deviceCount = await _videoScanner.currentVideoCount() +
          await _photoScanner.currentPhotoCount() +
          await _audioScanner.currentSongCount();
      if (deviceCount != indexedCount || stale) {
        await _runScan();
      }
    } catch (e) {
      debugPrint('VideoIndexService.ensureIndexed failed: $e');
    } finally {
      _running = false;
    }
  }

  /// Explicit rescan — e.g. the search page's empty-state "Rescan library".
  Future<void> rescan({void Function(int done, int total)? onProgress}) async {
    if (_running) return;
    _running = true;
    try {
      await _runScan(onProgress: onProgress);
    } finally {
      _running = false;
    }
  }

  Future<void> _runScan({void Function(int done, int total)? onProgress}) async {
    await _indexUseCase(onProgress: onProgress);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);
  }
}
