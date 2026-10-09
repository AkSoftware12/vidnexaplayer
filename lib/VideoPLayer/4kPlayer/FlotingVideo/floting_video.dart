import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../features/playback/playback_coordinator.dart';
import '../4k_player.dart';
import '../../safe_player_dispose.dart';
import '../../Resume/playback_position_store.dart';
import 'system_pip.dart';

/// Picture-in-picture style floating player rendered in the app's [Overlay].
///
/// Ownership rules (this is what the previous version got wrong):
///  * [show]     — takes over the given [Player]; the floating window owns it.
///  * [detach]   — removes the window but *keeps the player alive* and hands it
///                 back to the caller. Used when going back to fullscreen.
///  * [close]    — removes the window and disposes the player. Used by the ✕.
///
/// The old `hide()` always disposed the player, including on the path to
/// fullscreen, so the fullscreen route received a null/disposed player and
/// restarted the video from zero (or crashed).
class FloatingVideoManager {
  FloatingVideoManager._();

  static OverlayEntry? _entry;
  static Player? _player;
  static VideoController? _controller;
  static List<AssetEntity> _videos = const [];
  static int _currentIndex = 0;

  static Offset _offset = const Offset(20, 100);

  static StreamSubscription<bool>? _playingSub;

  /// Identifies this window to the PlaybackCoordinator.
  static int? _coordinatorToken;
  static bool _showControls = true;
  static Timer? _hideTimer;

  static bool get isActive => _entry != null;

  /// The floating window's video, for [PipHost] to show in the PiP window.
  static VideoController? get controller => _controller;

  /// Window size in logical pixels — also used to clamp dragging.
  static Size get _windowSize => Size(250.sp, 140.sp);

  static void _showControlsTemporarily() {
    _showControls = true;
    _entry?.markNeedsBuild();
    _hideTimer?.cancel();

    _hideTimer = Timer(const Duration(seconds: 5), () {
      _showControls = false;
      _entry?.markNeedsBuild();
    });
  }

  /// [offset] moved as needed to keep the window fully on [screen], so it can
  /// never be dragged out of reach.
  ///
  /// Returns a value instead of writing [_offset]: the build uses it only for
  /// display, so a frame laid out at a tiny size (the PiP window, while
  /// entering or leaving it) can no longer push the saved position into the
  /// corner for good.
  static Offset _clamped(Offset offset, Size screen) {
    final w = _windowSize.width;
    final h = _windowSize.height;
    const margin = 4.0;

    return Offset(
      offset.dx.clamp(margin, (screen.width - w - margin).clamp(margin, double.infinity)),
      offset.dy.clamp(margin, (screen.height - h - margin).clamp(margin, double.infinity)),
    );
  }

  /// Shows the floating player. No-op if one is already visible.
  static void show(
    BuildContext context,
    Player player,
    VideoController controller,
    List<AssetEntity> videos,
    int currentIndex,
  ) {
    if (_entry != null) return;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _player = player;
    _controller = controller;
    _videos = List<AssetEntity>.unmodifiable(videos);
    _currentIndex = currentIndex;

    // The full-screen player detached itself from the coordinator on the way
    // out, so the floating window has to take over as "the video that is
    // playing" — otherwise starting music would find nothing to pause and both
    // would play at once.
    _coordinatorToken = PlaybackCoordinator.instance.attachVideo(
      pauseVideo: () async {
        try {
          await _player?.pause();
        } catch (_) {}
      },
      isVideoPlaying: () {
        try {
          return _player?.state.playing ?? false;
        } catch (_) {
          return false;
        }
      },
    );

    // The full-screen player's own "play the next one" listener died with its
    // page, so the floating window has to carry the playlist on itself.
    _completedSub?.cancel();
    _completedSub = player.stream.completed.listen((completed) {
      if (!completed) return;
      // A finished video must not offer to resume next time.
      if (_currentIndex < _videos.length) {
        unawaited(PlaybackPositionStore.clear(_videos[_currentIndex].id));
      }
      if (_hasNext) unawaited(_playIndex(_currentIndex + 1));
    });

    _playingSub?.cancel();
    _playingSub = player.stream.playing.listen((playing) {
      if (playing) {
        unawaited(PlaybackCoordinator.instance.onVideoPlaying());
      } else {
        PlaybackCoordinator.instance.onVideoPaused();
      }
      globalPlayPause.update(playing);
      _entry?.markNeedsBuild();
    });

    _entry = OverlayEntry(
      builder: (overlayContext) => ValueListenableBuilder<bool>(
        valueListenable: SystemPip.instance.inPip,
        builder: (overlayContext, inPip, _) {
        final controller = _controller;
        if (controller == null) return const SizedBox.shrink();

        // In Android's PiP window [PipHost] draws the video full-window over
        // the whole app, so the small window steps aside.
        if (inPip) return const SizedBox.shrink();

        final screen = MediaQuery.sizeOf(overlayContext);
        final shown = _clamped(_offset, screen);

        return Positioned(
          left: shown.dx,
          top: shown.dy,
          child: GestureDetector(
            onTap: _showControlsTemporarily,
            onPanUpdate: (details) {
              _offset = _clamped(
                  _clamped(_offset, screen) + details.delta, screen);
              _entry?.markNeedsBuild();
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: _windowSize.width,
                height: _windowSize.height,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Video(controller: controller, controls: null),
                      ),
                    ),

                    // ============ CONTROLS - AUTO HIDE ============
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedOpacity(
                        opacity: _showControls ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: IgnorePointer(
                          ignoring: !_showControls,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.black54,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            height: 36.sp,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _skipButton(
                                  Icons.skip_previous,
                                  enabled: _hasPrevious,
                                  onPressed: () =>
                                      _playIndex(_currentIndex - 1),
                                ),

                                // Play / Pause synced with the fullscreen player
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    globalPlayPause.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 20.sp,
                                  ),
                                  onPressed: () async {
                                    _showControlsTemporarily();
                                    final p = _player;
                                    if (p == null) return;
                                    if (globalPlayPause.isPlaying) {
                                      await p.pause();
                                    } else {
                                      await p.play();
                                    }
                                  },
                                ),

                                _skipButton(
                                  Icons.skip_next,
                                  enabled: _hasNext,
                                  onPressed: () =>
                                      _playIndex(_currentIndex + 1),
                                ),

                                // Back to fullscreen
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: 20.sp,
                                  ),
                                  onPressed: () {
                                    _goFullScreen(overlayContext);
                                  },
                                ),

                                // Close
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20.sp,
                                  ),
                                  onPressed: close,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        },
      ),
    );

    overlay.insert(_entry!);
    _showControlsTemporarily();
    _armSystemPip(player);
  }

  static StreamSubscription<bool>? _completedSub;

  /// Guards against a second skip while the next file is still opening.
  static bool _switching = false;

  /// Previous / next in the window's control row; greyed out at either end of
  /// the playlist.
  static Widget _skipButton(
    IconData icon, {
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: enabled ? Colors.white : Colors.white38,
          size: 20.sp),
      onPressed: enabled
          ? () {
              _showControlsTemporarily();
              onPressed();
            }
          : null,
    );
  }

  static bool get _hasNext => _currentIndex < _videos.length - 1;
  static bool get _hasPrevious => _currentIndex > 0;

  /// Opens video [index] of the playlist in the same player, so the window,
  /// the PiP hand-off and fullscreen all keep working on the new one.
  static Future<void> _playIndex(int index) async {
    final player = _player;
    if (player == null || _switching) return;
    if (index < 0 || index >= _videos.length) return;

    _switching = true;
    try {
      final file = await _videos[index].file;
      // Closed or handed back to fullscreen while the file was resolving.
      if (file == null || !identical(_player, player)) return;
      _currentIndex = index;
      await player.open(Media(file.path));
      _entry?.markNeedsBuild();
    } catch (_) {
      // Unreadable file: stay on the current one.
    } finally {
      _switching = false;
    }
  }

  /// While the floating window is up, leaving the app moves it into Android's
  /// PiP window instead of losing it.
  ///
  /// Always 16:9, the same shape as the in-app window: following the video's
  /// own shape made portrait videos open a tall window that covered much of
  /// the home screen.
  static void _armSystemPip(Player player) {
    unawaited(SystemPip.instance.setEnabled(true, width: 16, height: 9));

    // The PiP window's own ✕ — the user is done watching, so stop the sound
    // rather than leave it playing with nothing on screen.
    SystemPip.instance.onDismissed = () {
      try {
        _player?.pause();
      } catch (_) {}
    };
  }

  static void _disarmSystemPip() {
    SystemPip.instance.onDismissed = null;
    unawaited(SystemPip.instance.setEnabled(false));
  }

  /// Re-opens the fullscreen player, handing over the *live* player instance so
  /// playback continues from the current position.
  static void _goFullScreen(BuildContext overlayContext) {
    _showControlsTemporarily();

    final navigator = Navigator.maybeOf(overlayContext, rootNavigator: true);

    // Capture BEFORE detaching — detach() nulls the static fields.
    final videos = _videos;
    final index = _currentIndex;
    final handover = detach();

    if (handover == null || navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'VideoPlayerScreen'),
        builder: (_) => FullScreenVideoPlayerFixed(
          videos: videos,
          initialIndex: index,
          externalPlayer: handover.player,
          externalController: handover.controller,
        ),
      ),
    );
  }

  /// Removes the overlay and hands the still-running player to the caller.
  /// The caller becomes responsible for disposing it.
  static FloatingHandover? detach() {
    final player = _player;
    final controller = _controller;

    // Going back to fullscreen: the video keeps playing, so music must NOT be
    // resumed. The fullscreen page re-registers itself in its own initState.
    unawaited(PlaybackCoordinator.instance
        .detachVideo(token: _coordinatorToken, resumeMusic: false));
    _coordinatorToken = null;

    _teardownOverlay();

    _player = null;
    _controller = null;

    if (player == null || controller == null) return null;
    return FloatingHandover(player: player, controller: controller);
  }

  /// Removes the overlay and disposes the player.
  static Future<void> close() async {
    final player = _player;

    // The ✕: the video is really gone, so music the video interrupted comes
    // back here.
    await PlaybackCoordinator.instance
        .detachVideo(token: _coordinatorToken, resumeMusic: true);
    _coordinatorToken = null;

    _teardownOverlay();

    _player = null;
    _controller = null;
    _videos = const [];

    if (player == null) return;

    // Deferred for the same reason as the full-screen player: the
    // `_teardownOverlay()` above removes the OverlayEntry, which destroys the
    // video platform view and fires media_kit's widListener. That listener
    // finishes with a `seek()` on this player and does not check whether it is
    // still alive, so releasing it here on the same frame throws
    // `Assertion failed: "[Player] has been disposed"`. See
    // [disposePlayerSafely].
    disposePlayerSafely(player);
  }

  /// Backwards-compatible alias for [close].
  static Future<void> hide() => close();

  static void _teardownOverlay() {
    _disarmSystemPip();

    _completedSub?.cancel();
    _completedSub = null;

    _playingSub?.cancel();
    _playingSub = null;

    _hideTimer?.cancel();
    _hideTimer = null;

    _entry?.remove();
    _entry = null;
  }
}

/// The player + controller pair handed over by [FloatingVideoManager.detach].
class FloatingHandover {
  const FloatingHandover({required this.player, required this.controller});

  final Player player;
  final VideoController controller;
}
