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
  final String? PlaybackRate;
  final int index;
  final List<AssetEntity> videos;


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
    this.PlaybackRate,
     required this.index,
    required this.videos,
    this.onBackPressed,
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
              top: 25,
              left: 0,
              right: 0,
              child: CustomVideoAppBar(
                title: widget.videos[widget.index].title.toString(),
                onBackPressed: ()=> widget.onBackPressed,


                //     () async {
                //   if (isLandscape) {
                //     // Switch back to portrait
                //     await SystemChrome.setPreferredOrientations([
                //       DeviceOrientation.portraitUp,
                //       DeviceOrientation.portraitDown,
                //     ]);
                //
                //     SystemChrome.setEnabledSystemUIMode(
                //       SystemUiMode.manual,
                //       overlays: SystemUiOverlay.values, // dono bars visible
                //     );
                //   } else {
                //     await ScreenBrightness().resetScreenBrightness();
                //     Navigator.pop(context);
                //   }
                //   setState(() {
                //     isLandscape = !isLandscape;
                //   });
                // },

                // videos: widget.videos,
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



            // Align(
            //   alignment: Alignment.topCenter,
            //   child: SizedBox(
            //     height: appBar,
            //     child: Padding(
            //       padding: const EdgeInsets.all(0.0),
            //       child: Row(
            //         children: [
            //           IconButton(
            //             onPressed: () async {
            //               // 🔒 Lock app to Portrait only
            //               await SystemChrome.setPreferredOrientations([
            //                 DeviceOrientation.portraitUp,
            //               ]);
            //               if (Navigator.canPop(context)) {
            //                 Navigator.pop(context);
            //               }
            //             },
            //             icon: Icon(
            //               Icons.arrow_back,
            //               color: Colors.white,
            //               size: sideSize - 10,
            //             ),
            //           ),
            //
            //           SizedBox(width: 10),
            //           Expanded(
            //             child: Text(
            //               '${widget.title}',
            //               maxLines: 1,
            //               style: const TextStyle(
            //                 color: Colors.white,
            //                 fontSize: 18,
            //                 fontWeight: FontWeight.w600,
            //               ),
            //             ),
            //           ),
            //           IconButton(
            //             onPressed: () {
            //
            //             },
            //             icon: Icon(
            //               Icons.list,
            //               color: Colors.white,
            //               size: sideSize - 10,
            //             ),
            //           ),
            //           Padding(
            //             padding:  EdgeInsets.only(right:isLandscape ? 15.sp : 0.sp),
            //             child: IconButton(
            //               onPressed: () {
            //
            //               },
            //               icon: Icon(
            //                 Icons.playlist_play_outlined,
            //                 color: Colors.white,
            //                 size: sideSize - 10,
            //               ),
            //             ),
            //           ),
            //
            //         ],
            //       ),
            //     ),
            //   ),
            // ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                color: Colors.black54,
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
                              IconButton(
                                icon: const Icon(Icons.equalizer),
                                color: Colors.white,
                                iconSize: 28,
                                onPressed: widget.onToggleEqualizer,
                              ),
                              IconButton(
                                icon: const Icon(Icons.lock_open),
                                color: Colors.white,
                                iconSize: 32,
                                onPressed: widget.onToggleLock,
                              ),
                              IconButton(
                                icon: const Icon(Icons.camera_alt),
                                color: Colors.white,
                                iconSize: 28,
                                onPressed: widget.onTakeScreenshot,
                              ),
                              IconButton(
                                icon: const Icon(Icons.headphones),
                                color:
                                widget.audioOnly == true
                                    ? Colors.greenAccent
                                    : Colors.white,
                                iconSize: 28,
                                onPressed: widget.onToggleAudioOnly,
                              ),
                            ],
                          ),
                        ),

                        Positioned(
                          // top: sideControlsTop,
                          right: 0,
                          bottom: 0,

                          child: Padding(
                            padding:  EdgeInsets.only(right:isLandscape ? 15.sp : 0.sp),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_alt),
                                  color: Colors.white,
                                  iconSize: 28,
                                  onPressed: widget.onToggleFilters,
                                ),
                                GestureDetector(
                                  onTap: widget.onCyclePlaybackRate,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '${widget.PlaybackRate?.toString()}x',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        // IconButton(
                                        //   icon: const Icon(Icons.speed),
                                        //   color: Colors.white,
                                        //   iconSize: 28,
                                        //   onPressed:  widget.onCyclePlaybackRate,
                                        // ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.screen_rotation),
                                  color: Colors.white,
                                  iconSize: 28,
                                  onPressed: widget.onToggleOrientation,
                                ),
                                // Picture-in-picture button: show overlay and close page
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_in_picture_alt,
                                  ),
                                  color: Colors.white,
                                  iconSize: 28,
                                  onPressed: widget.onToggleFloting,
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
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.skip_previous_rounded),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          // ICONS CHOTE
                          onPressed: widget.onPrevious,
                        ),
                        SizedBox(width: 20),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.replay_10),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          onPressed:
                              () => _seekBy(const Duration(seconds: -10)),
                        ),
                        SizedBox(width: 20),

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
                        SizedBox(width: 20),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.forward_10),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          onPressed:
                              () => _seekBy(const Duration(seconds: 10)),
                        ),
                        SizedBox(width: 20),

                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.skip_next_rounded),
                          color: Colors.white,
                          iconSize: sideSize + 4,
                          onPressed: widget.onNext,
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
}
