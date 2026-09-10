import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../../LocalMusic/AudioServiceInit/audio_service_init.dart';

/// Makes the music player and the video player take turns instead of talking
/// over each other.
///
/// WHY THIS IS NEEDED. The two players are different engines and neither knows
/// about the other:
///
///  * Music is `just_audio` + `audio_service`, which sits inside Android's
///    audio-focus system.
///  * Video is media_kit/libmpv, pinned to `ao=opensles`. OpenSL ES does not
///    request audio focus at all, so starting a video never told the music
///    player to stop — both streams simply mixed.
///
/// Rather than fight OEM audio-focus behaviour (which varies wildly and is
/// exactly where "works on my phone" bugs come from), the hand-off is made
/// explicit here: whoever the user just started wins, and the other one is
/// paused.
///
/// The one subtlety worth the code is [_musicPausedByVideo]. Music is only
/// resumed when the video ITSELF paused it — if the user had already paused
/// their music before opening the video, closing the video must not start
/// playing music at them.
class PlaybackCoordinator {
  PlaybackCoordinator._();

  static final PlaybackCoordinator instance = PlaybackCoordinator._();

  /// Pauses the video that is currently on screen. Registered by the player.
  Future<void> Function()? _pauseVideo;

  /// Whether that video is playing right now.
  bool Function()? _isVideoPlaying;

  /// True only while music is paused *because* a video took over, which is the
  /// only case where closing the video should resume it.
  bool _musicPausedByVideo = false;

  /// Guards the window between "we asked music to pause" and the player stream
  /// reporting it, so our own pause is not mistaken for the user starting
  /// something.
  bool _suppressMusicEvents = false;

  // ── video side ───────────────────────────────────────────────────────────

  /// Identifies the current video owner. See [detachVideo].
  int _videoToken = 0;

  /// Called by the video surface when it becomes the active one — the
  /// full-screen player, or the floating window after a hand-off.
  ///
  /// Returns a token the caller passes back to [detachVideo].
  int attachVideo({
    required Future<void> Function() pauseVideo,
    required bool Function() isVideoPlaying,
  }) {
    _pauseVideo = pauseVideo;
    _isVideoPlaying = isVideoPlaying;
    return ++_videoToken;
  }

  /// Called when a video surface goes away.
  ///
  /// [token] matters because of the ordering on a hand-off to the floating
  /// window: `FloatingVideoManager.show()` runs BEFORE the full-screen page's
  /// `dispose()`. Without the check, the page's detach would immediately
  /// unregister the window that had just taken over, and starting music would
  /// then find no video to pause — both would play at once, which is exactly
  /// the popup bug this guards.
  ///
  /// [resumeMusic] is what makes closing a video bring the user's music back.
  Future<void> detachVideo({int? token, bool resumeMusic = true}) async {
    if (token == null || token == _videoToken) {
      _pauseVideo = null;
      _isVideoPlaying = null;
    }
    if (resumeMusic) await _resumeMusicIfWePausedIt();
  }

  /// The video started playing — silence the music.
  Future<void> onVideoPlaying() async {
    if (!AudioServiceInit.isReady) return;

    try {
      final musicPlayer = GlobalAudioController().player;
      if (!musicPlayer.playing) return;

      _suppressMusicEvents = true;
      await GlobalAudioController().handler.pause();
      _musicPausedByVideo = true;
    } catch (e) {
      debugPrint('[playback] could not pause music for video: $e');
    } finally {
      // A microtask is not enough — the pause travels through the platform
      // channel and the playing stream lands a frame or two later.
      Timer(const Duration(milliseconds: 400), () {
        _suppressMusicEvents = false;
      });
    }
  }

  /// The video paused or stopped but is still on screen.
  ///
  /// Deliberately does NOT resume music: the user pausing a video to read a
  /// subtitle should not get music in their ears. Music comes back when the
  /// video is closed ([detachVideo]).
  void onVideoPaused() {}

  // ── music side ───────────────────────────────────────────────────────────

  /// The music player started playing — pause any video on screen.
  ///
  /// Called from the music player's state stream, so it also covers playback
  /// started from the notification or a headset button.
  Future<void> onMusicPlaying() async {
    // Our own pause/resume must not be read as the user picking a side.
    if (_suppressMusicEvents) return;

    // The user chose music, so the video no longer owns the resume.
    _musicPausedByVideo = false;

    final pause = _pauseVideo;
    final isPlaying = _isVideoPlaying;
    if (pause == null || isPlaying == null) return;

    try {
      if (isPlaying()) await pause();
    } catch (e) {
      debugPrint('[playback] could not pause video for music: $e');
    }
  }

  Future<void> _resumeMusicIfWePausedIt() async {
    if (!_musicPausedByVideo) return;
    _musicPausedByVideo = false;

    if (!AudioServiceInit.isReady) return;
    try {
      _suppressMusicEvents = true;
      await GlobalAudioController().handler.play();
    } catch (e) {
      debugPrint('[playback] could not resume music: $e');
    } finally {
      Timer(const Duration(milliseconds: 400), () {
        _suppressMusicEvents = false;
      });
    }
  }

  /// Test/debug hook: whether music is waiting on a video to finish.
  @visibleForTesting
  bool get musicPausedByVideo => _musicPausedByVideo;
}
