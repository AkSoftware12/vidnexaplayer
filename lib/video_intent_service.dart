import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'VideoPLayer/4kPlayer/4k_player.dart';
import 'app_globals.dart';

/// Bridge to the native "Open with" intent handled by `MainActivity`.
class VideoIntentService {
  VideoIntentService._();

  static const MethodChannel _channel = MethodChannel('open_video_channel');

  static bool _listening = false;

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

  /// Last uri actually opened, so a genuine cold boot can't double-open one
  /// video: the native side now always attempts a proactive "newVideoIntent"
  /// push (see MainActivity.handleIntent) *and* leaves the uri available for
  /// `fetchLaunchUri()`'s poll-based fallback, so both mechanisms can end up
  /// firing for the same uri in a narrow boot-timing race. Every actual
  /// navigation goes through this gate first.
  static String? _lastOpenedUri;

  /// Returns `true` the first time this uri is claimed, `false` on any
  /// repeat — call this immediately before actually navigating to the
  /// player, from every code path that can deliver a launch uri.
  static bool claimForOpening(String uri) {
    if (uri == _lastOpenedUri) return false;
    _lastOpenedUri = uri;
    return true;
  }

  /// `true` once `SplashScreen` has pushed Home onto the navigator stack.
  ///
  /// Before that, `SplashScreen`'s own `pushReplacement(Home)` — which fires
  /// a few seconds later regardless of anything else — replaces whatever is
  /// CURRENTLY ON TOP of the navigator, not specifically the splash route.
  /// If the proactive push below had already put the video player on top by
  /// then, that pushReplacement silently swapped it out for Home a few
  /// seconds into playback. Gating the direct push on this flag routes a
  /// video arriving before boot completes through `_pending` instead, so it
  /// rides splash's own already-correctly-sequenced flow.
  static bool _bootComplete = false;

  /// Call once, right after Home is pushed (see `SplashScreen.checkLoginStatus`).
  static void markBootComplete() {
    _bootComplete = true;
  }

  /// Asks the native side for the launch uri (`content://…` or `file://…`) and
  /// stores it. Returns `true` when there is something to open.
  ///
  /// The native side returns the raw uri string — media_kit can open content
  /// uris directly, so nothing is copied into the cache directory.
  static Future<bool> fetchLaunchUri() async {
    try {
      final uri = await _channel.invokeMethod<String>('getVideoPath');
      debugPrint('VidnexaIntent: fetchLaunchUri got uri=$uri');
      if (uri == null || uri.trim().isEmpty) return false;
      _pending = uri.trim();
      return true;
    } on MissingPluginException {
      // Channel not registered (e.g. a platform without our MainActivity).
      debugPrint('VidnexaIntent: fetchLaunchUri MissingPluginException');
      return false;
    } catch (e) {
      debugPrint('VideoIntentService.fetchLaunchUri failed: $e');
      return false;
    }
  }

  /// Starts listening for "Open with" intents that arrive while the app is
  /// already running.
  ///
  /// `fetchLaunchUri()` only covers a cold start — Dart asks for the launch
  /// uri exactly once, from `MyApp.initState`. If the app is already alive
  /// (backgrounded, or sitting on some other screen) and the user opens
  /// another video from the file manager, Android hands the new intent to
  /// `MainActivity.onNewIntent` instead of starting a fresh process, and
  /// nothing polled for it again — the tap silently did nothing. The native
  /// side now proactively calls "newVideoIntent" on this same channel for
  /// exactly that case, and we push the player directly here.
  static void startListening() {
    if (_listening) return;
    _listening = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method != 'newVideoIntent') return;

      final uri = (call.arguments as String?)?.trim();
      if (uri == null || uri.isEmpty) return;

      if (!_bootComplete) {
        // Home isn't up yet — defer to `_pending` so this rides the same
        // sequenced path as `fetchLaunchUri()` instead of racing ahead of
        // it and getting wiped out by splash's own delayed pushReplacement.
        _pending = uri;
        return;
      }

      if (!claimForOpening(uri)) return;

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;

      unawaited(
        navigator.push(
          MaterialPageRoute(
            builder: (_) => FullScreenVideoPlayerFixed(
              videos: const [],
              initialIndex: 0,
              // media_kit opens content:// and file:// uris directly.
              initialUrl: uri,
            ),
          ),
        ),
      );
    });
  }
}
