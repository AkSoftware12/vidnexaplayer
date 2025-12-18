import 'dart:async';

import 'package:flutter/cupertino.dart';
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
    });

    // Sync to global PlayPauseSync for floating window
    widget.player.stream.playing.listen((playing) {
      globalPlayPause.update(playing);
    });
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await widget.player.pause();
    } else {
      await widget.player.play();
    }
  }

  Future<void> _seekBy(Duration offset) async {
    final pos = _position + offset;
    await widget.player.seek(pos);
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double playSize = isLandscape ? 22.sp : 45.sp;
    final double sideSize = isLandscape ? 15.sp : 28.sp;
    final double appBar = isLandscape ? 20.sp : 100.sp;
    final double bottom = isLandscape ? 0.sp : 40.sp;
    return GestureDetector(
      onTap: () => setState(() => _visible = !_visible),
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: isLandscape?3:40,
              left: 0,
              right: 0,
              child: CustomVideoAppBar(
                title: widget.videos[widget.index].title.toString(),
                onBackPressed: () {
                  if (isLandscape) {
                    // Switch back to portrait
                     SystemChrome.setPreferredOrientations([
                      DeviceOrientation.portraitUp,
                      DeviceOrientation.portraitDown,
                    ]);

                    SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.manual,
                      overlays: SystemUiOverlay.values, // dono bars visible
                    );
                  } else {
                     ScreenBrightness().resetScreenBrightness();
                    Navigator.pop(context);
                  }
                  setState(() {
                    isLandscape = !isLandscape;
                  });
                },
                currentIndex: widget.index,
                onVideoSelected: (index) {
                  setState(() {
                    // widget.index = index; // Update playing video
                    // _initializePlayer(
                    //   '',
                    //   // widget.videos![index].path,
                    //   isNetwork: false,
                    // );
                  });
                },
                isLandscape: isLandscape,
                videos: widget.videos,
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black12,
                padding: EdgeInsets.symmetric(horizontal: 0.sp, vertical: 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Column(
                            children: [
                              // GestureDetector(
                              //   onTap: widget.onToggleEqualizer,
                              //   child: Image.asset(
                              //     'assets/equalizer.png',
                              //     height: 35,
                              //     width: 35,
                              //   ),
                              // ),
                              SizedBox(
                                height: 5,
                              ),

                              IconButton(
                                icon: const Icon(Icons.camera_alt),
                                color: Colors.white,
                                iconSize: 24,
                                onPressed: widget.onTakeScreenshot,
                              ),

                              IconButton(
                                icon: const Icon(Icons.screen_rotation),
                                color: Colors.white,
                                iconSize: 24,
                                onPressed: widget.onToggleOrientation,
                              ),
                              Padding(
                                padding: EdgeInsets.only(bottom: 12.0),
                                child: IconButton(
                                  icon: const Icon(Icons.headphones),
                                  color:
                                      widget.audioOnly == true
                                          ? Colors.greenAccent
                                          : Colors.white,
                                  iconSize: 24,
                                  onPressed: widget.onToggleAudioOnly,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          // top: sideControlsTop,
                          right: 0,
                          bottom: 0,

                          child: Padding(
                            padding: EdgeInsets.only(
                              right: isLandscape ? 15.sp : 0.sp,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: widget.onToggleFilters,
                                  child: Image.asset(
                                    'assets/hdr.png',
                                    height: 35,
                                    width: 35,
                                    color: Colors.pink,
                                  ),
                                ),

                                //
                                IconButton(
                                  icon: Icon(
                                    Icons.volume_up,
                                    color: Colors.white,
                                  ),
                                  onPressed: widget.onVolume,
                                  iconSize: 24,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.speed),
                                  color: Colors.white,
                                  iconSize: 24,
                                  onPressed: widget.onCyclePlaybackRate,
                                ),

                                Padding(
                                  padding: EdgeInsets.only(bottom: 12.0),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.picture_in_picture_alt,
                                    ),
                                    color: Colors.white,
                                    iconSize: 24,
                                    onPressed: widget.onToggleFloting,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          // Current Position Time
                          Text(
                            _format(_position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),

                          SizedBox(width: 4),

                          // Slider
                          Expanded(
                            child: Slider(
                              value: _progress.clamp(0.0, 1.0),
                              onChanged: (v) {
                                final newPos = _duration * v;
                                widget.player.seek(newPos);
                              },
                              activeColor: Colors.redAccent,
                              inactiveColor: Colors.white24,
                            ),
                          ),

                          SizedBox(width: 4),

                          // Total Duration
                          Text(
                            _format(_duration),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10),

                    /// COMPACT CONTROL ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.lock_open),
                          color: Colors.white,
                          iconSize: 24,
                          onPressed: widget.onToggleLock,
                        ),
                        Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.skip_previous_rounded),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          // ICONS CHOTE
                          onPressed: widget.onPrevious,
                        ),
                        SizedBox(width: 10),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.replay_10),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          onPressed:
                              () => _seekBy(const Duration(seconds: -10)),
                        ),
                        SizedBox(width: 10),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            globalPlayPause.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill,
                            color: Colors.white,
                            size: playSize + 8, // PLAY BUTTON bhi thoda chota
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        SizedBox(width: 10),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.forward_10),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          onPressed: () => _seekBy(const Duration(seconds: 10)),
                        ),
                        SizedBox(width: 10),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.skip_next_rounded),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          onPressed: widget.onNext,
                        ),
                        Spacer(),
                        IconButton(
                          icon: Icon(
                            widget.resizeMode == VideoResizeMode.fit
                                ? Icons.fit_screen
                                : widget.resizeMode == VideoResizeMode.fill
                                ? Icons.crop
                                : widget.resizeMode == VideoResizeMode.zoom
                                ? Icons.zoom_in_map
                                : Icons.open_in_full,
                            color: Colors.white,
                          ),
                          iconSize: 24,
                          onPressed: widget.onToggleResizeMode,
                        ),
                      ],
                    ),
                    SizedBox(height: bottom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showVolumeDialog(
    BuildContext context, {
    required double initialVolume,
    required Function(double) onVolumeChange,
  }) async {
    double newVolume = initialVolume;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.75,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Volume",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 25),

                      // Slider
                      Slider(
                        value: newVolume,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        activeColor: Colors.blueAccent,
                        onChanged: (value) {
                          setState(() => newVolume = value);
                          onVolumeChange(value);
                        },
                      ),

                      const SizedBox(height: 10),

                      // Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              newVolume = 1.0;
                              onVolumeChange(1.0);
                              setState(() {});
                            },
                            child: const Text(
                              "Max",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              "Close",
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
