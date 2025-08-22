import 'package:shared_preferences/shared_preferences.dart';

class RecentlyPlayedManager {
  static const String _key = 'recently_played_videos';

  // Save a video to the recently played list
  static Future<void> addVideo(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> videos = prefs.getStringList(_key) ?? [];

    // Avoid duplicates and maintain a limit (e.g., 10 videos)
    if (videos.contains(videoPath)) {
      videos.remove(videoPath);
    }
    videos.insert(0, videoPath); // Add to the start of the list
    if (videos.length > 10) {
      videos = videos.sublist(0, 10); // Limit to 10 videos
    }
    await prefs.setStringList(_key, videos);
  }

  // Retrieve the list of recently played videos
  static Future<List<String>> getVideos() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }
}