import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import '../4k_player.dart';

class FloatingVideoManager {
  static OverlayEntry? _entry;
  static Player? _player;
  static VideoController? _controller;
  static List<AssetEntity>? _videos;
  static int _currentIndex = 0;
  static Offset _offset = const Offset(20, 100);

  static StreamSubscription<bool>? _playingSub;
  static bool _showControls = true;
  static Timer? _hideTimer;

  static void _showControlsTemporarily() {
    _showControls = true;
    _entry?.markNeedsBuild();
    _hideTimer?.cancel();

    _hideTimer = Timer(const Duration(seconds: 5), () {
      _showControls = false;
      _entry?.markNeedsBuild();
    });
  }

  /// Show floating player
  static void show(
      BuildContext context,
      Player player,
      VideoController controller,
      List<AssetEntity> videos,
      int currentIndex,
      ) {
    if (_entry != null) return;

    _player = player;
    _controller = controller;
    _videos = videos;
    _currentIndex = currentIndex;

    // LISTEN PLAY/PAUSE — GLOBAL SYNC
    _playingSub?.cancel();
    _playingSub = _player!.stream.playing.listen((playing) {
      globalPlayPause.update(playing); // 🔥 SYNC state global
      _entry?.markNeedsBuild();
    });

    _entry = OverlayEntry(builder: (overlayContext) {
      return Positioned(
        left: _offset.dx,
        top: _offset.dy,
        child: GestureDetector(
          onTap: _showControlsTemporarily,
          onPanUpdate: (details) {
            _offset += details.delta;
            _entry?.markNeedsBuild();
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 250.sp,
              height: 140.sp,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Video(controller: _controller!, controls: null),
                    ),
                  ),

                  // ==============================
                  // CONTROLS - AUTO HIDE
                  // ==============================
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
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
                            // ------------------------------------------------
                            // 🔥 Play / Pause synced with FullScreen Player
                            // ------------------------------------------------
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

                                if (globalPlayPause.isPlaying) {
                                  await _player?.pause();
                                } else {
                                  await _player?.play();
                                }
                              },
                            ),

                            // FullScreen
                            IconButton(
                              icon: Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                              onPressed: () {
                                _showControlsTemporarily();

                                final ctx = overlayContext;
                                hide();

                                Navigator.of(ctx).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenVideoPlayer(
                                      videos: _videos!,
                                      initialIndex: _currentIndex,
                                      externalPlayer: _player,
                                      externalController: _controller,
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Close
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                              onPressed: () {
                                _showControlsTemporarily();
                                hide();
                                _player?.pause();
                              },
                            ),
                          ],
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
    });

    Overlay.of(context)!.insert(_entry!);
    _showControlsTemporarily();
  }

  static void hide() {
    _playingSub?.cancel();
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
  }

  static bool get isActive => _entry != null;
}
