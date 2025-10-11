import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter/services.dart'; // For SystemChrome
import '../RecentlyVideos/RecentlyPlayedManager/recently_played_manager.dart';
import '../Utils/color.dart';
import 'custom_video_appBar.dart';
import 'package:screenshot/screenshot.dart';


class VideoPlayerScreen extends StatefulWidget {
  final List<FileSystemEntity>?videos;
  final int initialIndex;
  final String? url;

  const VideoPlayerScreen({this.videos, this.initialIndex = 0, this.url});

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
  double _scale = 1.0; // Default scale (fit screen)
  ScreenshotController screenshotController = ScreenshotController();
  double _brightness = 1.0; // default Light
  ThemeMode _themeMode = ThemeMode.light;
  bool _isLocked = false; // Add this as a state variable in your StatefulWidget
  bool _isVolumeOn = true;
  bool _isHDR = false;
  String _selectedOption = 'HDR'; // Default selection

  // List of zoom levels
  // Zoom levels (double ke saath ek "null" stretch ke liye)
  final List<double?> _zoomLevels = [1.0, 5.0, 10.0, 15.0, null];

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

  Future<void> _initializePlayer(
    String source, {
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
      await RecentlyPlayedManager.addVideo(source);

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
            '${directory.path}/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
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



  void _toggleAudio() {
    setState(() {
      _isMuted = !_isMuted;
      final newVolume = _isMuted ? 0.0 : 1.0;
      _videoPlayerController.setVolume(newVolume);
    });
  }

  Future<void> _adjustVolume() async {
    final double originalVolume = _videoPlayerController.value.volume;
    double newVolume = originalVolume;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.1), // dim transparent bg
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent, // keep transparent
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 40,
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3), // semi-transparent bg
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
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
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // Restore state when closing
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
                    const SizedBox(height: 16),
                    // Volume %
                    Text(
                      "${(newVolume * 100).toInt()}%",
                      style: GoogleFonts.radioCanada(
                        fontSize: 26.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text("0%", style: TextStyle(color: Colors.white70)),
                        Text("100%", style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Add this function
  Future<void> _changeSpeed() async {
    final double originalSpeed = _playbackSpeed; // Store original for cancel
    double newSpeed = _playbackSpeed;
    await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Adjust Speed",
                    style: GoogleFonts.radioCanada(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _playbackSpeed = originalSpeed;
                        _videoPlayerController.setPlaybackSpeed(originalSpeed);
                      });
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close, color: Colors.red[600]),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speed value display
                  Text(
                    "${newSpeed.toStringAsFixed(1)}x",
                    style: GoogleFonts.radioCanada(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: ColorSelect.maineColor,
                    ),
                  ),
                  SizedBox(height: 12.sp),
                  // Linear Slider (like a progress bar for speed)
                  Slider(
                    value: newSpeed,
                    min: 0.5,
                    max: 3.0,
                    divisions: 25,
                    // For 0.5 to 3.0 in 0.1 steps
                    activeColor: ColorSelect.maineColor,
                    inactiveColor: Colors.grey[300],
                    onChanged: (value) {
                      setDialogState(() {
                        newSpeed = value;
                      });
                      // Real-time update to player
                      setState(() {
                        _playbackSpeed = value;
                      });
                      _videoPlayerController.setPlaybackSpeed(value);
                    },
                  ),
                  // Progress-like labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "0.5x",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        "1.0x",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        "2.0x",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                        ),
                      ),
                      Text(
                        "3.0x",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: ColorSelect.maineColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    setDialogState(() {
                      newSpeed = 1.0; // Reset to 1.0x
                    });
                    // Immediately update player
                    setState(() {
                      _playbackSpeed = 1.0;
                    });
                    _videoPlayerController.setPlaybackSpeed(1.0);
                  },
                  child: Text(
                    "Reset",
                    style: TextStyle(
                      color: ColorSelect.maineColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
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
                    _videoPlayerController.setPlaybackSpeed(originalSpeed);
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
            );
          },
        );
      },
    );
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

  Future<void> _toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      setState(() => _themeMode = ThemeMode.dark);
      await ScreenBrightness().setScreenBrightness(0.1); // 👈 actual brightness
    } else {
      setState(() => _themeMode = ThemeMode.light);
      await ScreenBrightness().setScreenBrightness(1.0); // 👈 full brightness
    }
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

  void _showPremiumHDRDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title:  Center(
            child: Text(
              "Select Display Mode",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
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




  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                    fontFamily: 'PoppinsSemiBold',
                                  ),
                                ),
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.7,
                                  child:
                                      _videoPlayerController
                                                  .value
                                                  .isInitialized &&
                                              _videoPlayerController
                                                      .value
                                                      .duration
                                                      .inSeconds >
                                                  0
                                          ? Slider(
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
                                                _videoPlayerController.seekTo(
                                                  _currentPosition,
                                                );
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
                                  _formatDuration(
                                    _videoPlayerController.value.duration,
                                  ),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.lock, color: Colors.white),
                                    onPressed: _toggleLock,
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.skip_previous_rounded,
                                      color: Colors.white,
                                      size: 35.sp,
                                    ),
                                    onPressed:
                                        widget.videos != null
                                            ? _playPrevious
                                            : null, // Disable if no videos
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
                                    icon: Icon(
                                      Icons.skip_next_rounded,
                                      color: Colors.white,
                                      size: 35.sp,
                                    ),
                                    onPressed:
                                        widget.videos != null
                                            ? _playNext
                                            : null, // Disable if no videos
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: IconButton(
                                      icon: Icon(
                                        _zoomIcons[_currentZoomIndex],
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
                    if (_isControllerInitialized && _showControls && !_isLocked)
                      Positioned(
                        right: 10,
                        bottom: 100.sp,
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(3.sp),
                              child: IconButton(
                                icon: Icon(
                                  _themeMode == ThemeMode.dark
                                      ? Icons
                                          .dark_mode // 👈 Light ka icon
                                      : Icons.light_mode, // 👈 Dark ka icon
                                  color: Colors.white,
                                ),
                                onPressed: _toggleTheme, // 👈 toggle function
                                tooltip: "Toggle Theme",
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(3.sp),
                              child: IconButton(
                                icon: Icon(
                                  Icons.volume_up,
                                  color: Colors.white,
                                ),
                                onPressed: _adjustVolume,
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.all(3.sp),
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
                        left: 10,
                        bottom: 100.sp,
                        child: Column(
                          children: [
                            // HDR badge
                            // if (_isHDR)
                            Padding(
                              padding: EdgeInsets.all(8.sp),
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
                            Padding(
                              padding: EdgeInsets.all(3.sp),
                              child: IconButton(
                                icon: Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                                onPressed: _takeScreenshot,
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.all(3.sp),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.equalizer,
                                  color: Colors.white,
                                  size: 28,
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
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  height: 4,
                                                  width: 40,
                                                  margin: const EdgeInsets.only(
                                                    bottom: 16,
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
                                                                (
                                                                  v,
                                                                ) => setSheetState(
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
                                                      () => Navigator.pop(
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

                            Padding(
                              padding: EdgeInsets.all(3.sp),
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
                                child: IconButton(
                                  icon: Icon(
                                    _isVolumeOn
                                        ? Icons.volume_off
                                        : Icons.volume_off,
                                    color: Colors.white,
                                    size: 20.sp,
                                  ),
                                  onPressed: _toggleVolume,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isControllerInitialized && _showControls && !_isLocked)
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
                          videos: widget.videos,
                          currentIndex: currentIndex,
                          onVideoSelected: (index) {
                            setState(() {
                              currentIndex = index; // Update playing video
                              _initializePlayer(widget.videos![index].path, isNetwork: false);
                            });
                          },
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
    );
  }
}
