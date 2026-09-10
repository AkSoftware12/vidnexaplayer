import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Last-watched position per video, so the player can offer "Resume" and the
/// video lists can draw a watched-progress line under each thumbnail.
///
/// Keyed by a caller-supplied id — `AssetEntity.id` for local videos and the
/// raw link for network streams. Entries are stored as one JSON map under a
/// single preferences key and pruned by last-touched time, so the list can't
/// grow without bound on a device with a large gallery.
class PlaybackPositionStore {
  PlaybackPositionStore._();

  static const String _key = 'video_resume_positions';
  static const int _maxEntries = 200;

  /// Ignore anything in the first few seconds — resuming at 0:03 is noise.
  static const Duration minSavePosition = Duration(seconds: 10);

  /// Treat the tail of a video as "finished" and drop the entry, otherwise
  /// every completed video would ask to resume 5 seconds before its end.
  static const Duration endThreshold = Duration(seconds: 15);

  /// Bumped whenever a position is written or cleared. List tiles listen to
  /// this so the progress line updates as soon as the player pops.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// In-memory mirror so the position ticker doesn't hit a disk decode on
  /// every save, and so tiles can read progress synchronously in `build`.
  static Map<String, dynamic>? _cache;
  static Future<void>? _loading;

  /// Loads the map into [_cache] once. Widgets call this and rebuild through
  /// [revision] when it completes.
  static Future<void> ensureLoaded() {
    if (_cache != null) return Future<void>.value();
    return _loading ??= _read().then((_) {
      _loading = null;
      revision.value++;
    });
  }

  static Future<Map<String, dynamic>> _read() async {
    if (_cache != null) return _cache!;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return _cache = <String, dynamic>{};
      final decoded = jsonDecode(raw);
      _cache = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      _cache = <String, dynamic>{};
    }
    return _cache!;
  }

  static Future<void> _flush(Map<String, dynamic> data) async {
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(data));
    } catch (_) {
      // Non-fatal — a lost resume point is not worth breaking playback for.
    }
  }

  /// Saves (or clears) the position for [id].
  ///
  /// The entry is removed when the video is near its start or its end, so the
  /// resume prompt and the progress line only appear where they are useful.
  static Future<void> save({
    required String id,
    required Duration position,
    required Duration duration,
  }) async {
    if (id.trim().isEmpty) return;

    final data = await _read();

    final tooEarly = position < minSavePosition;
    final tooLate =
        duration > Duration.zero && position >= duration - endThreshold;

    if (tooEarly || tooLate) {
      if (data.remove(id) != null) await _flush(data);
      return;
    }

    data[id] = <String, dynamic>{
      'p': position.inMilliseconds,
      'd': duration.inMilliseconds,
      't': DateTime.now().millisecondsSinceEpoch,
    };

    if (data.length > _maxEntries) {
      final entries = data.entries.toList()
        ..sort((a, b) {
          final at = (a.value is Map) ? (a.value['t'] as int? ?? 0) : 0;
          final bt = (b.value is Map) ? (b.value['t'] as int? ?? 0) : 0;
          return bt.compareTo(at); // newest first
        });
      data
        ..clear()
        ..addEntries(entries.take(_maxEntries));
    }

    await _flush(data);
  }

  /// Saved position for [id], or `null` when there is nothing to resume.
  static Future<Duration?> get(String id) async {
    if (id.trim().isEmpty) return null;
    await _read();
    return positionOf(id);
  }

  /// Synchronous read of the cached position — `null` until [ensureLoaded]
  /// has finished, or when nothing is stored for [id].
  static Duration? positionOf(String id) {
    final entry = _cache?[id];
    if (entry is! Map) return null;
    final ms = entry['p'];
    if (ms is! int || ms <= 0) return null;
    final position = Duration(milliseconds: ms);
    return position < minSavePosition ? null : position;
  }

  /// Watched fraction (0..1) for [id], or `null` when there is nothing to
  /// show. [fallbackDuration] covers entries saved before the player knew the
  /// real duration (network streams).
  static double? progressOf(String id, {Duration? fallbackDuration}) {
    final position = positionOf(id);
    if (position == null) return null;

    final entry = _cache?[id];
    var totalMs = (entry is Map && entry['d'] is int) ? entry['d'] as int : 0;
    if (totalMs <= 0) totalMs = fallbackDuration?.inMilliseconds ?? 0;
    if (totalMs <= 0) return null;

    return (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  static Future<void> clear(String id) async {
    if (id.trim().isEmpty) return;
    final data = await _read();
    if (data.remove(id) == null) return;
    await _flush(data);
  }

  static Future<void> clearAll() async {
    _cache = <String, dynamic>{};
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Non-fatal.
    }
  }
}
