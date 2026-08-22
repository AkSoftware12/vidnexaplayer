import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/media_kind.dart';
import '../models/video_index_entry.dart';
import 'photo_manager_scanner.dart';

/// Talks to `photo_manager` for videos — reuses the exact same plugin the
/// rest of the app (`home2.dart`, `video_list.dart`, `DirectoryFolder`)
/// already uses to enumerate videos, so indexing sees exactly what the
/// existing browse UI sees and never touches raw MediaStore/ContentResolver
/// itself. See [PhotoManagerScanner] for the shared walking logic.
class VideoScannerDatasource {
  final PhotoManagerScanner _scanner = PhotoManagerScanner(
    requestType: RequestType.video,
    mediaKind: MediaKind.video,
    defaultExtension: 'mp4',
  );

  Future<bool> hasPermission() => _scanner.hasPermission();

  Future<int> currentVideoCount() => _scanner.currentCount();

  Future<Set<String>?> scan({
    required Future<void> Function(List<VideoIndexEntry> entries) onBatch,
    void Function(int done, int total)? onProgress,
  }) =>
      _scanner.scan(onBatch: onBatch, onProgress: onProgress);
}
