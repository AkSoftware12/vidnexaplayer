import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import '../../NotifyListeners/PlayPauseSync/play_pause.dart';
import '../custom_video_appBar.dart';
import 'CustomVideoControls/custom_video_controls.dart';
import 'FlotingVideo/floting_video.dart';

final globalPlayPause = PlayPauseSync();

class FullScreenVideoPlayer extends StatefulWidget {
  final List<AssetEntity> videos;
  final int initialIndex;
  final Player? externalPlayer;
  final VideoController? externalController;

  const FullScreenVideoPlayer({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.externalPlayer,
    this.externalController,
  });

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late int _currentIndex;
  late final Player _player;
  late final VideoController _controller;
  double _volumePercent = 100; // 0–100 display slider
  // double get _volume => _volumePercent / 100;
  bool _isLoading = true;
  bool _showLogo = false;
  String _selectedFilter = "normal";
  Timer? _systemUiTimer;

  // Equalizer sliders
  double bassGain = 0.0;
  double midGain = 0.0;
  double trebleGain = 0.0;



  // Additional state
  bool _isLocked = false;
  bool _equalizerVisible = false;
  bool _filtersVisible = false;
  bool _audioOnly = false;
  double _playbackRate = 1.0;
  final List<double> _rateOptions = [0.5, 1.0, 1.5, 2.0];

  // Orientation state: tracks whether we're forcing landscape.
  bool _isLandscapeMode = false;

  // Variables for gesture seeking
  bool _isDragging = false;
  double _dragStartX = 0.0;
  Duration _dragStartPosition = Duration.zero;

  // For skip overlay
  bool _showSkipOverlay = false;
  int _skipDirection = 0; // -1 for backward, 1 for forward
  Timer? _skipOverlayTimer;


  // 🟦 Brightness / Volume gesture state
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _brightnessTimer;
  Timer? _volumeTimer;
  bool _verticalDragLeft = false;
  bool _verticalDragRight = false;



  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (widget.externalPlayer != null && widget.externalController != null) {
      // Use existing player from floating overlay
      _player = widget.externalPlayer!;
      _controller = widget.externalController!;
      _isLoading = false;
    } else {
      _player = Player();
      _controller = VideoController(_player);
      _loadVideo();

    }

    // Initialize brightness
    ScreenBrightness().current.then((value) {
      _brightness = value;
    });

    // Initialize & track volume
    _player.stream.volume.listen((v) {
      _volume = v;
    });

    _player.stream.completed.listen((completed) async {
      if (completed) {
        if (_currentIndex == widget.videos.length - 1) {
          setState(() => _showLogo = true);
          await _player.pause();
          await Future.delayed(const Duration(seconds: 5));
          if (mounted) setState(() => _showLogo = true);
        } else {
          await _playNext();
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _hideBottomBar());

    // Default orientation is portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

  }

  Future<void> _loadVideo() async {
    setState(() {
      _isLoading = true;
      _showLogo = false;
    });
    final file = await widget.videos[_currentIndex].file;
    if (file != null) {
      await _player.open(Media(file.path), play: false);
      await Future.delayed(const Duration(milliseconds: 100));
      await _player.play();
    }
    setState(() => _isLoading = false);
  }

  // Equalizer adjustment
  Future<void> _applyEqualizer() async {
    final weightedGain =
        (bassGain * 0.6 + midGain * 0.3 + trebleGain * 0.1) / 15.0;
    final volume = (1.0 + weightedGain).clamp(0.5, 1.5);
    await _player.setVolume(volume);
  }

  Future<void> _playNext() async {
    if (_currentIndex < widget.videos.length - 1) {
      _currentIndex++;
      await _player.stop();
      await _loadVideo();
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _player.stop();
      await _loadVideo();
    }
  }

  void _changeFilter(String filter) {
    setState(() => _selectedFilter = filter);
  }

  List<double> _getColorMatrix(String filter) {
    switch (filter) {
      case "dark":
        return [
          0.6, 0, 0, 0, 0, //
          0, 0.6, 0, 0, 0, //
          0, 0, 0.6, 0, 0, //
          0, 0, 0, 1.0, 0,
        ];
      case "blue":
        return [
          0.4, 0.2, 0.2, 0, 0, //
          0.2, 0.4, 0.2, 0, 0.05, //
          0.3, 0.3, 1.3, 0, 0.15, //
          0, 0, 0, 1, 0,
        ];
      case "warm":
        return [
          1.6, 0.3, 0.1, 0, -30, //
          0.2, 1.4, 0.1, 0, -30, //
          0.1, 0.2, 1.1, 0, -20, //
          0, 0, 0, 1.0, 0,
        ];
      case "sepia":
        return [
          0.5, 0.8, 0.2, 0, 0, //
          0.4, 0.7, 0.2, 0, 0, //
          0.2, 0.5, 0.1, 0, 0, //
          0, 0, 0, 1, 0,
        ];
      case "neon":
        return [
          1.2, 0.3, 0.8, 0, 0.1, //
          0.2, 0.7, 1.0, 0, 0.05, //
          0.8, 0.2, 1.4, 0, 0.1, //
          0, 0, 0, 1, 0,
        ];
      default:
        return [
          1, 0, 0, 0, 0, //
          0, 1, 0, 0, 0, //
          0, 0, 1, 0, 0, //
          0, 0, 0, 1, 0,
        ];
    }
  }

  Widget _buildFilterButton(String label, Color color, String filter) {
    final isSelected = _selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: () => _changeFilter(filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.8) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.black : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlider(
      String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        Slider(
          value: value,
          min: -15,
          max: 15,
          divisions: 30,
          activeColor: Colors.deepPurpleAccent,
          inactiveColor: Colors.white24,
          label: "${value.toStringAsFixed(1)} dB",
          onChanged: (v) {
            onChanged(v);
            _applyEqualizer();
          },
        ),
      ],
    );
  }

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
  }
  @override


  Future<void> _takeScreenshot() async {
    try {
      final Uint8List? data =
      await _player.screenshot(format: 'image/png');
      if (data != null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Screenshot captured')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screenshot failed: $e')),
        );
      }
    }
  }

  Future<void> _toggleAudioOnly() async {
    setState(() {
      _audioOnly = !_audioOnly;
    });
    try {
      if (_audioOnly) {
        await _player.setVideoTrack(VideoTrack.no());
      } else {
        await _player.setVideoTrack(VideoTrack.auto());
      }
    } catch (_) {}
  }

  Future<void> _cyclePlaybackRate() async {
    final currentIndex = _rateOptions.indexOf(_playbackRate);
    final nextIndex = (currentIndex + 1) % _rateOptions.length;
    final nextRate = _rateOptions[nextIndex];
    setState(() => _playbackRate = nextRate);
    await _player.setRate(nextRate);
  }

  void _toggleOrientation() {
    setState(() => _isLandscapeMode = !_isLandscapeMode);
    if (_isLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    if (_isLandscapeMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleEqualizer() {
    setState(() => _equalizerVisible = !_equalizerVisible);
  }

  void _toggleFilters() {
    setState(() => _filtersVisible = !_filtersVisible);
  }

  void _hideBottomBar() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top],
    );
  }

  void _showBottomBarTemporarily() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );
    _systemUiTimer?.cancel();
    _systemUiTimer = Timer(const Duration(seconds: 3), () {
      _hideBottomBar();
    });
  }

  void _onUserInteractionFromBottom(
      DragUpdateDetails details, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (details.localPosition.dy > screenHeight * 1 &&
        details.delta.dy < -5) {
      _showBottomBarTemporarily();
    }
  }

  // Gesture handlers for horizontal drag seeking
  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isLocked) return;
    final duration = _player.state.duration;
    if (duration.inMilliseconds <= 0) return;
    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _player.state.position;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isLocked) return;
    final duration = _player.state.duration;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx - _dragStartX;
    final relative = dx / screenWidth;
    final offsetMs = (duration.inMilliseconds * relative).toInt();
    int newMs = _dragStartPosition.inMilliseconds + offsetMs;
    newMs = newMs.clamp(0, duration.inMilliseconds);
    _player.seek(Duration(milliseconds: newMs));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
  }

  // 🟦 Vertical drag start: decide left/right for brightness/volume
  void _onVerticalDragStart(DragStartDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    _verticalDragLeft = dx < width * 0.5;
    _verticalDragRight = dx >= width * 0.5;
  }

  // 🟧 Vertical drag update: brightness (left) / volume (right)
  Future<void> _onVerticalDragUpdate(DragUpdateDetails details) async {
    _onUserInteractionFromBottom(details, context);
    if (_isLocked) return;

    final double delta = -details.delta.dy / 300; // smooth

    if (_verticalDragLeft) {
      // Brightness
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      try {
        await ScreenBrightness().setScreenBrightness(_brightness);
      } catch (_) {}

      setState(() => _showBrightnessOverlay = true);
      _brightnessTimer?.cancel();
      _brightnessTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showBrightnessOverlay = false);
        }
      });
    } else if (_verticalDragRight) {
      // Volume
      _volume = (_volume + delta).clamp(0.0, 1.0);
      await _player.setVolume(_volume);

      setState(() => _showVolumeOverlay = true);
      _volumeTimer?.cancel();
      _volumeTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() => _showVolumeOverlay = false);
        }
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _verticalDragLeft = false;
    _verticalDragRight = false;
  }

  void _onDoubleTapDown(TapDownDetails details) {
    if (_isLocked) return;
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;
    final position = _player.state.position;
    final duration = _player.state.duration;
    if (duration.inMilliseconds <= 0) return;
    if (dx < width / 2) {
      // Left side: rewind 10 seconds
      final newPositionMs =
      (position.inMilliseconds - 10000).clamp(0, duration.inMilliseconds);
      _player.seek(Duration(milliseconds: newPositionMs));
      setState(() {
        _skipDirection = -1;
        _showSkipOverlay = true;
      });
    } else {
      // Right side: forward 10 seconds
      final newPositionMs =
      (position.inMilliseconds + 10000).clamp(0, duration.inMilliseconds);
      _player.seek(Duration(milliseconds: newPositionMs));
      setState(() {
        _skipDirection = 1;
        _showSkipOverlay = true;
      });
    }
    // Hide overlay after a short delay
    _skipOverlayTimer?.cancel();
    _skipOverlayTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showSkipOverlay = false);
    });
  }

  @override
  void dispose() {
    // Dispose player only if no floating overlay is active.
    if (!FloatingVideoManager.isActive) {
      _player.dispose();
    }
    _systemUiTimer?.cancel();
    _skipOverlayTimer?.cancel();
    _brightnessTimer?.cancel();
    _volumeTimer?.cancel();


    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == widget.videos.length - 1;
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final double sideControlsTop = isLandscape
        ? MediaQuery.of(context).size.height * 0.15
        : MediaQuery.of(context).size.height * 0.25;
    final double filtersBottom = isLandscape ? 60 : 120;
    final double equalizerBottom = isLandscape ? 70 : 130;

    // Video widget
    final videoWidget = ColorFiltered(
      colorFilter: ColorFilter.matrix(_getColorMatrix(_selectedFilter)),
      child: Video(controller: _controller, controls: null),
    );

    return WillPopScope(
      onWillPop: () async {
        // If leaving this page, show floating overlay.
        FloatingVideoManager.show(
          context,
          _player,
          _controller,
          widget.videos,
          _currentIndex,
        );
        return true; // allow pop
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onDoubleTapDown: _onDoubleTapDown,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _isLoading
              ? const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
              : Stack(
            children: [
              Positioned.fill(child: videoWidget),

              // Show skip overlay when double tapped
              if (_showSkipOverlay)
                Center(
                  child: Icon(
                    _skipDirection == -1
                        ? Icons.replay_10
                        : Icons.forward_10,
                    color: Colors.white,
                    size: 80,
                  ),
                ),

              if (_showBrightnessOverlay)
                Positioned(
                  left: 20,
                  top: MediaQuery.of(context).size.height * 0.2,
                  child: Container(
                    width: 40,
                    height: MediaQuery.of(context).size.height * 0.5,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.brightness_6, color: Colors.yellow, size: 26),
                        SizedBox(height: 10),
                        Expanded(
                          child: RotatedBox(
                            quarterTurns: -1,
                            child: Slider(
                              value: _brightness,
                              onChanged: (v) async {
                                _brightness = v;
                                await ScreenBrightness().setScreenBrightness(v);
                                setState(() {});
                              },
                              activeColor: Colors.yellow,
                              inactiveColor: Colors.white24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),


    if (_showVolumeOverlay)
    Positioned(
    right: 20,
    top: MediaQuery.of(context).size.height * 0.2,
    child: Container(
    width: 40,
    height: MediaQuery.of(context).size.height * 0.5,
    decoration: BoxDecoration(
    color: Colors.black54,
    borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
    Icon(
    _volumePercent == 0 ? Icons.volume_off : Icons.volume_up,
    color: Colors.greenAccent,
    size: 26,
    ),
    SizedBox(height: 10),
    Expanded(
    child: RotatedBox(
    quarterTurns: -1,
    child: Slider(
    value: _volumePercent,
    min: 0,
    max: 100,
    onChanged: (value) async {
    _volumePercent = value;

    // convert 0–100 → 0–1
    await _player.setVolume(_volumePercent / 100);

    setState(() {});
    },
    activeColor: Colors.greenAccent,
    inactiveColor: Colors.white24,
    ),
    ),
    ),
    ],
    ),
    ),
    ),

              // Locked overlay
              if (_isLocked)
                Center(
                  child: GestureDetector(
                    onTap: _toggleLock,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Colors.green,
                        size: 60,
                      ),
                    ),
                  ),
                ),


              // Controls
              if (!_isLocked)
                Positioned(
                  top: 25,
                  left: 0,
                  right: 0,
                  child: CustomVideoAppBar(
                    title: widget.videos![_currentIndex].title.toString(),
                    onBackPressed: () async {
                      if (isLandscape) {
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
                        isLandscape = !isLandscape;
                      });
                    },

                    // videos: widget.videos,
                    currentIndex: _currentIndex,
                    onVideoSelected: (index) {
                      setState(() {
                        _currentIndex = index; // Update playing video
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

              if (!_isLocked)
                CustomVideoControls(
                  player: _player,
                  onNext: _playNext,
                  onPrevious: _playPrevious,
                  onToggleEqualizer: _toggleEqualizer,
                  onToggleFilters: _toggleFilters,
                  onToggleOrientation: _toggleOrientation,
                  onToggleFloting: () {
                    FloatingVideoManager.show(
                                  context,
                                  _player,
                                  _controller,
                                  widget.videos,
                                  _currentIndex,
                                );
                                Navigator.pop(context);
                  },
                  onTakeScreenshot: _takeScreenshot,
                  onToggleAudioOnly: _toggleAudioOnly,
                  onToggleLock: _toggleLock,
                  audioOnly: _audioOnly,
                  onCyclePlaybackRate: _cyclePlaybackRate,
                  PlaybackRate: _playbackRate.toString(),
                  index: _currentIndex,
                  videos:widget.videos,



                ),

              // Filters overlay
              if (!_isLocked && _filtersVisible)
                Positioned(
                  bottom: filtersBottom.toDouble(),
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFilterButton(
                            "Normal", Colors.white, "normal"),
                        _buildFilterButton(
                            "Dark", Colors.black87, "dark"),
                        _buildFilterButton(
                            "Blue", HexColor('#0000FF'), "blue"),
                        _buildFilterButton("Warm HDR",
                            Colors.deepOrangeAccent, "warm"),
                        _buildFilterButton(
                            "Sepia", Colors.redAccent, "sepia"),
                        _buildFilterButton(
                            "Neon", Colors.purpleAccent, "neon"),
                      ],
                    ),
                  ),
                ),

              // Equalizer overlay
              if (!_isLocked && _equalizerVisible)
                Positioned(
                  bottom: equalizerBottom.toDouble(),
                  left: 10,
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSlider("Bass (60Hz)", bassGain,
                                (v) => setState(() => bassGain = v)),
                        _buildSlider("Mid (1kHz)", midGain,
                                (v) => setState(() => midGain = v)),
                        _buildSlider("Treble (10kHz)", trebleGain,
                                (v) => setState(() => trebleGain = v)),
                      ],
                    ),
                  ),
                ),

              // Logo overlay at end
              if (_showLogo && isLast)
                AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 600),
                  child: Center(
                    child: Container(
                      color: Colors.black.withOpacity(0.7),
                      height: 200,
                      width: 200,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/appblue.png',
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Vidnexa Player',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
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
    );
  }
}
