import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge to the native "Open with" intent handled by `MainActivity`.
class VideoIntentService {
  VideoIntentService._();

  static const MethodChannel _channel = MethodChannel('open_video_channel');

  /// Uri the app was launched with, waiting to be opened.
  ///
  /// `main.dart` fetches it at start-up and parks it here; the splash screen
  /// consumes it *after* it has put the home screen on the stack, so backing
  /// out of the player lands on Home rather than on a dead splash route.
  static String? _pending;

  /// `true` when a video from an external intent is waiting to be shown.
  static bool get hasPendingVideo => _pending != null;

  /// Returns the pending uri exactly once.
  static String? consumePendingVideo() {
    final uri = _pending;
    _pending = null;
    return uri;
  }

  /// Asks the native side for the launch uri (`content://…` or `file://…`) and
  /// stores it. Returns `true` when there is something to open.
  ///
  /// The native side returns the raw uri string — media_kit can open content
  /// uris directly, so nothing is copied into the cache directory.
  static Future<bool> fetchLaunchUri() async {
    try {
      final uri = await _channel.invokeMethod<String>('getVideoPath');
      if (uri == null || uri.trim().isEmpty) return false;
      _pending = uri.trim();
      return true;
    } on MissingPluginException {
      // Channel not registered (e.g. a platform without our MainActivity).
      return false;
    } catch (e) {
      debugPrint('VideoIntentService.fetchLaunchUri failed: $e');
      return false;
    }
  }
}
