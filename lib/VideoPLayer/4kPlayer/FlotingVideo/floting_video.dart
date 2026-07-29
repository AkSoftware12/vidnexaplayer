import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import '../4k_player.dart';

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
  static bool _showControls = true;
  static Timer? _hideTimer;

  static bool get isActive => _entry != null;

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

  /// Keeps the window fully on screen so it can never be dragged out of reach.
  static void _clampOffset(Size screen) {
    final w = _windowSize.width;
    final h = _windowSize.height;
    const margin = 4.0;

    _offset = Offset(
      _offset.dx.clamp(margin, (screen.width - w - margin).clamp(margin, double.infinity)),
      _offset.dy.clamp(margin, (screen.height - h - margin).clamp(margin, double.infinity)),
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

    _playingSub?.cancel();
    _playingSub = player.stream.playing.listen((playing) {
      globalPlayPause.update(playing);
      _entry?.markNeedsBuild();
    });

    _entry = OverlayEntry(
      builder: (overlayContext) {
        final controller = _controller;
        if (controller == null) return const SizedBox.shrink();

        final screen = MediaQuery.sizeOf(overlayContext);
        _clampOffset(screen);

        return Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: GestureDetector(
            onTap: _showControlsTemporarily,
            onPanUpdate: (details) {
              _offset += details.delta;
              _clampOffset(screen);
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
                                // Play / Pause synced with the fullscreen player
                                IconButton(
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

                                // Back to fullscreen
                                IconButton(
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
    );

    overlay.insert(_entry!);
    _showControlsTemporarily();
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

    _teardownOverlay();

    _player = null;
    _controller = null;

    if (player == null || controller == null) return null;
    return FloatingHandover(player: player, controller: controller);
  }

  /// Removes the overlay and disposes the player.
  static Future<void> close() async {
    final player = _player;

    _teardownOverlay();

    _player = null;
    _controller = null;
    _videos = const [];

    if (player == null) return;
    try {
      await player.dispose();
    } catch (_) {
      // Already disposed elsewhere — nothing to do.
    }
  }

  /// Backwards-compatible alias for [close].
  static Future<void> hide() => close();

  static void _teardownOverlay() {
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
