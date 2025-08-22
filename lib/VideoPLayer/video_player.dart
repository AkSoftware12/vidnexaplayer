import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // For SystemChrome
import '../RecentlyVideos/RecentlyPlayedManager/recently_played_manager.dart';
import 'custom_video_appBar.dart';

class VideoPlayerScreen extends StatefulWidget {
  final List<FileSystemEntity>? videos; // Made optional to support URL-only use case
  final int initialIndex;
  final String? url;

  VideoPlayerScreen({this.videos, this.initialIndex = 0, this.url});

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _videoPlayerController;
  bool _isControllerInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  int currentIndex = 0;
  Duration _currentPosition = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _showControls = false;
  Timer? _hideControlsTimer;

  bool _isZoomedIn = false;
  double _scale = 1.0; // Default scale (fit screen)



  @override
  void initState() {
    super.initState();
    // Lock orientation to portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    currentIndex = widget.initialIndex;

    // Check if a URL is provided, otherwise use the videos list
    if (widget.url != null && widget.url!.isNotEmpty) {
      _initializePlayer(widget.url!, isNetwork: true);
    } else if (widget.videos != null && widget.videos!.isNotEmpty) {
      _initializePlayer(widget.videos![currentIndex].path, isNetwork: false);
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'No valid video source provided';
      });
    }
  }

  Future<void> _initializePlayer(String source, {required bool isNetwork}) async {
    try {
      // Initialize controller based on source type (network or file)
      _videoPlayerController = isNetwork
          ? VideoPlayerController.networkUrl(Uri.parse(source))
          : VideoPlayerController.file(File(source));

      await _videoPlayerController.initialize();
      _videoPlayerController.addListener(() {
        setState(() {
          _currentPosition = _videoPlayerController.value.position;
        });
      });
      _videoPlayerController.setPlaybackSpeed(_playbackSpeed);
      _videoPlayerController.play();

      // Save the video to recently played list
      await RecentlyPlayedManager.addVideo(source);

      setState(() {
        _isControllerInitialized = true;
        _hasError = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize the video player: $e';
      });
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _videoPlayerController.dispose();
    // Reset orientation to allow all orientations when leaving the screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  void _toggleZoom() {
    setState(() {
      _isZoomedIn = !_isZoomedIn;
      _scale = _isZoomedIn ? 1.5 : 1.0; // Zoom in by 1.5x or reset to 1.0x
    });
  }

  void _playPause() {
    setState(() {
      if (_videoPlayerController.value.isPlaying) {
        _videoPlayerController.pause();
      } else {
        _videoPlayerController.play();
      }
    });
  }

  void _playNext() {
    if (widget.videos != null && currentIndex < widget.videos!.length - 1) {
      setState(() {
        currentIndex++;
        _initializePlayer(widget.videos![currentIndex].path, isNetwork: false);
      });
    }
  }

  void _playPrevious() {
    if (widget.videos != null && currentIndex > 0) {
      setState(() {
        currentIndex--;
        _initializePlayer(widget.videos![currentIndex].path, isNetwork: false);
      });
    }
  }

  void _toggleLock() {
    print('Lock toggled');
  }

  void _editVideo() {
    print('Edit video');
  }

  void _toggleAudio() {
    setState(() {
      final newVolume = _videoPlayerController.value.volume == 0.0 ? 1.0 : 0.0;
      _videoPlayerController.setVolume(newVolume);
    });
  }

  void _changeSpeed() {
    setState(() {
      _playbackSpeed = _playbackSpeed == 1.0 ? 2.0 : 1.0;
      _videoPlayerController.setPlaybackSpeed(_playbackSpeed);
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$minutes:$seconds";
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _hideControlsTimer?.cancel();
        _hideControlsTimer = Timer(Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _showControls = false;
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _hasError
          ? Center(child: Text(_errorMessage, style: TextStyle(color: Colors.white)))
          : Stack(
        children: [
          GestureDetector(
            onTap: _toggleControls,
            child: Container(
              color: Colors.black,
              height: double.infinity,
            ),
          ),
          Center(
            child: _isControllerInitialized
                ? GestureDetector(
              onTap: _toggleControls,
              child: Transform.scale(
                scale: _scale,
                child: AspectRatio(
                  aspectRatio: _videoPlayerController.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController),
                ),
              ),
            )
                : CircularProgressIndicator(color: Colors.white),
          ),
          if (_isControllerInitialized && _showControls)
            GestureDetector(
              onTap: _toggleControls,
              child: Container(
                height: double.infinity,
                color: Colors.black26,
              ),
            ),
          if (_isControllerInitialized && _showControls)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'PoppinsSemiBold',
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: _videoPlayerController.value.isInitialized &&
                            _videoPlayerController.value.duration.inSeconds > 0
                            ? Slider(
                          value: _currentPosition.inSeconds.toDouble(),
                          min: 0.0,
                          max: _videoPlayerController.value.duration.inSeconds.toDouble(),
                          activeColor: Colors.red,
                          inactiveColor: Colors.grey,
                          onChanged: (value) {
                            setState(() {
                              _currentPosition = Duration(seconds: value.toInt());
                              _videoPlayerController.seekTo(_currentPosition);
                            });
                          },
                        )
                            : Slider(
                          value: 0.0,
                          min: 0.0,
                          max: 1.0,
                          activeColor: Colors.red,
                          inactiveColor: Colors.grey,
                          onChanged: null,
                        ),
                      ),
                      Text(
                        _formatDuration(_videoPlayerController.value.duration),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontFamily: 'PoppinsSemiBold',
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: Colors.black54,
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.lock, color: Colors.white),
                          onPressed: _toggleLock,
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 35.sp),
                          onPressed: widget.videos != null ? _playPrevious : null, // Disable if no videos
                        ),
                        IconButton(
                          icon: Icon(
                            _videoPlayerController.value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: Colors.white,
                            size: 50.sp,
                          ),
                          onPressed: _playPause,
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next_rounded, color: Colors.white, size: 35.sp),
                          onPressed: widget.videos != null ? _playNext : null, // Disable if no videos
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            icon: Icon(
                              _isZoomedIn ? Icons.crop : Icons.fit_screen,
                              color: Colors.white,
                              size: 20.sp,
                            ),
                            onPressed: _toggleZoom,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          if (_isControllerInitialized && _showControls)
            Positioned(
              right: 10,
              bottom: 100.sp,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.lock, color: Colors.white),
                    onPressed: _toggleLock,
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: _editVideo,
                  ),
                  IconButton(
                    icon: Icon(Icons.audiotrack, color: Colors.white),
                    onPressed: _toggleAudio,
                  ),
                  IconButton(
                    icon: Icon(Icons.speed, color: Colors.white),
                    onPressed: _changeSpeed,
                  ),
                ],
              ),
            ),
          if (_isControllerInitialized && _showControls)
            Positioned(
              left: 10,
              bottom: 100.sp,
              child: Column(
                children: [
                  IconButton(
                    icon: Icon(Icons.lock, color: Colors.white),
                    onPressed: _toggleLock,
                  ),
                  IconButton(
                    icon: Icon(Icons.edit, color: Colors.white),
                    onPressed: _editVideo,
                  ),
                  IconButton(
                    icon: Icon(Icons.audiotrack, color: Colors.white),
                    onPressed: _toggleAudio,
                  ),
                  IconButton(
                    icon: Icon(Icons.speed, color: Colors.white),
                    onPressed: _changeSpeed,
                  ),
                ],
              ),
            ),
          if (_isControllerInitialized && _showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: CustomVideoAppBar(
                title: widget.url != null
                    ? widget.url!.split('/').last
                    : widget.videos != null
                    ? widget.videos![currentIndex].path.split('/').last
                    : 'Video',
                onBackPressed: () => Navigator.pop(context),
              ),
            ),
        ],
      ),
    );
  }
}