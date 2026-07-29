import 'package:shared_preferences/shared_preferences.dart';

/// Recently-played list keyed by **file path**.
///
/// ⚠️ Not currently used anywhere — `VideoProvider` (lib/Home/HomeScreen/home2.dart)
/// is the live implementation and stores **AssetEntity ids**.
///
/// This class used to share `VideoProvider`'s `'recently_played_videos'` key
/// while storing a completely different kind of value, so enabling it would
/// have mixed paths and asset ids in one list and corrupted both features. It
/// now uses its own namespaced key. Prefer deleting this file and using
/// `VideoProvider` instead of wiring it up.
@Deprecated('Use VideoProvider in lib/Home/HomeScreen/home2.dart instead.')
class RecentlyPlayedManager {
  RecentlyPlayedManager._();

  // Deliberately NOT 'recently_played_videos' — that key belongs to VideoProvider.
  static const String _key = 'recently_played_video_paths';
  static const int _maxEntries = 10;

  /// Saves a video path at the top of the list.
  static Future<void> addVideo(String videoPath) async {
    if (videoPath.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final videos = prefs.getStringList(_key) ?? <String>[];

      videos
        ..remove(videoPath)
        ..insert(0, videoPath);

      await prefs.setStringList(
        _key,
        videos.length > _maxEntries ? videos.sublist(0, _maxEntries) : videos,
      );
    } catch (_) {
      // Non-fatal.
    }
  }

  static Future<List<String>> getVideos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? <String>[];
    } catch (_) {
      return <String>[];
    }
  }

  static Future<void> removeVideo(String videoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videos = prefs.getStringList(_key) ?? <String>[];
      if (!videos.remove(videoPath)) return;
      await prefs.setStringList(_key, videos);
    } catch (_) {
      // Non-fatal.
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Non-fatal.
    }
  }
}
