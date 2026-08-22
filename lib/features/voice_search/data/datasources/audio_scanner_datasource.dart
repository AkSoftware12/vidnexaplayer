import 'package:on_audio_query_forked/on_audio_query.dart';

import '../../domain/entities/media_kind.dart';
import '../models/video_index_entry.dart';

/// Talks to `on_audio_query_forked` for music — the same package
/// `Home/OfflineMusic`/`LocalMusic` already use to list and play songs
/// (`SongsView`, `GlobalAudioController`), so voice search sees exactly the
/// same library the Music tab does.
///
/// Unlike video/photo, music has no `photo_manager` "phase 2" size step:
/// `SongModel.size` is already available synchronously from the same
/// MediaStore query, so a single pass fully indexes it.
class AudioScannerDatasource {
  static const _pageSize = 200;

  final OnAudioQuery _audioQuery = OnAudioQuery();

  Future<bool> hasPermission() => _audioQuery.checkAndRequest();

  Future<int> currentSongCount() async {
    if (!await hasPermission()) return 0;
    try {
      final songs = await _audioQuery.querySongs();
      return songs.length;
    } catch (_) {
      return 0;
    }
  }

  /// Returns `null` if the scan could not run at all (no permission) so the
  /// caller can tell that apart from "ran and found zero songs".
  Future<Set<String>?> scan({
    required Future<void> Function(List<VideoIndexEntry> entries) onBatch,
    void Function(int done, int total)? onProgress,
  }) async {
    if (!await hasPermission()) return null;

    List<SongModel> songs;
    try {
      songs = await _audioQuery.querySongs(
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
    } catch (_) {
      return <String>{};
    }

    final seenIds = <String>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    for (var start = 0; start < songs.length; start += _pageSize) {
      final end = (start + _pageSize > songs.length) ? songs.length : start + _pageSize;
      final entries = <VideoIndexEntry>[];
      for (final song in songs.sublist(start, end)) {
        final entry = _toEntry(song, now);
        if (entry != null) entries.add(entry);
      }
      for (final e in entries) {
        seenIds.add(e.id);
      }
      await onBatch(entries);
      onProgress?.call(seenIds.length, songs.length);

      // Yield back to the event loop between pages.
      await Future.delayed(Duration.zero);
    }

    return seenIds;
  }

  /// `null` on malformed rows (e.g. missing path) rather than letting one
  /// bad song abort the whole batch.
  VideoIndexEntry? _toEntry(SongModel song, int indexedAt) {
    try {
      final path = song.data;
      final fileName = song.displayName.trim().isNotEmpty
          ? song.displayName.trim()
          : '${song.title}.mp3';
      final folderName = _folderNameFromPath(path);

      // MediaStore's date_added/date_modified are epoch *seconds*, unlike
      // photo_manager's DateTime (already millisecond-precise) — this is
      // the one field that needs a unit conversion between sources.
      final createdAt = (song.dateAdded ?? 0) * 1000;
      final modifiedAt = (song.dateModified ?? song.dateAdded ?? 0) * 1000;

      return VideoIndexEntry(
        sourceId: song.id.toString(),
        mediaKind: MediaKind.music,
        fileName: fileName,
        filePath: path,
        folderName: folderName,
        folderPath: folderName == null ? null : path.substring(0, path.length - fileName.length),
        fileSizeBytes: song.size,
        durationMs: song.duration ?? 0,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        mimeType: null,
        extension: song.fileExtension.trim().isNotEmpty
            ? song.fileExtension.trim().toLowerCase()
            : VideoIndexEntry.extensionOf(fileName),
        width: 0,
        height: 0,
        indexedAt: indexedAt,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _folderNameFromPath(String path) {
    if (path.isEmpty) return null;
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return null;
    return parts[parts.length - 2];
  }
}
