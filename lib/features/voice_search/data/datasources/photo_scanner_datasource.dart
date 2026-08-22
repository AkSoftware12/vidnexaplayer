import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/media_kind.dart';
import '../models/video_index_entry.dart';
import 'photo_manager_scanner.dart';

/// Talks to `photo_manager` for photos — same plugin `lib/Photo/image_album.dart`
/// already uses to browse images. See [PhotoManagerScanner] for the shared
/// walking logic (images just have no meaningful `videoDuration`, which
/// naturally comes back as zero).
class PhotoScannerDatasource {
  final PhotoManagerScanner _scanner = PhotoManagerScanner(
    requestType: RequestType.image,
    mediaKind: MediaKind.photo,
    defaultExtension: 'jpg',
  );

  Future<bool> hasPermission() => _scanner.hasPermission();

  Future<int> currentPhotoCount() => _scanner.currentCount();

  Future<Set<String>?> scan({
    required Future<void> Function(List<VideoIndexEntry> entries) onBatch,
    void Function(int done, int total)? onProgress,
  }) =>
      _scanner.scan(onBatch: onBatch, onProgress: onProgress);
}
