import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/media_kind.dart';
import '../models/video_index_entry.dart';

/// Shared `photo_manager` walking logic used by both the video and photo
/// scanners — the only difference between scanning videos and photos is the
/// `RequestType` passed to `photo_manager` and the [MediaKind] tag written
/// into each row, so this is the one place that logic lives.
///
/// `photo_manager`'s platform-channel calls only work on the root isolate,
/// so scanning runs here on the main isolate — kept safe for the UI by
/// working in small batches and yielding to the event loop between them.
class PhotoManagerScanner {
  PhotoManagerScanner({
    required this.requestType,
    required this.mediaKind,
    required this.defaultExtension,
  });

  static const _pageSize = 200;

  final RequestType requestType;
  final MediaKind mediaKind;
  final String defaultExtension;

  Future<bool> hasPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return state.isAuth || state.hasAccess;
  }

  /// Cheap total count, used only to decide whether a resync is worth doing.
  Future<int> currentCount() async {
    if (!await hasPermission()) return 0;
    final paths = await PhotoManager.getAssetPathList(
      type: requestType,
      onlyAll: true,
    );
    if (paths.isEmpty) return 0;
    return paths.first.assetCountAsync;
  }

  /// Walks every matching asset the device exposes, page by page.
  ///
  /// [onBatch] is called once per page with cheap metadata immediately
  /// (unlocks name/folder/date/duration/extension search right away) and
  /// then again with the same entries carrying a resolved [fileSizeBytes]
  /// shortly after (unlocks size-based search) — the "two-phase" indexing
  /// described in the plan: phase 1 is synchronous asset fields, phase 2 is
  /// the one field that needs a disk stat per file.
  ///
  /// Returns `null` if the scan could not run at all (no permission) so the
  /// caller can tell that apart from "ran and found zero items" — the
  /// former must never be treated as "delete everything from the index".
  Future<Set<String>?> scan({
    required Future<void> Function(List<VideoIndexEntry> entries) onBatch,
    void Function(int done, int total)? onProgress,
  }) async {
    if (!await hasPermission()) return null;

    final seenIds = <String>{};
    final paths = await PhotoManager.getAssetPathList(
      type: requestType,
      onlyAll: true,
    );
    if (paths.isEmpty) return seenIds;

    final all = paths.first;
    final total = await all.assetCountAsync;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var start = 0; start < total; start += _pageSize) {
      final end = (start + _pageSize > total) ? total : start + _pageSize;
      final assets = await all.getAssetListRange(start: start, end: end);

      // Phase 1: metadata already on the AssetEntity, no file I/O.
      final entries = assets.map((a) => _toEntry(a, now)).toList();
      for (final e in entries) {
        seenIds.add(e.id);
      }
      await onBatch(entries);
      onProgress?.call(seenIds.length, total);

      // Phase 2: resolve real byte size for this same batch while the
      // AssetEntity objects are already in memory (avoids a second
      // id->properties round trip later).
      final sized = <VideoIndexEntry>[];
      for (var i = 0; i < assets.length; i++) {
        final bytes = await _resolveSizeBytes(assets[i]);
        if (bytes != null) sized.add(_toEntry(assets[i], now, sizeBytes: bytes));
      }
      if (sized.isNotEmpty) await onBatch(sized);

      // Yield back to the event loop between pages.
      await Future.delayed(Duration.zero);
    }

    return seenIds;
  }

  Future<int?> _resolveSizeBytes(AssetEntity asset) async {
    try {
      final file = await asset.file;
      if (file == null || !await file.exists()) return null;
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  VideoIndexEntry _toEntry(AssetEntity asset, int indexedAt, {int? sizeBytes}) {
    final title = asset.title?.trim().isNotEmpty == true
        ? asset.title!.trim()
        : '${asset.id}.$defaultExtension';
    final relativePath = asset.relativePath;
    final folderName = _folderNameFromRelativePath(relativePath);

    return VideoIndexEntry(
      sourceId: asset.id,
      mediaKind: mediaKind,
      fileName: title,
      filePath: relativePath == null ? null : '$relativePath$title',
      folderName: folderName,
      folderPath: relativePath,
      fileSizeBytes: sizeBytes,
      durationMs: asset.videoDuration.inMilliseconds,
      createdAt: asset.createDateTime.millisecondsSinceEpoch,
      modifiedAt: asset.modifiedDateTime.millisecondsSinceEpoch,
      mimeType: asset.mimeType,
      extension: VideoIndexEntry.extensionOf(title),
      width: asset.width,
      height: asset.height,
      indexedAt: indexedAt,
    );
  }

  static String? _folderNameFromRelativePath(String? relativePath) {
    if (relativePath == null || relativePath.isEmpty) return null;
    final parts = relativePath.split('/').where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.last;
  }
}
