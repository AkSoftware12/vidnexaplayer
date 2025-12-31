import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../custom_video_appBar.dart';
import '../4k_player.dart';

class CustomVideoControls extends StatefulWidget {
  final Player player;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final VoidCallback? onToggleEqualizer;
  final VoidCallback? onToggleFilters;
  final VoidCallback? onToggleOrientation;
  final VoidCallback? onToggleLock;
  final VoidCallback? onTakeScreenshot;
  final VoidCallback? onToggleAudioOnly;
  final VoidCallback onToggleFloting;
  final VoidCallback? onCyclePlaybackRate;
  final VoidCallback? onBackPressed;
  final bool? audioOnly;
  final VoidCallback? onVolume;
  final int index;
  final List<AssetEntity> videos;
  final VideoResizeMode resizeMode;
  final VoidCallback onToggleResizeMode;

  const CustomVideoControls({
    super.key,
    required this.player,
    this.onNext,
    this.onPrevious,
    this.onToggleEqualizer,
    this.onToggleFilters,
    this.onToggleOrientation,
    required this.onToggleFloting,
    this.onToggleLock,
    this.onTakeScreenshot,
    this.onToggleAudioOnly,
    this.audioOnly,
    this.onCyclePlaybackRate,
    this.onVolume,
    required this.index,
    required this.videos,
    this.onBackPressed,
    required this.resizeMode,
    required this.onToggleResizeMode,
  });

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _visible = true;
  double _progress = 0.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  @override
  void initState() {
    super.initState();
    final p = widget.player;

    _positionSub = p.stream.position.listen((pos) {
      if (!mounted) return;
      _position = pos;
      final d = p.state.duration;
      if (d.inMilliseconds > 0) {
        _progress = pos.inMilliseconds / d.inMilliseconds;
      }
      setState(() {});
    });

    _durationSub = p.stream.duration.listen((d) {
      _duration = d;
    });

    _playingSub = p.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
      globalPlayPause.update(playing);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    _isPlaying ? widget.player.pause() : widget.player.play();
  }

  Future<void> _seekBy(Duration offset) async {
    await widget.player.seek(_position + offset);
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final playSize = isLandscape ? 22.sp : 45.sp;
    final sideSize = isLandscape ? 15.sp : 28.sp;
    final bottomPadding = isLandscape ? 0.sp : 40.sp;

    return GestureDetector(
      onTap: () => setState(() => _visible = !_visible),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: !_visible,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: RepaintBoundary(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    /// 🔥 SAFE DIM LAYER (NO GREY BUG)
                    Container(
                      color: Colors.black.withOpacity(0.15),
                    ),

                    /// 🔝 APP BAR
                    Positioned(
                      top: isLandscape ? 6 : 40,
                      left: 0,
                      right: 0,
                      child: RepaintBoundary(
                        child: Container(
                          color: Colors.black.withOpacity(0.4),
                          child: CustomVideoAppBar(
                            title: widget.videos[widget.index].title ?? '',
                            onBackPressed: () {
                              if (isLandscape) {
                                SystemChrome.setPreferredOrientations([
                                  DeviceOrientation.portraitUp,
                                  DeviceOrientation.portraitDown,
                                ]);
                                SystemChrome.setEnabledSystemUIMode(
                                  SystemUiMode.manual,
                                  overlays: SystemUiOverlay.values,
                                );
                              } else {
                                ScreenBrightness().resetScreenBrightness();
                                Navigator.pop(context);
                              }
                            },
                            currentIndex: widget.index,
                            onVideoSelected: (_) {},
                            isLandscape: isLandscape,
                            videos: widget.videos,
                          ),
                        ),
                      ),
                    ),

                    /// ⬇️ BOTTOM CONTROLS
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        color: Colors.black.withOpacity(0.08),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            /// LEFT & RIGHT SIDE BUTTONS
                            Stack(
                              children: [
                                Align(
                                  alignment: Alignment.bottomLeft,
                                  child: Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.camera_alt),
                                        color: Colors.white,
                                        onPressed:
                                        widget.onTakeScreenshot,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.screen_rotation),
                                        color: Colors.white,
                                        onPressed:
                                        widget.onToggleOrientation,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.headphones),
                                        color: widget.audioOnly == true
                                            ? Colors.greenAccent
                                            : Colors.white,
                                        onPressed:
                                        widget.onToggleAudioOnly,
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Column(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.hdr_on),
                                        color: Colors.pink,
                                        iconSize: sideSize + 4,
                                        onPressed:
                                        widget.onToggleFilters,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.volume_up),
                                        color: Colors.white,
                                        onPressed: widget.onVolume,
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.speed),
                                        color: Colors.white,
                                        onPressed:
                                        widget.onCyclePlaybackRate,
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                            Icons.picture_in_picture_alt),
                                        color: Colors.white,
                                        onPressed:
                                        widget.onToggleFloting,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            /// ⏱ SLIDER
                            Row(
                              children: [
                                Text(
                                  _format(_position),
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: RepaintBoundary(
                                    child: Slider(
                                      value:
                                      _progress.clamp(0.0, 1.0),
                                      onChanged: (v) {
                                        widget.player
                                            .seek(_duration * v);
                                      },
                                      activeColor: Colors.redAccent,
                                      inactiveColor: Colors.white24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _format(_duration),
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11),
                                ),
                              ],
                            ),

                            /// ▶ PLAY CONTROLS
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon:
                                  const Icon(Icons.lock_open),
                                  color: Colors.white,
                                  onPressed:
                                  widget.onToggleLock,
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.skip_previous),
                                  color: Colors.white,
                                  iconSize: sideSize + 4,
                                  onPressed: widget.onPrevious,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.replay_10),
                                  color: Colors.white,
                                  iconSize: sideSize + 4,
                                  onPressed: () =>
                                      _seekBy(const Duration(
                                          seconds: -10)),
                                ),
                                IconButton(
                                  icon: Icon(
                                    globalPlayPause.isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                  ),
                                  color: Colors.white,
                                  iconSize: playSize + 8,
                                  onPressed: _togglePlayPause,
                                ),
                                IconButton(
                                  icon:
                                  const Icon(Icons.forward_10),
                                  color: Colors.white,
                                  iconSize: sideSize + 4,
                                  onPressed: () =>
                                      _seekBy(const Duration(
                                          seconds: 10)),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.skip_next),
                                  color: Colors.white,
                                  iconSize: sideSize + 4,
                                  onPressed: widget.onNext,
                                ),
                                IconButton(
                                  icon: Icon(
                                    widget.resizeMode ==
                                        VideoResizeMode.fit
                                        ? Icons.fit_screen
                                        : widget.resizeMode ==
                                        VideoResizeMode.fill
                                        ? Icons.crop
                                        : Icons.zoom_in_map,
                                  ),
                                  color: Colors.white,
                                  onPressed:
                                  widget.onToggleResizeMode,
                                ),
                              ],
                            ),
                            SizedBox(height: bottomPadding),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
