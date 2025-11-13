import 'dart:async';
import 'package:floating/floating.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // For SystemChrome
import '../Home/HomeScreen/home_screen.dart';
import '../Utils/color.dart';
import 'custom_video_appBar.dart';
import 'package:screenshot/screenshot.dart';
import 'package:photo_manager/photo_manager.dart';



class VideoPlayerScreen extends StatefulWidget {
  final List<AssetEntity> videos;
  final int initialIndex;
  final String? url;

  const VideoPlayerScreen({required this.videos, required this.initialIndex, this.url});

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
  bool _isMuted = false; // Track mute state
  bool _isZoomedIn = false;
  double _scale = 1.3; // Default scale (fit screen)
  ScreenshotController screenshotController = ScreenshotController();
  double _brightness = 1.0; // default Light
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLocked = false; // Add this as a state variable in your StatefulWidget
  bool _isVolumeOn = true;
  bool _isHDR = false;
  String _selectedOption = 'HDR'; // Default selection

  final List<double?> _zoomLevels = [1.5, 2.0, 6.0,9.0, null];

  // null => stretch mode

  final List<IconData> _zoomIcons = [
    Icons.fit_screen, // for 1.0
    Icons.crop_square, // for 5.0
    Icons.zoom_out_map, // for 15.0
    Icons.crop, // for 20.0
    Icons.open_in_full, // for stretch
  ];

  int _currentZoomIndex = 0;
  bool _isStretch = false;

  @override
  void initState() {
    super.initState();
    _setFullBrightness();

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
      _initializePlayer(widget.videos[currentIndex].file.toString(), isNetwork: false);
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'No valid video source provided';
      });
    }
  }

  Future<void> _initializePlayer(String source, {
    required bool isNetwork,
  }) async {
    try {
      // Initialize controller based on source type (network or file)
      _videoPlayerController =
      isNetwork
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

      await Provider.of<VideoProvider>(
        context,
        listen: false,
      ).addToRecentlyPlayed(source);
      // await RecentlyPlayedManager.addVideo(source);

      // Check HDR detection (simple check based on format)
      if (_videoPlayerController.dataSource.toLowerCase().contains("hdr")) {
        _isHDR = true;
      }

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
      _currentZoomIndex = (_currentZoomIndex + 1) % _zoomLevels.length;

      if (_zoomLevels[_currentZoomIndex] == null) {
        // Stretch mode
        _isStretch = true;
      } else {
        _isStretch = false;
        _scale = _zoomLevels[_currentZoomIndex]!;
      }
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
        // _initializePlayer(widget.videos![currentIndex].path, isNetwork: false);
      });
    }
  }

  void _playPrevious() {
    if (widget.videos != null && currentIndex > 0) {
      setState(() {
        currentIndex--;
        // _initializePlayer(widget.videos![currentIndex].path, isNetwork: false);
      });
    }
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });

    Fluttertoast.showToast(
      msg: _isLocked ? "🔒 Screen Locked" : "🔓 Screen Unlocked",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: _isLocked ? Colors.red : Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  // 📸 Screenshot function (Gallery me save hoga)
  Future<void> _takeScreenshot() async {
    try {
      final image = await screenshotController.capture();
      if (image != null) {
        // Temporary directory me file save karo
        final directory = await getTemporaryDirectory();
        final filePath =
            '${directory.path}/screenshot_${DateTime
            .now()
            .millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(image);

        // Gallery me save karo
        await GallerySaver.saveImage(file.path, albumName: "MyAppScreenshots");

        Fluttertoast.showToast(
          msg: "✅ Screenshot capture!",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ Error: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.0,
      );
    }
  }


  // Add this function

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


  void _toggleVolume() {
    setState(() {
      _isVolumeOn = !_isVolumeOn;

      if (_isVolumeOn) {
        _videoPlayerController.setVolume(1.0); // 🔊 volume on
      } else {
        _videoPlayerController.setVolume(0.0); // 🔇 mute
      }
    });
  }

  String _selectedDisplayMode = 'Auto';
  bool _isHDRSupported = false; // Set true if your device supports HDR

  double? _previousBrightness;


  bool _isLandscape = false;

  void _toggleLandscape() async {
    if (_isLandscape) {
      // Switch back to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values, // dono bars visible
      );
    } else {
      // Switch to landscape
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.bottom], // bottom bar visible, top bar hide
      );
    }
    setState(() {
      _isLandscape = !_isLandscape;
    });
  }


  void skipForward() {
    final currentPosition = _videoPlayerController.value.position;
    final maxDuration = _videoPlayerController.value.duration;
    final newPosition = currentPosition + Duration(seconds: 10);

    _videoPlayerController.seekTo(
        newPosition > maxDuration ? maxDuration : newPosition);
  }

  void skipBackward() {
    final currentPosition = _videoPlayerController.value.position;
    final newPosition = currentPosition - Duration(seconds: 10);

    _videoPlayerController.seekTo(
        newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  Future<void> _setFullBrightness() async {
    try {
      _previousBrightness = await ScreenBrightness().current; // store current
      await ScreenBrightness().setScreenBrightness(1.0); // set to full brightness
    } catch (e) {
      debugPrint("Error setting brightness: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery
        .of(context)
        .orientation == Orientation.landscape;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Screenshot(
          controller: screenshotController,
          child:
          _hasError
              ? Center(
            child: Text(
              _errorMessage,
              style: TextStyle(color: Colors.white),
            ),
          )
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
                child:
                _isControllerInitialized
                    ? GestureDetector(
                  onTap: _toggleControls,
                  child: Transform.scale(
                    scale: _scale,
                    child: AspectRatio(
                      aspectRatio:
                      _videoPlayerController
                          .value
                          .aspectRatio,
                      child: VideoPlayer(_videoPlayerController),
                    ),
                  ),
                )
                    : CircularProgressIndicator(color: Colors.white),
              ),
              if (_isControllerInitialized && _showControls && !_isLocked)
                GestureDetector(
                  onTap: _toggleControls,
                  child: Container(
                    height: double.infinity,
                    color: Colors.black26,
                  ),
                ),
              if (_isControllerInitialized && _showControls && !_isLocked)
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
                              fontSize: isLandscape ? 5.sp : 12.sp,
                              // 👈 smaller text in landscape
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              fontFamily: 'PoppinsSemiBold',
                            ),
                          ),
                          SizedBox(
                            width:
                            MediaQuery
                                .of(context)
                                .size
                                .width *
                                (isLandscape ? 0.8 : 0.7),

                            child:
                            _videoPlayerController
                                .value
                                .isInitialized &&
                                _videoPlayerController
                                    .value
                                    .duration
                                    .inSeconds >
                                    0
                                ? SliderTheme(
                              data: SliderTheme.of(
                                context,
                              ).copyWith(
                                trackHeight: 3,
                                // track ki height chhoti karo
                                thumbShape:
                                RoundSliderThumbShape(
                                  enabledThumbRadius: 10,
                                ),
                                // thumb ka size chhota karo
                                overlayShape:
                                RoundSliderOverlayShape(
                                  overlayRadius: 20,
                                ), // touch overlay
                              ),
                              child: Slider(
                                value:
                                _currentPosition.inSeconds
                                    .toDouble(),
                                min: 0.0,
                                max:
                                _videoPlayerController
                                    .value
                                    .duration
                                    .inSeconds
                                    .toDouble(),
                                activeColor: Colors.red,
                                inactiveColor: Colors.grey,
                                onChanged: (value) {
                                  setState(() {
                                    _currentPosition = Duration(
                                      seconds: value.toInt(),
                                    );
                                    _videoPlayerController
                                        .seekTo(
                                      _currentPosition,
                                    );
                                  });
                                },
                              ),
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
                            _formatDuration(
                              _videoPlayerController.value.duration,
                            ),
                            style: TextStyle(
                              fontSize: isLandscape ? 5.sp : 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                              fontFamily: 'PoppinsSemiBold',
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: isLandscape ? 30.sp : 60.sp,
                      color: Colors.black54,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.lock,
                                color: Colors.white,
                                size: isLandscape ? 10.sp : 20.sp,
                              ),
                              onPressed: _toggleLock,
                            ),

                            Row(
                              children: [
                                Positioned(
                                  left: 30,
                                  child: IconButton(
                                    iconSize: isLandscape ? 15.sp : 25.sp,
                                    color: Colors.white,
                                    icon: Icon(Icons.replay_10),
                                    onPressed: skipBackward,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_previous_rounded,
                                    color: Colors.white,
                                    size: isLandscape ? 25.sp : 35.sp,
                                  ),
                                  onPressed:
                                  widget.videos != null
                                      ? _playPrevious
                                      : null,
                                ),
                                IconButton(
                                  icon: Icon(
                                    _videoPlayerController.value.isPlaying
                                        ? Icons.pause_circle
                                        : Icons.play_circle,
                                    color: Colors.white,
                                    size: isLandscape ? 25.sp : 50.sp,
                                  ),
                                  onPressed: _playPause,
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.skip_next_rounded,
                                    color: Colors.white,
                                    size: isLandscape ? 25.sp : 35.sp,
                                  ),
                                  onPressed:
                                  widget.videos != null
                                      ? _playNext
                                      : null,
                                ),
                                Positioned(
                                  right: 30,
                                  child: IconButton(
                                    iconSize: isLandscape ? 15.sp : 25.sp,
                                    color: Colors.white,
                                    icon: Icon(Icons.forward_10),
                                    onPressed: skipForward,
                                  ),
                                ),
                              ],
                            ),

                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: IconButton(
                                icon: Icon(
                                  _zoomIcons[_currentZoomIndex],
                                  color: Colors.white,
                                  size: isLandscape ? 10.sp : 20.sp,
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
              if (_isControllerInitialized && _showControls && !_isLocked)
                Positioned(
                  right: 10,
                  bottom: isLandscape ? 45.sp : 100.sp,
                  child: Column(
                    children: [
                      // 🌐 Landscape Mode Button
                      Padding(
                        padding:  EdgeInsets.only(bottom: 0.sp),
                        child: Padding(
                          padding:  EdgeInsets.all(3.sp),
                          child: Container(
                            height: isLandscape ?18.sp:null,

                            decoration: BoxDecoration(
                              color: ColorSelect.maineColor.withOpacity(
                                0.9,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.screen_rotation,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: _toggleLandscape,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(0.sp),
                        child: SizedBox(
                          height: isLandscape ?18.sp:null,
                          child: IconButton(
                            icon: Icon(
                              _themeMode == ThemeMode.dark
                                  ? Icons
                                  .dark_mode // 👈 Light ka icon
                                  : Icons.light_mode, // 👈 Dark ka icon
                              color: Colors.white,
                            ),
                            // onPressed: _toggleTheme,
                            onPressed: _adjustBrightness,
                            tooltip: "Toggle Theme",
                          ),
                        ),
                      ),
                      Padding(
                        padding:isLandscape ? EdgeInsets.all(0.sp): EdgeInsets.all(3.sp),
                        child: SizedBox(
                          height: isLandscape ?18.sp:null,

                          child: IconButton(
                            icon: Icon(
                              Icons.volume_up,
                              color: Colors.white,
                            ),
                            onPressed: _adjustVolume,
                          ),
                        ),
                      ),

                      Padding(
                        padding:isLandscape ? EdgeInsets.all(0.sp): EdgeInsets.all(3.sp),
                        child: IconButton(
                          icon: Icon(Icons.speed, color: Colors.white),
                          onPressed: _changeSpeed,
                        ),
                      ),
                    ],
                  ),
                ),

              if (_isControllerInitialized && _showControls && !_isLocked)
                Positioned(
                  left: 0,
                  bottom: isLandscape ? 45.sp : 100.sp,
                  child: Column(
                    children: [
                      // HDR badge
                      // if (_isHDR)
                      Padding(
                        padding:isLandscape ? EdgeInsets.all(0.sp): EdgeInsets.all(8.sp),
                        child: Padding(
                          padding:  EdgeInsets.only(bottom: 5.sp),
                          child: GestureDetector(
                            onTap: _showPremiumHDRDialog,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: ColorSelect.maineColor.withOpacity(
                                  0.8,
                                ), // Example color
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _selectedDisplayMode, // Shows the selected option
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:isLandscape ? EdgeInsets.all(0.sp): EdgeInsets.all(3.sp),
                        child: SizedBox(
                          height: isLandscape ?18.sp:null,
                          child: IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                            ),
                            onPressed: _takeScreenshot,
                          ),
                        ),
                      ),
                      Padding(
                        padding:isLandscape ? EdgeInsets.all(0.sp): EdgeInsets.all(3.sp),
                        child: SizedBox(
                          height: isLandscape ?18.sp:null,
                          child: IconButton(
                            icon: const Icon(
                              Icons.equalizer,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.black87,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                builder: (context) {
                                  double bass = 0.5;
                                  double mid = 0.5;
                                  double treble = 0.5;

                                  return StatefulBuilder(
                                    builder: (context, setSheetState) {
                                      return Padding(
                                        padding: const EdgeInsets.all(0.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              height: 4,
                                              width: 40,
                                              margin: const EdgeInsets.only(
                                                bottom: 0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.grey[600],
                                                borderRadius:
                                                BorderRadius.circular(
                                                  2,
                                                ),
                                              ),
                                            ),
                                            const Text(
                                              "Equalizer",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 20),

                                            // Vertical Sliders in a Row
                                            Row(
                                              mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceEvenly,
                                              children: [
                                                // Bass
                                                Column(
                                                  children: [
                                                    const Text(
                                                      "Normal",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    RotatedBox(
                                                      quarterTurns: -1,
                                                      child: Slider(
                                                        value: bass,
                                                        min: 0.0,
                                                        max: 1.0,
                                                        divisions: 10,
                                                        activeColor:
                                                        ColorSelect
                                                            .maineColor,
                                                        label: bass
                                                            .toStringAsFixed(
                                                          1,
                                                        ),
                                                        onChanged:
                                                            (v) =>
                                                            setSheetState(
                                                                  () =>
                                                              bass =
                                                                  v,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                // Bass
                                                Column(
                                                  children: [
                                                    const Text(
                                                      "Bass",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    RotatedBox(
                                                      quarterTurns: -1,
                                                      child: Slider(
                                                        value: bass,
                                                        min: 0.0,
                                                        max: 1.0,
                                                        divisions: 10,
                                                        activeColor:
                                                        ColorSelect
                                                            .maineColor,
                                                        label: bass
                                                            .toStringAsFixed(
                                                          1,
                                                        ),
                                                        onChanged:
                                                            (v) =>
                                                            setSheetState(
                                                                  () =>
                                                              bass =
                                                                  v,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Mid
                                                Column(
                                                  children: [
                                                    const Text(
                                                      "Mid",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    RotatedBox(
                                                      quarterTurns: -1,
                                                      child: Slider(
                                                        value: mid,
                                                        min: 0.0,
                                                        max: 1.0,
                                                        divisions: 10,
                                                        activeColor:
                                                        ColorSelect
                                                            .maineColor,
                                                        label: mid
                                                            .toStringAsFixed(
                                                          1,
                                                        ),
                                                        onChanged:
                                                            (v) =>
                                                            setSheetState(
                                                                  () =>
                                                              mid =
                                                                  v,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Treble
                                                Column(
                                                  children: [
                                                    const Text(
                                                      "Treble",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    RotatedBox(
                                                      quarterTurns: -1,
                                                      child: Slider(
                                                        value: treble,
                                                        min: 0.0,
                                                        max: 1.0,
                                                        divisions: 10,
                                                        activeColor:
                                                        ColorSelect
                                                            .maineColor,
                                                        label: treble
                                                            .toStringAsFixed(
                                                          1,
                                                        ),
                                                        onChanged:
                                                            (v,) =>
                                                            setSheetState(
                                                                  () =>
                                                              treble =
                                                                  v,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),

                                            const SizedBox(height: 20),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                ColorSelect.maineColor,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                  BorderRadius.circular(
                                                    8,
                                                  ),
                                                ),
                                              ),
                                              onPressed:
                                                  () =>
                                                  Navigator.pop(
                                                    context,
                                                  ),
                                              child: const Text("Close"),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),

                      Padding(
                        padding:isLandscape ? EdgeInsets.all(0.sp): EdgeInsets.all(3.sp),
                        child: Container(

                          decoration: BoxDecoration(
                            color:
                            _isVolumeOn
                                ? Colors
                                .transparent // 🔊 ON → no background
                                : ColorSelect.maineColor,
                            // 🔇 OFF → colored background
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: IconButton(
                              icon: Icon(
                                _isVolumeOn
                                    ? Icons.volume_off
                                    : Icons.volume_off,
                                color: Colors.white,
                              ),
                              onPressed: _toggleVolume,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isControllerInitialized && _showControls && !_isLocked)
                Positioned(
                  top: 5,
                  left: 0,
                  right: 0,
                  child: CustomVideoAppBar(
                    title:
                    widget.url != null
                        ? widget.url!.split('/').last
                        : widget.videos != null
                        ? widget.videos![currentIndex].title.toString()
                        : 'Video',
                    onBackPressed: () async {
                      if (_isLandscape) {
                        // Switch back to portrait
                        await SystemChrome.setPreferredOrientations([
                          DeviceOrientation.portraitUp,
                          DeviceOrientation.portraitDown,
                        ]);

                        SystemChrome.setEnabledSystemUIMode(
                          SystemUiMode.manual,
                          overlays: SystemUiOverlay.values, // dono bars visible
                        );
                      } else {
                        await ScreenBrightness().resetScreenBrightness();
                        Navigator.pop(context);
                      }
                      setState(() {
                        _isLandscape = !_isLandscape;
                      });
                    },

                    // videos: widget.videos,
                    currentIndex: currentIndex,
                    onVideoSelected: (index) {
                      setState(() {
                        currentIndex = index; // Update playing video
                        _initializePlayer(
                          '',
                          // widget.videos![index].path,
                          isNetwork: false,
                        );
                      });
                    },
                    isLandscape: isLandscape,
                    videos: null,
                  ),
                ),

              if (_showControls && _isLocked)
                Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      color: Colors.black54,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.lock,
                                color: Colors.redAccent,
                              ),
                              onPressed: _toggleLock,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }


  void _showPremiumHDRDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title:  Text(
            "Select Display Mode",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.start,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              _buildRadioOption('Auto'),
              _buildRadioOption('HDR'),
              _buildRadioOption('SDR'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioOption(String title) {
    return RadioListTile<String>(
      value: title,
      groupValue: _selectedDisplayMode,
      activeColor: Colors.white,
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 16),
      ),
      onChanged: (value) {
        if (value == 'HDR' && !_isHDRSupported) {
          Fluttertoast.showToast(
            msg: "Device not support",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.redAccent,
            textColor: Colors.white,
            fontSize: 16.0,
          );
          return; // do not select HDR or close dialog
        }

        setState(() {
          _selectedDisplayMode = value!;
        });

        Fluttertoast.showToast(
          msg: "$value",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: ColorSelect.maineColor,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        Navigator.pop(context); // close dialog after selection
      },
      toggleable: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
    );
  }

  Future<void> _changeSpeed() async {
    final double originalSpeed = _playbackSpeed; // store original
    double newSpeed = _playbackSpeed;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations
          .of(context)
          .modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        final media = MediaQuery.of(context);
        final isLandscape = media.orientation == Orientation.landscape;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? media.size.width * 0.55 : media.size
                  .width * 0.85,
              maxHeight: isLandscape ? media.size.height * 0.7 : media.size
                  .height * 0.7,
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                TextEditingController _textController = TextEditingController(
                  text: newSpeed.toStringAsFixed(1),
                );

                return Dialog(
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: EdgeInsets.all(5.sp),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Adjust Speed",
                                style: GoogleFonts.radioCanada(
                                  fontSize: isLandscape ? 8.sp : 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _playbackSpeed = originalSpeed;
                                    _videoPlayerController.setPlaybackSpeed(
                                        originalSpeed);
                                  });
                                  Navigator.pop(context);
                                },
                                icon: Icon(Icons.close, color: Colors.red[600]),
                              ),
                            ],
                          ),

                          // Speed display + edit icon
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${newSpeed.toStringAsFixed(1)}x",
                                style: GoogleFonts.radioCanada(
                                  fontSize: isLandscape ? 10.sp : 20.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 0.sp),
                              PlaybackSpeedPopup(
                                videoPlayerController: _videoPlayerController,
                                playbackSpeed: _playbackSpeed,
                                onSpeedChanged: (newSpeed) {
                                  setState(() {
                                    _playbackSpeed = newSpeed;
                                  });
                                },
                                isLandscape: isLandscape,)
                            ],
                          ),


                          // Slider
                          Slider(
                            value: newSpeed,
                            min: 0.1,
                            max: 3.0,
                            divisions: 25,
                            activeColor: ColorSelect.maineColor,
                            inactiveColor: Colors.grey[300],
                            onChanged: (value) {
                              setDialogState(() {
                                newSpeed = value;
                                _textController.text = value.toStringAsFixed(1);
                              });
                              setState(() {
                                _playbackSpeed = value;
                              });
                              _videoPlayerController.setPlaybackSpeed(value);
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("0.1x", style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isLandscape ? 7.sp : 12.sp,)),
                              Text("1.0x", style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isLandscape ? 7.sp : 12.sp,)),
                              Text("2.0x", style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isLandscape ? 7.sp : 12.sp,)),
                              Text("3.0x", style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: isLandscape ? 7.sp : 12.sp,)),
                            ],
                          ),

                          SizedBox(height: 10.sp),

                          // Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    newSpeed = 1.0;
                                    _textController.text = "1.0";
                                  });
                                  setState(() {
                                    _playbackSpeed = 1.0;
                                  });
                                  _videoPlayerController.setPlaybackSpeed(1.0);
                                },
                                child: Text(
                                  "Reset",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(width: 10.sp),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red[400]!),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _playbackSpeed = originalSpeed;
                                  });
                                  _videoPlayerController.setPlaybackSpeed(
                                      originalSpeed);
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  "Cancel",
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  Future<void> _adjustVolume() async {
    final double originalVolume = _videoPlayerController.value.volume;
    double newVolume = originalVolume;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54, // dim background
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        final media = MediaQuery.of(context);
        final isLandscape = media.orientation == Orientation.landscape;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? media.size.width * 0.55 : media.size.width * 0.85,
              maxHeight: isLandscape ? media.size.height * 0.8 : media.size.height * 0.7,
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15), // semi-transparent glass look
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Adjust Volume",
                                style: GoogleFonts.radioCanada(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _isMuted = originalVolume == 0.0;
                                    _videoPlayerController.setVolume(newVolume);
                                  });
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.close, color: Colors.white70),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),

                          // Volume Percentage
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                newVolume == 0
                                    ? Icons.volume_off
                                    : newVolume < 0.5
                                    ? Icons.volume_down
                                    : Icons.volume_up,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 10.sp),
                              Text(
                                "${(newVolume * 100).toInt()}%",
                                style: GoogleFonts.radioCanada(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 5.sp),

                          // Slider
                          SliderTheme(
                            data: SliderThemeData(
                              thumbColor: ColorSelect.maineColor,
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 10,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 18,
                              ),
                              overlayColor: Colors.white24,
                            ),
                            child: Slider(
                              value: newVolume,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              onChanged: (value) {
                                setDialogState(() {
                                  newVolume = value;
                                });
                                _videoPlayerController.setVolume(value);
                              },
                            ),
                          ),


                          // Volume Range Labels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text("0%", style: TextStyle(color: Colors.white70)),
                              Text("100%", style: TextStyle(color: Colors.white70)),
                            ],
                          ),


                          // Buttons (Mute/Unmute)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                icon: Icon(
                                  newVolume == 0 ? Icons.volume_off : Icons.volume_up,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  newVolume == 0 ? "Unmute" : "Mute",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 10),
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    if (newVolume == 0) {
                                      newVolume = originalVolume == 0 ? 0.5 : originalVolume;
                                    } else {
                                      newVolume = 0.0;
                                    }
                                    _videoPlayerController.setVolume(newVolume);
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
  Future<void> _adjustBrightness() async {
    // Use the screen brightness package:
    // Add dependency: screen_brightness: ^1.0.0 (in pubspec.yaml)

    double originalBrightness = await ScreenBrightness().current;
    double newBrightness = originalBrightness;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (context, _, __) {
        final media = MediaQuery.of(context);
        final isLandscape = media.orientation == Orientation.landscape;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isLandscape ? media.size.width * 0.55 : media.size.width * 0.85,
              maxHeight: isLandscape ? media.size.height * 0.8 : media.size.height * 0.7,
            ),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Dialog(
                  insetPadding: EdgeInsets.zero,
                  backgroundColor: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Adjust Brightness",
                                style: GoogleFonts.radioCanada(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.close, color: Colors.white70),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),

                          // Brightness percentage display
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                newBrightness == 0
                                    ? Icons.brightness_low
                                    : newBrightness < 0.5
                                    ? Icons.brightness_medium
                                    : Icons.brightness_high,
                                color: Colors.white,
                                size: 28,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "${(newBrightness * 100).toInt()}%",
                                style: GoogleFonts.radioCanada(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          // Brightness Slider
                          SliderTheme(
                            data: SliderThemeData(
                              thumbColor: ColorSelect.maineColor,
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white24,
                              trackHeight: 6,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                              overlayColor: Colors.white24,
                            ),
                            child: Slider(
                              value: newBrightness,
                              min: 0.0,
                              max: 1.0,
                              divisions: 10,
                              onChanged: (value) {
                                setDialogState(() => newBrightness = value);
                                ScreenBrightness().setScreenBrightness(value);
                              },
                            ),
                          ),

                          // Labels
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text("0%", style: TextStyle(color: Colors.white70)),
                              Text("100%", style: TextStyle(color: Colors.white70)),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.brightness_auto, color: Colors.white),
                                label: const Text(
                                  "Auto",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                ),
                                onPressed: () async {
                                  await ScreenBrightness().resetScreenBrightness();
                                  double autoBrightness = await ScreenBrightness().current;
                                  setDialogState(() => newBrightness = autoBrightness);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }


}


class PlaybackSpeedPopup extends StatefulWidget {
  final VideoPlayerController videoPlayerController;
  final double playbackSpeed;
  final bool isLandscape; // <-- add this
  final Function(double) onSpeedChanged;

  const PlaybackSpeedPopup(
      { super.key, required this.videoPlayerController, required this.playbackSpeed, required this.onSpeedChanged, required this.isLandscape,});

  @override State<PlaybackSpeedPopup> createState() =>
      _PlaybackSpeedPopupState();
}

class _PlaybackSpeedPopupState extends State<PlaybackSpeedPopup> {
  late TextEditingController _textController;
  late double _tempSpeed;
  final Color _blueAccent = Colors.blueAccent;

  @override void initState() {
    super.initState();
    _tempSpeed = widget.playbackSpeed.clamp(0.5, 3.0);
    _textController =
        TextEditingController(text: _tempSpeed.toStringAsFixed(2));
  }

  @override void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _showSpeedDialog() {
    showGeneralDialog(context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations
          .of(context)
          .modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: ScaleTransition(scale: CurvedAnimation(
              parent: animation, curve: Curves.easeOutBack), child: child,),);
      },
      pageBuilder: (context, _, __) {
        return AlertDialog(shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          elevation: 10,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 20),
          title: Row(children: [
            Icon(Icons.speed, color: ColorSelect.maineColor2,),
            const SizedBox(width: 12),
            Text("Playback Speed", style: TextStyle(color: Theme
                .of(context)
                .colorScheme
                .onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 15,
              letterSpacing: 0.8,),),
          ],),
          content: StatefulBuilder(builder: (context, setDialogState) {
            String? getErrorText() {
              final text = _textController.text.trim();
              if (text.isEmpty) return null;
              final val = double.tryParse(text);
              if (val == null || val < 0.5 || val > 3.0) {
                return "Enter a value between 0.5 and 3.0";
              }
              return null;
            }
            return SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children:
              [
                Text("Custom Speed", style: TextStyle(color: Theme
                    .of(context)
                    .colorScheme
                    .onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,),),
                const SizedBox(height: 12),
                TextField(controller: _textController,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [ FilteringTextInputFormatter.allow(RegExp(
                      r'^\d*\.?\d{0,2}$')),
                  ],
                  decoration: InputDecoration(hintText: "e.g., 1.50 (0.5–3.0)",
                    hintStyle: TextStyle(color: Theme
                        .of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.5),),
                    filled: true,
                    fillColor: Theme
                        .of(context)
                        .colorScheme
                        .surfaceVariant ?? Theme
                        .of(context)
                        .colorScheme
                        .surface
                        .withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius
                        .circular(16), borderSide: BorderSide.none,),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    prefixIcon: Icon(Icons.edit, color: ColorSelect.maineColor2, size: 22),
                    errorText: getErrorText(),
                    errorStyle: TextStyle(color: Theme
                        .of(context)
                        .colorScheme
                        .error, fontWeight: FontWeight.w500,),),
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500, color: Theme
                      .of(context)
                      .colorScheme
                      .onSurface,),
                  onChanged: (value) {
                    final parsed = double.tryParse(value);
                    if (parsed != null && parsed >= 0.5 && parsed <= 3.0) {
                      setDialogState(() => _tempSpeed = parsed);
                    }
                  },),
                const SizedBox(height: 24),
                Text("Fine-Tune Speed", style: TextStyle(color: Theme
                    .of(context)
                    .colorScheme
                    .onSurfaceVariant,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,),),
                const SizedBox(height: 12),
                SliderTheme(data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 15),
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                  valueIndicatorColor: ColorSelect.maineColor2,
                  valueIndicatorTextStyle: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600,),),
                  child: Slider(value: _tempSpeed.clamp(0.5, 3.0),
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    label: "${_tempSpeed.toStringAsFixed(2)}x",
                    onChanged: (value) {
                      setDialogState(() {
                        _tempSpeed = value;
                        _textController.text = value.toStringAsFixed(2);
                      });
                    },
                    activeColor: ColorSelect.maineColor2,
                    inactiveColor: ColorSelect.maineColor2.withOpacity(0.2),),),
                const SizedBox(height: 12),
                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow, color: ColorSelect.maineColor2, ),
                    const SizedBox(width: 6),
                    Text("Current: ${_tempSpeed.toStringAsFixed(2)}x",
                      style: TextStyle(color: ColorSelect.maineColor2,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,),),
                  ],),),
              ],),);
          },),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Theme
                  .of(context)
                  .colorScheme
                  .onSurfaceVariant,
                fontSize: 15,
                fontWeight: FontWeight.w600,),),),
            ElevatedButton(onPressed: () {
              final entered = double.tryParse(_textController.text);
              if (entered != null && entered >= 0.5 && entered <= 3.0) {
                widget.onSpeedChanged(entered);
                widget.videoPlayerController.setPlaybackSpeed(entered);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text(
                    "Please enter a value between 0.5 and 3.0",
                    style: TextStyle(fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white),),
                  backgroundColor: Theme
                      .of(context)
                      .colorScheme
                      .error,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),),);
              }
            },
              style: ElevatedButton.styleFrom(backgroundColor: ColorSelect.maineColor2,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 5),
                elevation: 3,
                shadowColor: _blueAccent.withOpacity(0.4),),
              child: const Text("Apply", style: TextStyle(fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,),),),
          ],);
      },);
  }

  @override Widget build(BuildContext context) {
    return IconButton(
      onPressed: (){
        Navigator.pop(context);
        _showSpeedDialog();
      },
      icon: Icon(Icons.edit, color:Colors.white, size: 30),
      tooltip: 'Adjust Playback Speed',);
  }
}
