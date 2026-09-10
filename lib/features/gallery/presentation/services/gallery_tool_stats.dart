import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the last run of each gallery tool found.
///
/// The Tools tab wants to show a number on every card — "38 groups",
/// "1.2 GB free" — but finding those numbers costs a full library scan, which
/// is exactly what the card is a button for. So each tool writes its result
/// down when it finishes, and the tab quotes that instead of re-running the
/// work. A null field means "never run": the card says so rather than
/// inventing a figure.
@immutable
class GalleryToolStats {
  const GalleryToolStats({
    this.duplicateGroups,
    this.junkBytes,
    this.indexedAt,
  });

  static const GalleryToolStats empty = GalleryToolStats();

  /// Groups the duplicate finder last reported, null until it has run.
  final int? duplicateGroups;

  /// Bytes the junk cleaner last found, null until it has run.
  final int? junkBytes;

  /// When the signature index last completed a pass.
  final DateTime? indexedAt;

  GalleryToolStats copyWith({
    int? duplicateGroups,
    int? junkBytes,
    DateTime? indexedAt,
  }) {
    return GalleryToolStats(
      duplicateGroups: duplicateGroups ?? this.duplicateGroups,
      junkBytes: junkBytes ?? this.junkBytes,
      indexedAt: indexedAt ?? this.indexedAt,
    );
  }
}

/// Persists [GalleryToolStats] and broadcasts changes to whoever is showing
/// them.
///
/// A singleton for the same reason [PhotoSignatureService] is: the tools that
/// write here live on pushed routes, and the tab that reads is somewhere
/// underneath. Never throws — a preferences failure must not take down a tool
/// that has just finished real work.
class GalleryToolStatsStore {
  GalleryToolStatsStore._();

  static final GalleryToolStatsStore instance = GalleryToolStatsStore._();

  static const _duplicateGroupsKey = 'gallery_stats_duplicate_groups';
  static const _junkBytesKey = 'gallery_stats_junk_bytes';
  static const _indexedAtKey = 'gallery_stats_indexed_at';

  final ValueNotifier<GalleryToolStats> stats =
      ValueNotifier<GalleryToolStats>(GalleryToolStats.empty);

  bool _loaded = false;

  /// Reads the stored values once. Safe to call from every `initState` that
  /// wants them — subsequent calls are a no-op.
  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final indexedMillis = prefs.getInt(_indexedAtKey);
      stats.value = GalleryToolStats(
        duplicateGroups: prefs.getInt(_duplicateGroupsKey),
        junkBytes: prefs.getInt(_junkBytesKey),
        indexedAt: indexedMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(indexedMillis),
      );
    } catch (error) {
      debugPrint('GalleryToolStatsStore.load failed: $error');
    }
  }

  Future<void> recordDuplicates({required int groups}) async {
    stats.value = stats.value.copyWith(duplicateGroups: groups);
    await _write((prefs) => prefs.setInt(_duplicateGroupsKey, groups));
  }

  Future<void> recordJunk({required int bytes}) async {
    stats.value = stats.value.copyWith(junkBytes: bytes);
    await _write((prefs) => prefs.setInt(_junkBytesKey, bytes));
  }

  Future<void> recordIndexRun() async {
    final now = DateTime.now();
    stats.value = stats.value.copyWith(indexedAt: now);
    await _write(
      (prefs) => prefs.setInt(_indexedAtKey, now.millisecondsSinceEpoch),
    );
  }

  Future<void> _write(Future<void> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (error) {
      debugPrint('GalleryToolStatsStore write failed: $error');
    }
  }
}
