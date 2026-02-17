import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:volume_controller/volume_controller.dart';

import '../../Home/HomeScreen/home2.dart';
import '../../NotifyListeners/PlayPauseSync/play_pause.dart';
import '../custom_video_appBar.dart';
import 'FlotingVideo/floting_video.dart';
import 'HDR/hdr.dart';
import 'PopupPlayer/Speed/speed.dart';
import 'PopupPlayer/Volume/volume.dart';

final globalPlayPause = PlayPauseSync();

enum VideoResizeMode { fit, fill, zoom, stretch }

class FullScreenVideoPlayerFixed extends StatefulWidget {
  /// ✅ Local list (can be empty for URL streaming mode)
  final List<AssetEntity> videos;

  /// ✅ Safe even if videos empty
  final int initialIndex;

  /// ✅ If provided -> plays this network link
  final String? initialUrl;

  final Player? externalPlayer;
  final VideoController? externalController;

  const FullScreenVideoPlayerFixed({
    super.key,
    this.videos = const [],
    this.initialIndex = 0,
    this.initialUrl,
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

  bool get _hasLocalList => widget.videos.isNotEmpty;

  bool get _hasUrl =>
      (widget.initialUrl != null && widget.initialUrl!.trim().isNotEmpty);

  // system volume 0..100
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
  bool _isSeeking = false;

  // Equalizer sliders (dB)
  double bassGain = 0.0;
  double midGain = 0.0;
  double trebleGain = 0.0;

  bool _isLocked = false;
  bool _equalizerVisible = false;
  bool _filtersVisible = false;
  bool _audioOnly = false;
  bool _hdrOnly = false;
  double _playbackRate = 1.0;
  final List<double> _rateOptions = [0.5, 1.0, 1.5, 2.0];

  bool _isLandscapeMode = false;

  // seek state
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

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;

  bool _hdrOn = false;
  bool _showHdrOverlay = false;
  bool _hdrChanging = false;

  // Track playback position & duration for the progress bar.
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration> _durationSub;
  StreamSubscription<bool>? _playingSub;

  // =========================================================
  // ✅ MX PLAYER PAN ENGINE + SEEK OVERLAY + BUBBLE + HAPTIC
  // =========================================================
  bool _panActive = false;
  bool _panIsHorizontal = false;
  bool _panIsVertical = false;

  Offset _panStart = Offset.zero;
  double _panStartVolume = 0; // 0..100
  double _panStartBrightness = 0; // 0..1
  Duration _panStartPos = Duration.zero;

  static const double _axisLockThreshold = 10; // px
  static const double _seekSpeed = 1.2; // tune 0.8..1.8
  static const double _volSpeed = 120; // tune 80..160
  static const double _briSpeed = 1.2; // tune 0.8..1.6

  bool _verticalDragLeft = false;
  bool _verticalDragRight = false;

  // throttle system volume set
  Timer? _volThrottle;

  // seek overlay + bubble
  bool _showSeekOverlay = false;
  String _seekOverlayText = '';
  Timer? _seekOverlayTimer;

  bool _showSeekBubble = false;
  Timer? _seekBubbleTimer;
  Duration _bubblePos = Duration.zero;

  // haptic edge control (volume 0/100)
  int _lastHapticEdge = -1; // -1 none, 0 min, 1 max
  DateTime _lastHapticAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();

    _currentIndex =
        _hasLocalList
            ? widget.initialIndex.clamp(0, widget.videos.length - 1)
            : 0;

    // ✅ Reuse external player/controller if coming from floating
    if (widget.externalPlayer != null && widget.externalController != null) {
      _player = widget.externalPlayer!;
      _controller = widget.externalController!;
      _isLoading = false;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        if (_hasUrl) {
          await _playFromUrl(widget.initialUrl!.trim());
        } else {
          if (!_player.state.playing) {
            await _player.play();
          }
        }
      });
    } else {
      _player = Player();
      _controller = VideoController(_player);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        if (_hasUrl) {
          await _playFromUrl(widget.initialUrl!.trim());
        } else {
          await _loadVideo();
        }
      });
    }

    // Set player's internal volume to 100% so system volume controls the loudness.
    _player.setVolume(100);

    // Initialise brightness
    ScreenBrightness().current.then((value) => _brightness = value);

    // Hide native OS volume UI
    VolumeController.instance.showSystemUI = false;

    // Initialise system volume and listener.
    VolumeController.instance.getVolume().then((v) {
      if (!mounted) return;
      setState(() {
        _systemVolume = v * 100;
      });
    });

    _volumeSubscription = VolumeController.instance.addListener((
      double volume,
    ) {
      if (!mounted) return;
      setState(() {
        _systemVolume = volume * 100;
      });
    }, fetchInitialVolume: false);

    // ✅ Listen to position changes
    _positionSub = _player.stream.position.listen((position) {
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
    });

    // ✅ Listen to duration changes (with safe fallback)
    _durationSub = _player.stream.duration.listen((duration) {
      if (!mounted) return;

      final d = duration == Duration.zero ? _player.state.duration : duration;

      setState(() {
        _totalDuration = d;
      });
    });

    // ✅ IMPORTANT: pull initial values immediately (externalPlayer case)
    _syncFromPlayerState();

    // ✅ duration sometimes arrives a little later -> sync again
    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      _syncFromPlayerState();
    });

    // Completed listener (only for local list)
    _player.stream.completed.listen((completed) async {
      if (!completed) return;

      if (!_hasLocalList) {
        // URL mode: do nothing on completed (or you can loop)
        return;
      }

      if (_currentIndex == widget.videos.length - 1) {
        setState(() => _showLogo = true);
        await _player.pause();
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) setState(() => _showLogo = true);
      } else {
        await _playNext();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _controlsVisible = true);
      _startHideTimer();
      _hideBottomBar();
    });

    // Default portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Playing state sync (global play/pause)
    _playingSub = _player.stream.playing.listen((playing) {
      if (!mounted) return;
      setState(() => _isPlaying = playing);
      globalPlayPause.update(playing);
    });
  }

  Future<void> _playFromUrl(String url) async {
    try {
      setState(() {
        _isLoading = true;
        _showLogo = false;
      });

      await _player.open(Media(url), play: true);

      _syncFromPlayerState();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Link play failed: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncFromPlayerState() {
    final pos = _player.state.position;
    final dur = _player.state.duration;

    if (!mounted) return;

    setState(() {
      _currentPosition = pos;
      _totalDuration = dur;
    });
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    final duration = const Duration(seconds: 5);
    _hideTimer = Timer(duration, () {
      if (mounted && !_isLocked) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _onScreenTap() {
    if (_isLocked) return;

    setState(() => _controlsVisible = !_controlsVisible);

    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  Future<void> _loadVideo() async {
    if (!_hasLocalList) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _showLogo = false;
    });

    // ✅ RECENT ADD (AssetEntity.id save)
    try {
      final id = widget.videos[_currentIndex].id;
      Provider.of<VideoProvider>(
        context,
        listen: false,
      ).addToRecentlyPlayed(id);
    } catch (_) {}

    final file = await widget.videos[_currentIndex].file;

    if (file != null) {
      await _player.open(Media(file.path), play: false);
      await Future.delayed(const Duration(milliseconds: 100));
      await _player.play();
    } else {
      Fluttertoast.showToast(
        msg: "Video file not found",
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _applyEqualizer() async {
    final weightedGain =
        (bassGain * 0.6 + midGain * 0.3 + trebleGain * 0.1) / 15.0;
    final factor = (1.0 + weightedGain).clamp(0.5, 1.5);
    final newVolume = (factor * 100).clamp(0.0, 100.0);
    await _player.setVolume(newVolume);
  }

  Future<void> _playNext() async {
    if (!_hasLocalList) return;

    if (_currentIndex < widget.videos.length - 1) {
      _currentIndex++;
      await _player.stop();
      await _loadVideo();
    }
  }

  Future<void> _playPrevious() async {
    if (!_hasLocalList) return;

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
      builder:
          (context) => Center(
            child: Material(
              color: Colors.transparent,
              child: AnimatedScale(
                scale: 1,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 20,
                  ),
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

    Overlay.of(context).insert(entry);
    Future.delayed(
      const Duration(milliseconds: 900),
    ).then((_) => entry.remove());
  }

  List<double> _getColorMatrix(String filter, {double hdrIntensity = 0.65}) {
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
          1,
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
          1,
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
      case 'hdr':
        return fakeHdrMatrix(intensity: hdrIntensity);
      default:
        return [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
    }
  }

  double hdrIntensity = 0.7;

  List<double> fakeHdrMatrix({double intensity = 0.65}) {
    final c = 1.0 + (0.55 * intensity);
    final s = 1.0 + (0.75 * intensity);
    final b = 6.0 * intensity;

    const r = 0.2126;
    const g = 0.7152;
    const bl = 0.0722;

    final ir = (1 - s) * r;
    final ig = (1 - s) * g;
    final ib = (1 - s) * bl;

    final m00 = ir + s;
    final m01 = ig;
    final m02 = ib;

    final m10 = ir;
    final m11 = ig + s;
    final m12 = ib;

    final m20 = ir;
    final m21 = ig;
    final m22 = ib + s;

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

  Future<void> toggleHdr() async {
    if (_hdrChanging) return;

    _hdrChanging = true;

    setState(() {
      _showHdrOverlay = true;
    });

    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    setState(() {
      _hdrOn = !_hdrOn;
      _selectedFilter = _hdrOn ? 'hdr' : '';
      _showHdrOverlay = false;
    });

    _hdrChanging = false;
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

  // =========================================================
  // ✅ MX PAN ENGINE: Seek + Volume/Brightness + overlays
  // =========================================================
  void _onPanStart(DragStartDetails details) async {
    if (_isLocked) return;

    _panActive = true;
    _panIsHorizontal = false;
    _panIsVertical = false;

    _panStart = details.localPosition;
    _panStartPos = _player.state.position;

    _panStartVolume = _systemVolume;

    try {
      _panStartBrightness = await ScreenBrightness().current;
    } catch (_) {
      _panStartBrightness = _brightness;
    }

    _hideSeekOverlay(immediate: true);
    _hideSeekBubble(immediate: true);
  }

  Future<void> _onPanUpdate(DragUpdateDetails details) async {
    _onUserInteractionFromBottom(details, context);
    if (!_panActive || _isLocked) return;

    final size = MediaQuery.of(context).size;
    final dxTotal = details.localPosition.dx - _panStart.dx;
    final dyTotal = details.localPosition.dy - _panStart.dy;

    // Axis lock decide (MX style)
    if (!_panIsHorizontal && !_panIsVertical) {
      if (dxTotal.abs() < _axisLockThreshold &&
          dyTotal.abs() < _axisLockThreshold) {
        return;
      }

      if (dxTotal.abs() > dyTotal.abs()) {
        // Horizontal seek (avoid bottom slider zone)
        if (_panStart.dy > size.height * 0.80) return;
        _panIsHorizontal = true;
      } else {
        _panIsVertical = true;
        final isLeft = _panStart.dx < size.width * 0.5;
        _verticalDragLeft = isLeft;
        _verticalDragRight = !isLeft;
      }
    }

    // ---------- HORIZONTAL SEEK ----------
    if (_panIsHorizontal) {
      final duration = _player.state.duration;
      if (duration.inMilliseconds <= 0) return;

      final relative = dxTotal / size.width;
      final offsetMs =
          (duration.inMilliseconds * relative * _seekSpeed).toInt();

      int newMs = _panStartPos.inMilliseconds + offsetMs;
      newMs = newMs.clamp(0, duration.inMilliseconds);

      final newPos = Duration(milliseconds: newMs);
      _player.seek(newPos);

      setState(() {
        _currentPosition = newPos;
        _bubblePos = newPos;
      });

      final sign = offsetMs >= 0 ? "+" : "-";
      final off = Duration(milliseconds: offsetMs.abs());
      _showSeekOverlayText("$sign${_formatDuration(off)}");
      _showSeekBubbleNow();
      return;
    }

    // ---------- VERTICAL BRIGHTNESS / VOLUME ----------
    if (_panIsVertical) {
      final h = size.height;
      final delta = (-dyTotal / h); // swipe up => +ve

      if (_verticalDragLeft) {
        final b = (_panStartBrightness + delta * _briSpeed).clamp(0.0, 1.0);
        _brightness = b;

        try {
          await ScreenBrightness().setScreenBrightness(b);
        } catch (_) {}

        setState(() => _showBrightnessOverlay = true);

        _brightnessTimer?.cancel();
        _brightnessTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showBrightnessOverlay = false);
        });
      } else if (_verticalDragRight) {
        final v = (_panStartVolume + delta * _volSpeed).clamp(0.0, 100.0);

        setState(() {
          _systemVolume = v;
          _showVolumeOverlay = true;
        });

        _handleVolumeEdgeHaptic(v);

        _volThrottle?.cancel();
        _volThrottle = Timer(const Duration(milliseconds: 35), () async {
          await VolumeController.instance.setVolume(_systemVolume / 100);
        });

        _volumeTimer?.cancel();
        _volumeTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
      }
    }
  }

  void _onPanEnd(DragEndDetails details) {
    _panActive = false;
    _panIsHorizontal = false;
    _panIsVertical = false;
    _verticalDragLeft = false;
    _verticalDragRight = false;

    _hideSeekOverlay(immediate: false);
    _hideSeekBubble(immediate: false);
  }

  void _handleVolumeEdgeHaptic(double v) {
    final now = DateTime.now();
    if (now.difference(_lastHapticAt).inMilliseconds < 180) return;

    if (v <= 0.0) {
      if (_lastHapticEdge != 0) {
        _lastHapticEdge = 0;
        _lastHapticAt = now;
        HapticFeedback.mediumImpact();
      }
    } else if (v >= 100.0) {
      if (_lastHapticEdge != 1) {
        _lastHapticEdge = 1;
        _lastHapticAt = now;
        HapticFeedback.mediumImpact();
      }
    } else {
      _lastHapticEdge = -1;
    }
  }

  void _showSeekOverlayText(String text) {
    setState(() {
      _seekOverlayText = text;
      _showSeekOverlay = true;
    });

    _seekOverlayTimer?.cancel();
    _seekOverlayTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() => _showSeekOverlay = false);
    });
  }

  void _hideSeekOverlay({required bool immediate}) {
    _seekOverlayTimer?.cancel();
    if (immediate) {
      if (mounted) setState(() => _showSeekOverlay = false);
    } else {
      _seekOverlayTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => _showSeekOverlay = false);
      });
    }
  }

  void _showSeekBubbleNow() {
    setState(() => _showSeekBubble = true);
    _seekBubbleTimer?.cancel();
    _seekBubbleTimer = Timer(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _showSeekBubble = false);
    });
  }

  void _hideSeekBubble({required bool immediate}) {
    _seekBubbleTimer?.cancel();
    if (immediate) {
      if (mounted) setState(() => _showSeekBubble = false);
    } else {
      _seekBubbleTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showSeekBubble = false);
      });
    }
  }

  // Double tap (your existing)
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
      final newPos = Duration(milliseconds: newPositionMs);
      _player.seek(newPos);
      setState(() {
        _skipDirection = -1;
        _showSkipOverlay = true;
        _currentPosition = newPos;
        _bubblePos = newPos;
      });
      _showSeekOverlayText("-00:10");
      _showSeekBubbleNow();
    } else {
      final newPositionMs = (position.inMilliseconds + 10000).clamp(
        0,
        duration.inMilliseconds,
      );
      final newPos = Duration(milliseconds: newPositionMs);
      _player.seek(newPos);
      setState(() {
        _skipDirection = 1;
        _showSkipOverlay = true;
        _currentPosition = newPos;
        _bubblePos = newPos;
      });
      _showSeekOverlayText("+00:10");
      _showSeekBubbleNow();
    }

    _skipOverlayTimer?.cancel();
    _skipOverlayTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showSkipOverlay = false);
    });
  }

  // =========================================================

  @override
  void dispose() {
    // if floating is active you may not want to dispose player
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
    _volThrottle?.cancel();
    _seekOverlayTimer?.cancel();
    _seekBubbleTimer?.cancel();

    VolumeController.instance.removeListener();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _playingSub?.cancel();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLocked) {
        setState(() => _controlsVisible = true);
        _startHideTimer();
      }
    });
  }

// ✅ Landscape me "more" click par right-side se panel (sheet) aayega
// ✅ Portrait me normal bottom sheet hi aayega
// Paste this inside your State class

  void openControlsSheetSmart() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      _openRightControlsSheet();
    } else {
      _openControlsBottomSheet(); // aapka existing bottom sheet
    }
  }

  /// ✅ RIGHT SIDE SHEET (Landscape)
  void _openRightControlsSheet() {
    if (_isLocked) return;

    final size = MediaQuery.of(context).size;
    final double panelWidth = (size.width * 0.42).clamp(280.0, 420.0);

    showGeneralDialog(
      context: context,
      barrierLabel: "Controls",
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: panelWidth,
                height: double.infinity,
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // ✅ Header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Player Controls",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon:
                            const Icon(Icons.close, color: Colors.white70),
                          ),
                        ],
                      ),
                    ),

                    Divider(color: Colors.white.withOpacity(0.12), height: 1),

                    // ✅ Scroll Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _sheetTitle("Quick Actions"),
                            const SizedBox(height: 10),

                            // ✅ same controls
                            _controlGrid([
                              _controlItem(
                                icon: Icons.camera_alt,
                                label: "Screenshot",
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _takeScreenshot();
                                },
                              ),
                              _controlItem(
                                icon: Icons.screen_rotation,
                                label: "Rotate",
                                onTap: () {
                                  Navigator.pop(context);
                                  _toggleOrientation();
                                },
                              ),
                              _controlItem(
                                icon: Icons.headphones,
                                label: _audioOnly ? "Video On" : "Audio Only",
                                active: _audioOnly,
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _toggleAudioOnly();
                                },
                              ),
                              _controlItem(
                                icon: Icons.color_lens,
                                label: "Filters",
                                onTap: () {
                                  Navigator.pop(context);
                                  FilterPopup.show(
                                    context,
                                    selectedKey: _selectedFilter,
                                    onSelected: (key) =>
                                        setState(() => _selectedFilter = key),
                                  );
                                },
                              ),
                              _controlItem(
                                icon: Icons.hdr_auto_select_sharp,
                                label: "HDR",
                                active: _selectedFilter == 'hdr',
                                onTap: () async {
                                  Navigator.pop(context);
                                  await toggleHdr();
                                },
                              ),
                              _controlItem(
                                icon: Icons.volume_up,
                                label: "Volume",
                                onTap: () {
                                  Navigator.pop(context);
                                  _openVolumeDialog();
                                },
                              ),
                              _controlItem(
                                icon: Icons.speed,
                                label: "Speed",
                                onTap: () {
                                  Navigator.pop(context);
                                  _openSpeedDialog();
                                },
                              ),
                              _controlItem(
                                icon: Icons.picture_in_picture_alt,
                                label: "PIP",
                                disabled: !_hasLocalList,
                                onTap: !_hasLocalList
                                    ? null
                                    : () {
                                  Navigator.pop(context);
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
                            ]),

                            const SizedBox(height: 14),
                            Divider(color: Colors.white.withOpacity(0.12)),
                            const SizedBox(height: 12),

                            _sheetTitle("Playback"),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                _pillButton(
                                  icon: _isLocked ? Icons.lock : Icons.lock_open,
                                  label: _isLocked ? "Locked" : "Lock",
                                  active: _isLocked,
                                  onTap: () {
                                    Navigator.pop(context);
                                    _toggleLock();
                                  },
                                ),
                                _pillButton(
                                  icon: Icons.replay_10,
                                  label: "-10s",
                                  onTap: () {
                                    Navigator.pop(context);
                                    _seekBy(const Duration(seconds: -10));
                                  },
                                ),
                                _pillButton(
                                  icon: globalPlayPause.isPlaying
                                      ? Icons.pause_circle_filled
                                      : Icons.play_circle_fill,
                                  label:
                                  globalPlayPause.isPlaying ? "Pause" : "Play",
                                  onTap: () {
                                    Navigator.pop(context);
                                    _togglePlayPause();
                                  },
                                ),
                                _pillButton(
                                  icon: Icons.forward_10,
                                  label: "+10s",
                                  onTap: () {
                                    Navigator.pop(context);
                                    _seekBy(const Duration(seconds: 10));
                                  },
                                ),
                                _pillButton(
                                  icon: Icons.skip_previous,
                                  label: "Prev",
                                  disabled: !_hasLocalList,
                                  onTap: !_hasLocalList
                                      ? null
                                      : () async {
                                    Navigator.pop(context);
                                    await _playPrevious();
                                  },
                                ),
                                _pillButton(
                                  icon: Icons.skip_next,
                                  label: "Next",
                                  disabled: !_hasLocalList,
                                  onTap: !_hasLocalList
                                      ? null
                                      : () async {
                                    Navigator.pop(context);
                                    await _playNext();
                                  },
                                ),
                                _pillButton(
                                  icon: _resizeMode == VideoResizeMode.fit
                                      ? Icons.fit_screen
                                      : _resizeMode == VideoResizeMode.fill
                                      ? Icons.crop
                                      : Icons.zoom_in_map,
                                  label: "Resize",
                                  onTap: () {
                                    Navigator.pop(context);
                                    _toggleResizeMode();
                                  },
                                ),
                              ],
                            ),
                          ],
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
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        );
      },
    );
  }

  void _openControlsBottomSheet() {
    if (_isLocked) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        final h = MediaQuery.of(context).size.height;
        final maxH = h * 0.4; // ✅ fixed height (change 0.60..0.75)

        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(0),
            constraints: BoxConstraints(maxHeight: maxH), // ✅ fixed height
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),

                // ✅ handle
                Container(
                  height: 5,
                  width: 45,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),

                // ✅ header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Player Controls",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                Divider(color: Colors.white.withOpacity(0.12), height: 1),

                // ✅ scrollable body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sheetTitle("Quick Actions"),
                        const SizedBox(height: 10),

                        // ✅ SAME ICONS (fixed size portrait/landscape)
                        _controlGrid([
                          _controlItem(
                            icon: Icons.camera_alt,
                            label: "Screenshot",
                            onTap: () async {
                              Navigator.pop(context);
                              await _takeScreenshot();
                            },
                          ),
                          _controlItem(
                            icon: Icons.screen_rotation,
                            label: "Rotate",
                            onTap: () {
                              Navigator.pop(context);
                              _toggleOrientation();
                            },
                          ),
                          _controlItem(
                            icon: Icons.headphones,
                            label: _audioOnly ? "Video On" : "Audio Only",
                            active: _audioOnly,
                            onTap: () async {
                              Navigator.pop(context);
                              await _toggleAudioOnly();
                            },
                          ),
                          _controlItem(
                            icon: Icons.color_lens,
                            label: "Filters",
                            onTap: () {
                              Navigator.pop(context);
                              FilterPopup.show(
                                context,
                                selectedKey: _selectedFilter,
                                onSelected: (key) =>
                                    setState(() => _selectedFilter = key),
                              );
                            },
                          ),
                          _controlItem(
                            icon: Icons.hdr_auto_select_sharp,
                            label: "HDR",
                            active: _selectedFilter == 'hdr',
                            onTap: () async {
                              Navigator.pop(context);
                              await toggleHdr();
                            },
                          ),
                          _controlItem(
                            icon: Icons.volume_up,
                            label: "Volume",
                            onTap: () {
                              Navigator.pop(context);
                              _openVolumeDialog();
                            },
                          ),
                          _controlItem(
                            icon: Icons.speed,
                            label: "Speed",
                            onTap: () {
                              Navigator.pop(context);
                              _openSpeedDialog();
                            },
                          ),
                          _controlItem(
                            icon: Icons.picture_in_picture_alt,
                            label: "PIP",
                            disabled: !_hasLocalList,
                            onTap: !_hasLocalList
                                ? null
                                : () {
                              Navigator.pop(context);
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
                        ]),

                        const SizedBox(height: 14),
                        Divider(color: Colors.white.withOpacity(0.12)),
                        const SizedBox(height: 12),

                        _sheetTitle("Playback"),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _pillButton(
                              icon: _isLocked ? Icons.lock : Icons.lock_open,
                              label: _isLocked ? "Locked" : "Lock",
                              active: _isLocked,
                              onTap: () {
                                Navigator.pop(context);
                                _toggleLock();
                              },
                            ),
                            _pillButton(
                              icon: Icons.replay_10,
                              label: "-10s",
                              onTap: () {
                                Navigator.pop(context);
                                _seekBy(const Duration(seconds: -10));
                              },
                            ),
                            _pillButton(
                              icon: globalPlayPause.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              label: globalPlayPause.isPlaying ? "Pause" : "Play",
                              onTap: () {
                                Navigator.pop(context);
                                _togglePlayPause();
                              },
                            ),
                            _pillButton(
                              icon: Icons.forward_10,
                              label: "+10s",
                              onTap: () {
                                Navigator.pop(context);
                                _seekBy(const Duration(seconds: 10));
                              },
                            ),
                            _pillButton(
                              icon: Icons.skip_previous,
                              label: "Prev",
                              disabled: !_hasLocalList,
                              onTap: !_hasLocalList
                                  ? null
                                  : () async {
                                Navigator.pop(context);
                                await _playPrevious();
                              },
                            ),
                            _pillButton(
                              icon: Icons.skip_next,
                              label: "Next",
                              disabled: !_hasLocalList,
                              onTap: !_hasLocalList
                                  ? null
                                  : () async {
                                Navigator.pop(context);
                                await _playNext();
                              },
                            ),
                            _pillButton(
                              icon: _resizeMode == VideoResizeMode.fit
                                  ? Icons.fit_screen
                                  : _resizeMode == VideoResizeMode.fill
                                  ? Icons.crop
                                  : Icons.zoom_in_map,
                              label: "Resize",
                              onTap: () {
                                Navigator.pop(context);
                                _toggleResizeMode();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sheetTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _controlGrid(List<Widget> children) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: children,
    );
  }

  Widget _controlItem({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
    bool disabled = false,
  }) {
    final isDisabled = disabled || onTap == null;

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? Colors.white.withOpacity(0.22)
                : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24, // ✅ fixed size (portrait/landscape same)
              color: isDisabled
                  ? Colors.white24
                  : active
                  ? Colors.greenAccent
                  : Colors.white,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDisabled ? Colors.white24 : Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool active = false,
    bool disabled = false,
  }) {
    final isDisabled = disabled || onTap == null;

    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withOpacity(0.18)
              : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18, // ✅ fixed size (portrait/landscape same)
              color: isDisabled
                  ? Colors.white24
                  : active
                  ? Colors.greenAccent
                  : Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isDisabled ? Colors.white24 : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }


  // =================== BUILD (UI SAME) =====================
  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final double equalizerBottom = isLandscape ? 70 : 130;
    final playSize = isLandscape ? 22.sp : 45.sp;
    final sideSize = isLandscape ? 15.sp : 28.sp;
    final bottomPadding = isLandscape ? 0.sp : 40.sp;

    final maxMs = _totalDuration.inMilliseconds;
    final safeMax = (maxMs <= 0 ? 1 : maxMs);
    final posMs = _currentPosition.inMilliseconds.clamp(0, safeMax);

    final String appBarTitle =
        _hasLocalList
            ? (widget.videos[_currentIndex].title ?? '')
            : (_hasUrl ? widget.initialUrl!.trim() : 'Streaming');

    final videoWidget = ColorFiltered(
      colorFilter: ColorFilter.matrix(
        _getColorMatrix(_selectedFilter, hdrIntensity: 0.8),
      ),
      child: Video(
        controller: _controller,
        fit:
            _resizeMode == VideoResizeMode.fit
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
        // ✅ only show floating when we have local list (safe)
        if (_hasLocalList) {
          FloatingVideoManager.show(
            context,
            _player,
            _controller,
            widget.videos,
            _currentIndex,
          );
        }
        return true;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,

        // ✅ ONLY ONE ENGINE (MX style)
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,

        onTap: _onScreenTap,
        onDoubleTapDown: _onDoubleTapDown,

        child: Scaffold(
          backgroundColor: Colors.black,
          body:
              _isLoading
                  ? const Center(
                    child: CupertinoActivityIndicator(
                      radius: 25,
                      color: Colors.white,
                      animating: true,
                    ),
                  )
                  : Stack(
                    children: [
                      Positioned.fill(child: videoWidget),

                      // subtle vignette (same)
                      IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              radius: 1.0,
                              colors: [
                                const Color(0x00000000),
                                const Color(0x22000000),
                              ],
                              stops: const [0.65, 1.0],
                            ),
                          ),
                        ),
                      ),

                      // ✅ Center seek overlay
                      if (_showSeekOverlay)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 120),
                                scale: _showSeekOverlay ? 1 : 0.95,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.70),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.10),
                                    ),
                                  ),
                                  child: Text(
                                    _seekOverlayText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // ✅ Seek bubble (time preview)
                      if (_showSeekBubble)
                        Positioned(
                          top: 70,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.72),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.10),
                                  ),
                                ),
                                child: Text(
                                  "${_formatDuration(_bubblePos)} / ${_formatDuration(_totalDuration)}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // brightness overlay (same)
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
                                  Container(
                                    width: 20,
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
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(20),
                                                bottom: Radius.circular(20),
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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

                      // volume overlay
                      if (_showVolumeOverlay)
                        Builder(
                          builder: (context) {
                            final screenHeight =
                                MediaQuery.of(context).size.height;
                            final barHeight = screenHeight * 0.3;
                            final volValue = _systemVolume.round();
                            final frac = (_systemVolume / 100).clamp(0.0, 1.0);

                            return Positioned(
                              right: 20,
                              top: screenHeight / 2 - barHeight / 2,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        volValue == 0
                                            ? Icons.volume_off
                                            : Icons.volume_up,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 6),
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
                                  const SizedBox(width: 10),
                                  Container(
                                    width: 22,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 120,
                                        ),
                                        curve: Curves.easeOutCubic,
                                        width: 22,
                                        height: barHeight * frac,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.greenAccent,
                                              Colors.green,
                                            ],
                                          ),
                                          borderRadius: BorderRadius.vertical(
                                            bottom: Radius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      // ✅ HDR overlay (same - premium)
                      if (_showHdrOverlay)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            opacity: _showHdrOverlay ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                              child: Container(
                                color: Colors.black.withOpacity(0.45),
                                alignment: Alignment.center,
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.85, end: 1),
                                  duration: const Duration(milliseconds: 260),
                                  curve: Curves.easeOutBack,
                                  builder: (context, scale, child) {
                                    return Transform.scale(
                                      scale: scale,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 280,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 24,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(26),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors:
                                            _hdrOn
                                                ? const [
                                                  Color(0xFF0F172A),
                                                  Color(0xFF1E293B),
                                                ]
                                                : const [
                                                  Color(0xFFFFC857),
                                                  Color(0xFFFF8A00),
                                                ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.65),
                                          blurRadius: 35,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.12),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0, end: 1),
                                          duration: const Duration(seconds: 1),
                                          builder: (_, value, child) {
                                            return Transform.rotate(
                                              angle: value * 6.28,
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(18),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: RadialGradient(
                                                colors: [
                                                  Colors.white.withOpacity(
                                                    0.35,
                                                  ),
                                                  Colors.white.withOpacity(
                                                    0.05,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.hdr_on_rounded,
                                              size: 40,
                                              color:
                                                  _hdrOn
                                                      ? Colors.orangeAccent
                                                      : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        Text(
                                          "HDR PROCESSING",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.6,
                                            color:
                                                _hdrOn
                                                    ? Colors.white70
                                                    : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _hdrOn
                                              ? "Turning HDR OFF"
                                              : "Turning HDR ON",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color:
                                                _hdrOn
                                                    ? Colors.white
                                                    : Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        const SizedBox(
                                          width: 34,
                                          height: 34,
                                          child: CupertinoActivityIndicator(
                                            radius: 20,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // lock overlay (same)
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

                      // equalizer (same)
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

                      // ✅ controls
                      if (!_isLocked && _controlsVisible)
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              color: Colors.black.withOpacity(0.4),
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: isLandscape ? 0.sp : 40.sp,
                                ),
                                child:
                                    _hasLocalList
                                        ? CustomVideoAppBar(
                                          title: appBarTitle,
                                          onBackPressed: () {
                                            if (isLandscape) {
                                              SystemChrome.setPreferredOrientations(
                                                [
                                                  DeviceOrientation.portraitUp,
                                                  DeviceOrientation
                                                      .portraitDown,
                                                ],
                                              );
                                              SystemChrome.setEnabledSystemUIMode(
                                                SystemUiMode.manual,
                                                overlays:
                                                    SystemUiOverlay.values,
                                              );
                                            } else {
                                              ScreenBrightness()
                                                  .resetScreenBrightness();
                                              Navigator.pop(context);
                                            }
                                          },
                                          currentIndex: _currentIndex,
                                          onVideoSelected: (index) async {
                                            if (index == _currentIndex) {
                                              if (!_player.state.playing) {
                                                await _player.play();
                                              }
                                              return;
                                            }

                                            setState(() {
                                              _currentIndex = index;
                                            });

                                            await _player.stop();
                                            await _loadVideo();
                                          },
                                          isLandscape: isLandscape,
                                          videos: widget.videos,
                                          onBackPressedMore: () {
                                            print('click more');
                                            openControlsSheetSmart();


                                          },
                                        )
                                        : Container(
                                          child: _StreamTopBar(
                                            title: appBarTitle,
                                            onBack: () {
                                              ScreenBrightness()
                                                  .resetScreenBrightness();
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ),
                              ),
                            ),

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
                                            onPressed: _takeScreenshot,
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.screen_rotation,
                                            ),
                                            color: Colors.white,
                                            onPressed: _toggleOrientation,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.headphones),
                                            color:
                                                _audioOnly
                                                    ? Colors.greenAccent
                                                    : Colors.white,
                                            onPressed: _toggleAudioOnly,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.color_lens),
                                            color: Colors.white,
                                            onPressed: () {
                                              FilterPopup.show(
                                                context,
                                                selectedKey: _selectedFilter,
                                                onSelected: (key) {
                                                  setState(
                                                    () => _selectedFilter = key,
                                                  );
                                                },
                                              );
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
                                            icon: const Icon(
                                              Icons.hdr_auto_select_sharp,
                                              size: 30,
                                            ),
                                            color:
                                                _selectedFilter == 'hdr'
                                                    ? Colors.pink
                                                    : Colors.grey,
                                            onPressed: toggleHdr,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.volume_up),
                                            color: Colors.white,
                                            onPressed: _openVolumeDialog,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.speed),
                                            color: Colors.white,
                                            onPressed: _openSpeedDialog,
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.picture_in_picture_alt,
                                            ),
                                            color: Colors.white,
                                            onPressed:
                                                _hasLocalList
                                                    ? () {
                                                      FloatingVideoManager.show(
                                                        context,
                                                        _player,
                                                        _controller,
                                                        widget.videos,
                                                        _currentIndex,
                                                      );
                                                      Navigator.pop(context);
                                                    }
                                                    : null, // ✅ disable for URL mode
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                Row(
                                  children: [
                                    Text(
                                      _formatDuration(_currentPosition),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 1),
                                    Expanded(
                                      child: Slider(
                                        value:
                                            posMs.clamp(0, safeMax).toDouble(),
                                        min: 0.0,
                                        max: safeMax.toDouble(),
                                        activeColor: Colors.green,
                                        inactiveColor: Colors.white54,

                                        onChangeStart: (_) {
                                          _isSeeking = true;
                                        },

                                        onChanged: (value) {
                                          if (!_isSeeking) return;
                                          setState(() {
                                            _bubblePos = Duration(
                                              milliseconds: value.round(),
                                            );
                                            _currentPosition = _bubblePos;
                                          });
                                        },

                                        onChangeEnd: (value) {
                                          final newPos = Duration(
                                            milliseconds: value.round(),
                                          );
                                          _player.seek(newPos);

                                          setState(() {
                                            _currentPosition = newPos;
                                            _bubblePos = newPos;
                                            _isSeeking = false;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 1),
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
                                      onPressed: _toggleLock,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_previous),
                                      color: Colors.white,
                                      iconSize: sideSize + 4,
                                      onPressed:
                                          _hasLocalList ? _playPrevious : null,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.replay_10),
                                      color: Colors.white,
                                      iconSize: sideSize + 4,
                                      onPressed:
                                          () => _seekBy(
                                            const Duration(seconds: -10),
                                          ),
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
                                      icon: const Icon(Icons.forward_10),
                                      color: Colors.white,
                                      iconSize: sideSize + 4,
                                      onPressed:
                                          () => _seekBy(
                                            const Duration(seconds: 10),
                                          ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.skip_next),
                                      color: Colors.white,
                                      iconSize: sideSize + 4,
                                      onPressed:
                                          _hasLocalList ? _playNext : null,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        _resizeMode == VideoResizeMode.fit
                                            ? Icons.fit_screen
                                            : _resizeMode ==
                                                VideoResizeMode.fill
                                            ? Icons.crop
                                            : Icons.zoom_in_map,
                                      ),
                                      color: Colors.white,
                                      onPressed: _toggleResizeMode,
                                    ),
                                  ],
                                ),
                                SizedBox(height: bottomPadding),
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

  // helpers
  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPause() async {
    _player.state.playing ? _player.pause() : _player.play();
  }

  Future<void> _seekBy(Duration offset) async {
    await _player.seek(_currentPosition + offset);
  }
}

/// ✅ Simple top bar for URL streaming mode (when videos list is empty)
class _StreamTopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _StreamTopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
      child: Row(
        children: [
          Card(
            color: Colors.white10,

            child: IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
