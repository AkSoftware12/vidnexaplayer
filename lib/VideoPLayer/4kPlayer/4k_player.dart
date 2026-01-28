import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import '../../NotifyListeners/PlayPauseSync/play_pause.dart';
import '../custom_video_appBar.dart';
import 'CustomVideoControls/custom_video_controls.dart';
import 'FlotingVideo/floting_video.dart';
import 'HDR/hdr.dart';
import 'PopupPlayer/Speed/speed.dart';
import 'PopupPlayer/Volume/volume.dart';

/// This file provides a revised implementation of the full screen video player
/// that fixes a few issues reported in the original widget:
///   * The native system volume overlay now remains hidden while still
///     allowing the application to control the system volume via the
///     `volume_controller` plugin.  According to the plugin documentation,
///     setting `VolumeController.instance.showSystemUI` to `false` disables
///     the operating system’s volume HUD【88287368509493†L331-L336】.
///   * A built‑in progress bar has been added at the bottom of the
///     player.  This progress bar listens to the player's position and
///     duration streams and uses a `Slider` to let users scrub through
///     the video.  When the user drags the slider thumb, the underlying
///     player seeks in real time to the new position.  This addresses
///     feedback that the original slider didn’t move the video forward.
///   * Horizontal seeking gestures are now ignored when the drag starts
///     within the bottom 20 % of the screen.  This prevents the
///     underlying `GestureDetector` from stealing pointer events from
///     interactive controls (such as sliders) placed near the bottom
///     of the screen.
///   * The player’s position is tracked locally (`_currentPosition`)
///     alongside the total duration (`_totalDuration`) to keep the
///     progress bar in sync with playback.
///
/// Drop this file into your project to replace the existing
/// `FullScreenVideoPlayerFixed` implementation.  It retains the
/// majority of the original behaviour—playback, brightness/volume
/// gestures, equaliser, filters, floating window, etc.—but fixes the
/// issues related to system volume UI and video scrubbing.

final globalPlayPause = PlayPauseSync();

enum VideoResizeMode {
  fit,
  fill,
  zoom,
  stretch,
}

class FullScreenVideoPlayerFixed extends StatefulWidget {
  final List<AssetEntity> videos;
  final int initialIndex;
  final Player? externalPlayer;
  final VideoController? externalController;

  const FullScreenVideoPlayerFixed({
    super.key,
    required this.videos,
    required this.initialIndex,
    this.externalPlayer,
    this.externalController,
  });

  @override
  State<FullScreenVideoPlayerFixed> createState() =>
      _FullScreenVideoPlayerSystemVolumeState();
}

class _FullScreenVideoPlayerSystemVolumeState
    extends State<FullScreenVideoPlayerFixed> {
  late int _currentIndex;
  late final Player _player;
  late final VideoController _controller;
  VideoResizeMode _resizeMode = VideoResizeMode.fit;

  // Track the system volume in 0–100 range.  This is updated via
  // VolumeController.listener and used for UI controls.
  double _systemVolume = 100.0;
  StreamSubscription<double>? _volumeSubscription;
  bool get isLandscape =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  bool _controlsVisible = true;
  Timer? _hideTimer;

  bool _isLoading = true;
  bool _showLogo = false;
  String _selectedFilter = 'normal';
  Timer? _systemUiTimer;

  // Equalizer sliders (dB)
  double bassGain = 0.0;
  double midGain = 0.0;
  double trebleGain = 0.0;

  bool _isLocked = false;
  bool _equalizerVisible = false;
  bool _filtersVisible = false;
  bool _audioOnly = false;
  double _playbackRate = 1.0;
  final List<double> _rateOptions = [0.5, 1.0, 1.5, 2.0];

  bool _isLandscapeMode = false;

  bool _isDragging = false;
  double _dragStartX = 0.0;
  Duration _dragStartPosition = Duration.zero;

  bool _showSkipOverlay = false;
  int _skipDirection = 0;
  Timer? _skipOverlayTimer;

  double _brightness = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _brightnessTimer;
  Timer? _volumeTimer;
  bool _verticalDragLeft = false;
  bool _verticalDragRight = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  // Track playback position & duration for the progress bar.
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  StreamSubscription<bool>? _playingSub;


  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (widget.externalPlayer != null && widget.externalController != null) {
      _player = widget.externalPlayer!;
      _controller = widget.externalController!;
      _isLoading = false;
    } else {
      _player = Player();
      _controller = VideoController(_player);
      _loadVideo();
    }

    // Set player's internal volume to 100% so system volume controls the loudness.
    _player.setVolume(100);

    // Initialise brightness
    ScreenBrightness().current.then((value) => _brightness = value);

    // Hide the native operating system volume UI.  The
    // volume_controller plugin provides a `showSystemUI` variable to
    // control this behaviour.  Setting it to `false` prevents the
    // OS‑level volume HUD from being displayed【88287368509493†L331-L336】.
    VolumeController.instance.showSystemUI = false;

    // Initialise system volume and listener.
    VolumeController.instance.getVolume().then((v) {
      setState(() {
        _systemVolume = v * 100;
      });
    });
    _volumeSubscription = VolumeController.instance.addListener((
        double volume,
        ) {
      setState(() {
        _systemVolume = volume * 100;
      });
    }, fetchInitialVolume: false);

    // Listen to player position & duration changes so we can update
    // the progress bar.  When the player position updates, we
    // convert it to a Duration and store it locally.  Similarly for
    // duration.
    _positionSub = _player.stream.position.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });
    _durationSub = _player.stream.duration.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startHideTimer();
      _hideBottomBar();
    });

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      globalPlayPause.update(playing);
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();

    final duration = isLandscape
        ? const Duration(seconds: 5)
        : const Duration(seconds: 5);

    _hideTimer = Timer(duration, () {
      if (mounted && !_isLocked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onScreenTap() {
    if (_isLocked) return;

    setState(() => _controlsVisible = true);
    _startHideTimer();
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

  Future<void> _applyEqualizer() async {
    final weightedGain =
        (bassGain * 0.6 + midGain * 0.3 + trebleGain * 0.1) / 15.0;
    final factor = (1.0 + weightedGain).clamp(0.5, 1.5);
    // Set the player's internal volume based on the factor (0.5–1.5 of 100)
    final newVolume = (factor * 100).clamp(0.0, 100.0);
    await _player.setVolume(newVolume);
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

  void _toggleResizeMode() {
    setState(() {
      if (_resizeMode == VideoResizeMode.fit) {
        _resizeMode = VideoResizeMode.fill;
      } else if (_resizeMode == VideoResizeMode.fill) {
        _resizeMode = VideoResizeMode.zoom;
      } else if (_resizeMode == VideoResizeMode.zoom) {
        _resizeMode = VideoResizeMode.stretch;
      } else {
        _resizeMode = VideoResizeMode.fit;
      }
    });

    showCenterToast(context, _resizeMode.name.toUpperCase());
  }

  void showCenterToast(BuildContext context, String message) {
    final OverlayEntry entry = OverlayEntry(
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: AnimatedScale(
            scale: 1,
            duration: const Duration(milliseconds: 150),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // Insert Overlay
    Overlay.of(context).insert(entry);

    // Auto remove
    Future.delayed(const Duration(milliseconds: 900)).then((_) {
      entry.remove();
    });
  }

  List<double> _getColorMatrix(String filter) {
    switch (filter) {
      case 'dark':
        return [
          0.6,
          0,
          0,
          0,
          0,
          0,
          0.6,
          0,
          0,
          0,
          0,
          0,
          0.6,
          0,
          0,
          0,
          0,
          0,
          1.0,
          0,
        ];
      case 'blue':
        return [
          0.4,
          0.2,
          0.2,
          0,
          0,
          0.2,
          0.4,
          0.2,
          0,
          0.05,
          0.3,
          0.3,
          1.3,
          0,
          0.15,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'warm':
        return [
          1.6,
          0.3,
          0.1,
          0,
          -30,
          0.2,
          1.4,
          0.1,
          0,
          -30,
          0.1,
          0.2,
          1.1,
          0,
          -20,
          0,
          0,
          0,
          1.0,
          0,
        ];
      case 'sepia':
        return [
          0.5,
          0.8,
          0.2,
          0,
          0,
          0.4,
          0.7,
          0.2,
          0,
          0,
          0.2,
          0.5,
          0.1,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'neon':
        return [
          1.2,
          0.3,
          0.8,
          0,
          0.1,
          0.2,
          0.7,
          1.0,
          0,
          0.05,
          0.8,
          0.2,
          1.4,
          0,
          0.1,
          0,
          0,
          0,
          1,
          0,
        ];
      case 'green':
        return [
          0.0,
          1.0,
          0.0,
          0,
          0,
          0.0,
          1.2,
          0.0,
          0,
          0,
          0.0,
          1.0,
          0.0,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ];
      default:
        return [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
    }
  }

  double hdrIntensity = 0.7; // 0..1

  List<double> fakeHdrMatrix({double intensity = 0.65}) {
    // intensity: 0.0 to 1.0
    final c = 1.0 + (0.55 * intensity); // contrast
    final s = 1.0 + (0.75 * intensity); // saturation
    final b = 6.0 * intensity; // brightness lift (small)

    // Luma coefficients
    const r = 0.2126;
    const g = 0.7152;
    const bl = 0.0722;

    final ir = (1 - s) * r;
    final ig = (1 - s) * g;
    final ib = (1 - s) * bl;

    // Saturation matrix
    final m00 = ir + s;
    final m01 = ig;
    final m02 = ib;

    final m10 = ir;
    final m11 = ig + s;
    final m12 = ib;

    final m20 = ir;
    final m21 = ig;
    final m22 = ib + s;

    // Contrast: scale RGB around 128 (for 0-255 range)
    final t = 128.0 * (1 - c) + b;

    return [
      c * m00,
      c * m01,
      c * m02,
      0,
      t,
      c * m10,
      c * m11,
      c * m12,
      0,
      t,
      c * m20,
      c * m21,
      c * m22,
      0,
      t,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  Widget _buildSlider(
      String label,
      double value,
      ValueChanged<double> onChanged,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Slider(
          value: value,
          min: -15,
          max: 15,
          divisions: 30,
          activeColor: Colors.deepPurpleAccent,
          inactiveColor: Colors.white24,
          label: '${value.toStringAsFixed(1)} dB',
          onChanged: (v) {
            onChanged(v);
            _applyEqualizer();
          },
        ),
      ],
    );
  }

  void _toggleLock() {
    setState(() => _isLocked = !_isLocked);
  }

  Future<void> _takeScreenshot() async {
    try {
      final Uint8List? data = await _player.screenshot(format: 'image/png');
      if (data != null) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: 'Screenshot captured',
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 14,
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Screenshot failed: $e')));
      }
    }
  }

  Future<void> _toggleAudioOnly() async {
    setState(() => _audioOnly = !_audioOnly);
    try {
      if (_audioOnly) {
        await _player.setVideoTrack(VideoTrack.no());
      } else {
        await _player.setVideoTrack(VideoTrack.auto());
      }
    } catch (_) {}
  }

  void _openSpeedDialog() {
    PlaybackSpeedDialog.show(
      context,
      currentSpeed: _playbackRate,
      onSpeedChange: (speed) async {
        setState(() => _playbackRate = speed);
        await _player.setRate(speed);
      },
    );
  }

  void _openVolumeDialog() {
    VolumeDialog.show(
      context,
      currentVolume: _systemVolume / 100.0,
      onVolumeChange: (v) async {
        // Clamp and set system volume.  The dialog returns 0–1.
        final clamped = v.clamp(0.0, 1.0);
        await VolumeController.instance.setVolume(clamped);
        setState(() {
          _systemVolume = clamped * 100;
        });
      },
    );
  }

  void _toggleOrientation() {
    setState(() => _isLandscapeMode = !_isLandscapeMode);
    if (_isLandscapeMode) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleEqualizer() {
    setState(() => _equalizerVisible = !_equalizerVisible);
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
      DragUpdateDetails details,
      BuildContext context,
      ) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (details.localPosition.dy > screenHeight * 1 && details.delta.dy < -5) {
      _showBottomBarTemporarily();
    }
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_isLocked) return;
    // Prevent horizontal seeking gestures from interfering with UI
    // controls placed near the bottom of the screen.  If the user
    // starts a drag in the bottom 20% of the screen, we ignore it.
    final screenHeight = MediaQuery.of(context).size.height;
    if (details.localPosition.dy > screenHeight * 0.8) {
      _isDragging = false;
      return;
    }
    final duration = _player.state.duration;
    if (duration.inMilliseconds <= 0) return;
    _isDragging = true;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _player.state.position;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_isDragging || _isLocked) return;
    final duration = _player.state.duration;
    if (duration.inMilliseconds <= 0) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx - _dragStartX;
    final relative = dx / screenWidth;
    final offsetMs = (duration.inMilliseconds * relative).toInt();
    int newMs = _dragStartPosition.inMilliseconds + offsetMs;
    newMs = newMs.clamp(0, duration.inMilliseconds);
    final newPos = Duration(milliseconds: newMs);
    _player.seek(newPos);
    setState(() {
      _currentPosition = newPos;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;
    _isDragging = false;
  }

  void _onVerticalDragStart(DragStartDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;
    _verticalDragLeft = dx < width * 0.5;
    _verticalDragRight = dx >= width * 0.5;
  }

  Future<void> _onVerticalDragUpdate(DragUpdateDetails details) async {
    _onUserInteractionFromBottom(details, context);
    if (_isLocked) return;
    if (_verticalDragLeft) {
      final delta = -details.delta.dy / 300;
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      try {
        await ScreenBrightness().setScreenBrightness(_brightness);
      } catch (_) {}
      setState(() => _showBrightnessOverlay = true);
      _brightnessTimer?.cancel();
      _brightnessTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showBrightnessOverlay = false);
      });
    } else if (_verticalDragRight) {
      final drag = -details.delta.dy;
      // Perfect speed
      const sensitivity = 0.75;
      double newVolume = _systemVolume + drag * sensitivity;
      newVolume = newVolume.clamp(0.0, 100.0);
      // Apply to system
      await VolumeController.instance.setVolume(newVolume / 100);
      setState(() {
        _systemVolume = newVolume;
        _showVolumeOverlay = true;
      });
      _volumeTimer?.cancel();
      _volumeTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showVolumeOverlay = false);
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
      final newPositionMs = (position.inMilliseconds - 10000).clamp(
        0,
        duration.inMilliseconds,
      );
      _player.seek(Duration(milliseconds: newPositionMs));
      setState(() {
        _skipDirection = -1;
        _showSkipOverlay = true;
        _currentPosition = Duration(milliseconds: newPositionMs);
      });
    } else {
      final newPositionMs = (position.inMilliseconds + 10000).clamp(
        0,
        duration.inMilliseconds,
      );
      _player.seek(Duration(milliseconds: newPositionMs));
      setState(() {
        _skipDirection = 1;
        _showSkipOverlay = true;
        _currentPosition = Duration(milliseconds: newPositionMs);
      });
    }
    _skipOverlayTimer?.cancel();
    _skipOverlayTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showSkipOverlay = false);
    });
  }

  @override
  void dispose() {
    if (!FloatingVideoManager.isActive) {
      _player.dispose();
    }
    _positionSub.cancel();
    _durationSub.cancel();
    _systemUiTimer?.cancel();
    _skipOverlayTimer?.cancel();
    _brightnessTimer?.cancel();
    _volumeTimer?.cancel();
    _volumeSubscription?.cancel();
    VolumeController.instance.removeListener();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _playingSub?.cancel();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always restart hide timer on orientation change
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLocked) {
        setState(() => _controlsVisible = true);
        _startHideTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final double equalizerBottom = isLandscape ? 70 : 130;
    final playSize = isLandscape ? 22.sp : 45.sp;
    final sideSize = isLandscape ? 15.sp : 28.sp;
    final bottomPadding = isLandscape ? 0.sp : 40.sp;
    final videoWidget = ColorFiltered(
      // You can uncomment this line and choose an actual filter for the video
      // colorFilter: ColorFilter.matrix(_getColorMatrix(_selectedFilter)),
      colorFilter: ColorFilter.matrix(fakeHdrMatrix(intensity: hdrIntensity)),
      child: Video(
        controller: _controller,
        fit: _resizeMode == VideoResizeMode.fit
            ? BoxFit.contain
            : _resizeMode == VideoResizeMode.fill
            ? BoxFit.cover
            : _resizeMode == VideoResizeMode.zoom
            ? BoxFit.fill
            : BoxFit.none,
        controls: null,
      ),
    );
    return WillPopScope(
      onWillPop: () async {
        FloatingVideoManager.show(
          context,
          _player,
          _controller,
          widget.videos,
          _currentIndex,
        );
        return true;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        onTap: _onScreenTap,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _isLoading
              ? const Center(
            child: CupertinoActivityIndicator(
              radius: 25,
              color: Colors.white,
              animating: true,
            ),
          )
              : Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragStart: _onHorizontalDragStart,
                    onHorizontalDragUpdate: _onHorizontalDragUpdate,
                    onHorizontalDragEnd: _onHorizontalDragEnd,
                    onDoubleTapDown: _onDoubleTapDown,
                    child: videoWidget),
              ),
              // subtle vignette
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.0,
                      colors: [
                        const Color(0x00000000),
                        const Color(0x22000000), // darkness edge
                      ],
                      stops: const [0.65, 1.0],
                    ),
                  ),
                ),
              ),
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
                Builder(
                  builder: (context) {
                    final screenHeight =
                        MediaQuery.of(context).size.height;
                    final barHeight = screenHeight * 0.3;
                    final brightnessValue = (_brightness * 100).round();
                    return Positioned(
                      left: 20,
                      top: screenHeight / 2 - barHeight / 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Vertical brightness bar
                          Container(
                            width: 40,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: double.infinity,
                                height: barHeight * _brightness,
                                decoration: BoxDecoration(
                                  color: ColorSelect.maineColor2,
                                  // Top round hide when brightness is full
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(
                                      _brightness >= 0.99 ? 20 : 20,
                                    ),
                                    bottom: const Radius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Icon + brightness value
                          Row(
                            children: [
                              const Icon(
                                Icons.brightness_6,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                brightnessValue.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              if (_showVolumeOverlay)
                Builder(
                  builder: (context) {
                    final screenHeight =
                        MediaQuery.of(context).size.height;
                    final barHeight = screenHeight * 0.3;
                    final volValue = _systemVolume.round();
                    return Positioned(
                      right: 20,
                      top: screenHeight / 2 - barHeight / 2,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Icon + Number
                          Row(
                            children: [
                              Icon(
                                _systemVolume <= 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white,
                                size: 32,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                volValue.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          // Smooth animated bar
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: _systemVolume / 100,
                            ),
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOut,
                            builder: (context, animValue, child) {
                              return Container(
                                width: 40,
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    height: barHeight * animValue,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.vertical(
                                        bottom: Radius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
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
                        _buildSlider(
                          'Bass (60Hz)',
                          bassGain,
                              (v) => setState(() => bassGain = v),
                        ),
                        _buildSlider(
                          'Mid (1kHz)',
                          midGain,
                              (v) => setState(() => midGain = v),
                        ),
                        _buildSlider(
                          'Treble (10kHz)',
                          trebleGain,
                              (v) => setState(() => trebleGain = v),
                        ),
                      ],
                    ),
                  ),
                ),

              if (!_isLocked && _controlsVisible && _totalDuration.inMilliseconds > 0)
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        color: Colors.black.withOpacity(0.4),
                        child: Padding(
                          padding: EdgeInsets.only(top: isLandscape ? 0.sp : 40.sp),
                          child: CustomVideoAppBar(
                            title: widget.videos[_currentIndex].title ?? '',
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
                            currentIndex: _currentIndex,
                            onVideoSelected: (_) {},
                            isLandscape: isLandscape,
                            videos: widget.videos,
                          ),
                        ),
                      ),
                      // Bottom controls
                      Column(
                        children: [
                          Stack(
                            children: [
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Column(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.camera_alt),
                                      color: Colors.white,
                                      onPressed: (){
                                        _takeScreenshot();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.screen_rotation),
                                      color: Colors.white,
                                      onPressed: (){
                                        _toggleOrientation();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.headphones),
                                      color: _audioOnly == true
                                          ? Colors.greenAccent
                                          : Colors.white,
                                      onPressed: (){
                                        _toggleAudioOnly();
                                      },
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
                                      onPressed: (){
                                        FilterPopup.show(
                                          context,
                                          selectedKey: _selectedFilter,
                                          onSelected: (key) {
                                            setState(() => _selectedFilter = key);
                                          },
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.volume_up),
                                      color: Colors.white,
                                      onPressed: (){
                                        _openVolumeDialog();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.speed),
                                      color: Colors.white,
                                      onPressed: (){
                                        _openSpeedDialog();
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.picture_in_picture_alt),
                                      color: Colors.white,
                                      onPressed: (){
                                        FloatingVideoManager.show(
                                          context,
                                          _player,
                                          _controller,
                                          widget.videos,
                                          _currentIndex,
                                        );
                                        Navigator.pop(context);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              /// ⏱ START TIME (current position)
                              Text(
                                _formatDuration(_currentPosition),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),

                              const SizedBox(width: 8),

                              /// 🎚 SLIDER (4K style)
                              Expanded(
                                child: Slider(
                                  value: _currentPosition.inMilliseconds
                                      .clamp(0, _totalDuration.inMilliseconds)
                                      .toDouble(),
                                  min: 0.0,
                                  max: _totalDuration.inMilliseconds.toDouble(),
                                  activeColor: Colors.green,
                                  inactiveColor: Colors.white54,
                                  onChanged: (value) {
                                    final newPos =
                                    Duration(milliseconds: value.round());
                                    _player.seek(newPos);
                                    setState(() {
                                      _currentPosition = newPos;
                                    });
                                  },
                                ),
                              ),

                              const SizedBox(width: 8),

                              /// ⏱ TOTAL TIME (end duration)
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.lock_open),
                                color: Colors.white,
                                onPressed:(){
                                  _toggleLock();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.skip_previous),
                                color: Colors.white,
                                iconSize: sideSize + 4,
                                onPressed: (){
                                  _playPrevious();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.replay_10),
                                color: Colors.white,
                                iconSize: sideSize + 4,
                                onPressed: () => _seekBy(const Duration(seconds: -10)),
                              ),
                              IconButton(
                                  icon: Icon(
                                    globalPlayPause.isPlaying
                                        ? Icons.pause_circle_filled
                                        : Icons.play_circle_fill,
                                  ),
                                  color: Colors.white,
                                  iconSize: playSize + 8,
                                  onPressed: (){
                                    _togglePlayPause();

                                  }
                              ),
                              IconButton(
                                icon: const Icon(Icons.forward_10),
                                color: Colors.white,
                                iconSize: sideSize + 4,
                                onPressed: () => _seekBy(const Duration(seconds: 10)),
                              ),
                              IconButton(
                                  icon: const Icon(Icons.skip_next),
                                  color: Colors.white,
                                  iconSize: sideSize + 4,
                                  onPressed: (){
                                    _playNext();

                                  }
                              ),
                              IconButton(
                                icon: Icon(
                                  _resizeMode == VideoResizeMode.fit
                                      ? Icons.fit_screen
                                      : _resizeMode == VideoResizeMode.fill
                                      ? Icons.crop
                                      : Icons.zoom_in_map,
                                ),
                                color: Colors.white,
                                onPressed:(){
                                  _toggleResizeMode();
                                },
                              ),
                            ],
                          ),
                          SizedBox(
                            height: bottomPadding,
                          )
                        ],
                      ),

                    ],
                  ),




            ],
          ),
        ),
      ),
    );
  }
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPause() async {
    _isPlaying ? _player.pause() : _player.play();
  }

  Future<void> _seekBy(Duration offset) async {
    await _player.seek(_currentPosition + offset);

  }

}