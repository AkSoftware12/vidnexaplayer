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
import '../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../NotifyListeners/LanguageProvider/video_strings.dart';
import '../../NotifyListeners/PlayPauseSync/play_pause.dart';
import '../../ads/app_open_ad_manager.dart';
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
  // Singleton — initialised once in main.dart, never disposed by a screen.
  final appOpenManager = AppOpenAdManager();

  late int _currentIndex;
  late final Player _player;
  late final VideoController _controller;
  VideoResizeMode _resizeMode = VideoResizeMode.fit;

  // ✅ true only if WE created the player (so we may dispose it)
  bool _ownsPlayer = false;

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

  // Cached at the top of build() (context.watch) so a language change
  // triggers a rebuild; reused from callbacks/dialogs outside build() where
  // `context.watch` cannot be called.
  String _lang = 'en';
  String _t(String key) => VideoStrings.t(_lang, key);

  bool _isLoading = true;
  String _selectedFilter = 'normal';
  Timer? _systemUiTimer;
  bool _isSeeking = false;

  // Equalizer sliders (dB)
  double bassGain = 0.0;
  double midGain = 0.0;
  double trebleGain = 0.0;

  bool _isLocked = false;
  final bool _equalizerVisible = false;
  bool _audioOnly = false;
  double _playbackRate = 1.0;

  bool _isLandscapeMode = false;

  // seek state
  final bool _isDragging = false;

  double _brightness = 0.5;
  bool _showBrightnessOverlay = false;
  bool _showVolumeOverlay = false;
  Timer? _brightnessTimer;
  Timer? _volumeTimer;

  bool _hdrOn = false;
  bool _showHdrOverlay = false;
  bool _hdrChanging = false;

  // Track playback position & duration for the progress bar.
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<bool>? _completedSub; // ✅ store to cancel later

  // =========================================================
  // ✅ MX PLAYER PAN ENGINE + SEEK OVERLAY + BUBBLE + HAPTIC
  // =========================================================
  bool _panActive = false;
  bool _panIsHorizontal = false;
  bool _panIsVertical = false;

  Offset _panStart = Offset.zero;
  double _panStartVolume = 0; // 0.._maxBoost (0..100 system, 100+ boost)
  double _panStartBrightness = 0; // 0..1
  Duration _panStartPos = Duration.zero;

  static const double _axisLockThreshold = 10; // px

  /// How much video time a full-screen-width horizontal swipe covers.
  ///
  /// This is a FIXED rate, deliberately independent of the clip's length. The
  /// old code scaled the jump by total duration
  /// (`duration * relative * 1.2`), so on a 3-hour film a mere 10% swipe moved
  /// ~22 minutes and the gesture became unusable for anything but the roughest
  /// scrubbing. With a fixed rate the feel is identical on a 2-minute clip and
  /// a 3-hour one; the progress bar remains the tool for long jumps.
  static const double _seekSecondsPerScreenWidth = 90; // tune 60..150

  static const double _volSpeed = 120; // tune 80..160
  static const double _briSpeed = 1.2; // tune 0.8..1.6

  bool _verticalDragLeft = false;
  bool _verticalDragRight = false;

  // throttle system volume set
  Timer? _volThrottle;

  // ✅ throttle seek during horizontal pan (avoid stutter)
  Timer? _seekThrottle;
  Duration? _pendingSeekPos;

  // seek overlay + bubble
  bool _showSeekOverlay = false;
  String _seekOverlayText = '';
  Timer? _seekOverlayTimer;

  bool _showSeekBubble = false;
  Timer? _seekBubbleTimer;
  Duration _bubblePos = Duration.zero;

  // haptic edge control (volume 0 / boost-gate / max)
  int _lastHapticEdge = -1; // -1 none, 0 min, 1 boost gate, 2 max
  DateTime _lastHapticAt = DateTime.fromMillisecondsSinceEpoch(0);

  // =========================================================
  // ✅ VOLUME BOOST (player-side gain)
  // =========================================================
  /// Player gain in percent. 100 = normal, up to [_maxBoost].
  ///
  /// This sits ON TOP of the device volume: `VolumeController` still owns the
  /// hardware 0..100, and everything above that is software gain applied by the
  /// player itself. The swipe gesture treats both as ONE continuous scale
  /// (0.._maxBoost) so the meter never restarts from the bottom when the boost
  /// range is entered — it simply keeps filling, in a different colour.
  double _volumeBoost = 100.0;
  static const double _maxBoost = 150.0;

  /// True once `volume-max` was successfully raised on the native player.
  /// While false we simply never go past 100 — no crash, no silent no-op.
  bool _boostReady = false;

  /// Whether the soft-clip limiter is currently in the audio filter chain.
  bool _limiterOn = false;

  bool get _isBoosting => _volumeBoost > 100.5;

  /// mpv clamps `volume` to `volume-max` (default 130), so the ceiling has to
  /// be raised first or anything above 100 would be quietly ignored.
  Future<void> _initVolumeBoost() async {
    final p = _player.platform;
    if (p is! NativePlayer) return; // web / unsupported -> boost stays off
    try {
      await p.setProperty('volume-max', _maxBoost.toStringAsFixed(0));
      _boostReady = true;
      await _applyPlayerVolume();
    } catch (_) {
      _boostReady = false;
    }
  }

  /// The single place the player's gain is set: boost × equalizer.
  ///
  /// Previously the equalizer and the volume dialog each called `setVolume()`
  /// independently, so whichever ran last silently wiped the other one out.
  Future<void> _applyPlayerVolume() async {
    final weightedGain =
        (bassGain * 0.6 + midGain * 0.3 + trebleGain * 0.1) / 15.0;
    final eqFactor = (1.0 + weightedGain).clamp(0.5, 1.5);

    final target =
    (_volumeBoost * eqFactor).clamp(0.0, _boostReady ? _maxBoost : 100.0);

    try {
      await _player.setVolume(target);

      // Some media_kit versions clamp setVolume() at 100, so write the mpv
      // property directly once we are above that.
      final p = _player.platform;
      if (_boostReady && target > 100 && p is NativePlayer) {
        await p.setProperty('volume', target.toStringAsFixed(1));
      }
    } catch (_) {}

    await _applyLimiter(target > 105);
  }

  /// Above 100% samples clip and the audio turns harsh; the limiter keeps it
  /// clean.
  ///
  /// Only toggled on a boundary crossing: setting `af` rebuilds the whole audio
  /// filter chain (a small audible hiccup), so it must never run on every drag
  /// frame.
  Future<void> _applyLimiter(bool on) async {
    if (on == _limiterOn) return;
    final p = _player.platform;
    if (p is! NativePlayer) return;
    try {
      await p.setProperty('af', on ? 'lavfi=[alimiter=limit=0.92]' : '');
      _limiterOn = on;
    } catch (_) {}
  }

  Future<void> _setVolumeBoost(double percent) async {
    final v = percent.clamp(100.0, _maxBoost);
    if (mounted) setState(() => _volumeBoost = v);
    await _applyPlayerVolume();
  }

  /// Gesture-space value on ONE continuous scale:
  /// 0..100 = device volume, 100.._maxBoost = software boost.
  ///
  /// The old version remapped the boost range onto 100..200, which meant the
  /// meter's fraction was computed against a different scale the moment boost
  /// kicked in — that is why the bar appeared to jump back to the bottom.
  double get _combinedVolume => _isBoosting ? _volumeBoost : _systemVolume;

  // =========================================================
  // ✅ PINCH TO ZOOM (2-finger)
  // =========================================================
  double _videoScale = 1.0;
  double _baseScaleOnGesture = 1.0;
  bool _isZooming = false;
  Offset _videoOffset = Offset.zero;
  static const double _minScale = 1.0;
  static const double _maxScale = 4.0;

  bool _showZoomBadge = false;
  Timer? _zoomBadgeTimer;

  /// Size the video actually occupies on screen at scale 1.0.
  ///
  /// This is NOT the screen size: with `BoxFit.contain` a 16:9 clip on a tall
  /// phone is letterboxed into a band with black above and below.
  Size _baseVideoSize(Size screen) {
    // Prefer the controller's reported rect; fall back to the player state.
    double? vw;
    double? vh;

    final rect = _controller.rect.value;
    if (rect != null && rect.width > 0 && rect.height > 0) {
      vw = rect.width;
      vh = rect.height;
    } else {
      final w = _player.state.width;
      final h = _player.state.height;
      if (w != null && h != null && w > 0 && h > 0) {
        vw = w.toDouble();
        vh = h.toDouble();
      }
    }

    // Dimensions not known yet (first frame still decoding). Returning `screen`
    // here would resurrect the original bug — it makes the clamp think the
    // frame is full-height and hands back a huge pan range. Report zero
    // instead: panning is simply disabled until the real size arrives, which
    // is a far better failure mode than letting the picture slide into the
    // black bars.
    if (vw == null || vh == null) return Size.zero;

    final videoAr = vw / vh;
    final screenAr = screen.width / screen.height;

    switch (_resizeMode) {
      case VideoResizeMode.stretch: // BoxFit.fill — distorted to exactly fill
        return screen;

      case VideoResizeMode.fill: // BoxFit.cover — fills, crops overflow
        return videoAr > screenAr
            ? Size(screen.height * videoAr, screen.height)
            : Size(screen.width, screen.width / videoAr);

      case VideoResizeMode.zoom: // BoxFit.fitWidth
        return Size(screen.width, screen.width / videoAr);

      case VideoResizeMode.fit: // BoxFit.contain — letterboxed
        return videoAr > screenAr
            ? Size(screen.width, screen.width / videoAr)
            : Size(screen.height * videoAr, screen.height);
    }
  }

  /// Keeps the zoomed frame from being dragged off screen.
  ///
  /// The old version measured against `MediaQuery.size`, i.e. the SCREEN, so on
  /// a 1080x2340 phone a letterboxed 16:9 clip (really 1080x607) was allowed
  /// ~1170px of vertical travel at 2x — far more than exists. That is why the
  /// video slid up/down leaving big black areas. Now the limit comes from the
  /// video's own rendered box: if the scaled frame is smaller than the screen
  /// on an axis, that axis is pinned to 0 and simply cannot be panned.
  void _clampOffset() {
    if (!mounted) return;

    final screen = MediaQuery.sizeOf(context);
    final base = _baseVideoSize(screen);

    final scaledW = base.width * _videoScale;
    final scaledH = base.height * _videoScale;

    final maxX = ((scaledW - screen.width) / 2).clamp(0.0, double.infinity);
    final maxY = ((scaledH - screen.height) / 2).clamp(0.0, double.infinity);

    _videoOffset = Offset(
      _videoOffset.dx.clamp(-maxX, maxX),
      _videoOffset.dy.clamp(-maxY, maxY),
    );
  }

  @override
  void initState() {
    super.initState();

    _currentIndex =
    _hasLocalList
        ? widget.initialIndex.clamp(0, widget.videos.length - 1)
        : 0;

    // ✅ Reuse external player/controller if coming from floating.
    //    FloatingVideoManager.detach() transfers ownership to us, so we ARE
    //    responsible for disposing it (the old `_ownsPlayer = false` here meant
    //    nobody ever did, leaking a native player per PiP round-trip).
    if (widget.externalPlayer != null && widget.externalController != null) {
      _player = widget.externalPlayer!;
      _controller = widget.externalController!;
      _ownsPlayer = true;
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
      _ownsPlayer = true; // ✅ we created it -> safe to dispose

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        if (_hasUrl) {
          await _playFromUrl(widget.initialUrl!.trim());
        } else {
          await _loadVideo();
        }
      });
    }

    // ✅ Player gain init (boost ceiling + current gain).
    //    The mpv context is not ready the instant the Player is constructed, so
    //    this is deferred; every `open()` re-checks it as a safety net.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await _initVolumeBoost();
    });

    // Initialise brightness.
    // screen_brightness 2.1 deprecated `current` / `setScreenBrightness` /
    // `resetScreenBrightness` in favour of the `application*` variants, which
    // scope the change to this app instead of the whole device.
    ScreenBrightness().application.then((value) {
      if (mounted) _brightness = value;
    }).catchError((Object _) {
      // Brightness unavailable (emulator / restricted OEM) — keep the default.
    });

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

    // ✅ Listen to position changes.
    //    Rebuilding the whole (very large) player tree on every position tick
    //    caused constant jank. The UI only ever renders whole seconds, so skip
    //    the rebuild unless the displayed second actually changed — while the
    //    user is scrubbing, the drag handler owns `_currentPosition`.
    _positionSub = _player.stream.position.listen((position) {
      if (!mounted) return;
      if (_isDragging || _panIsHorizontal) return;
      if (position.inSeconds == _currentPosition.inSeconds) return;
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
    _completedSub = _player.stream.completed.listen((completed) async {
      if (!completed) return;

      if (!_hasLocalList) {
        // URL mode: do nothing on completed (or you can loop)
        return;
      }

      if (_currentIndex == widget.videos.length - 1) {
        // End of the playlist — just stop. (The old code toggled a `_showLogo`
        // flag that nothing ever rendered, then waited 5 s and set it again.)
        await _player.pause();
        if (mounted) {
          setState(() => _controlsVisible = true);
        }
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
      globalPlayPause.update(playing);
      // `globalPlayPause` is not listened to by this widget, so without an
      // explicit rebuild the center overlay and the bottom bar icon would keep
      // showing the previous state until some other setState happened to fire.
      setState(() {});
    });
  }

  /// Re-applies the gain after a new media is opened.
  ///
  /// mpv keeps `volume` across files, but `volume-max` and the filter chain can
  /// be reset by a fresh context, so both are re-established here.
  Future<void> _restoreGainAfterOpen() async {
    if (!_boostReady) {
      await _initVolumeBoost();
    } else {
      await _applyPlayerVolume();
    }
  }

  Future<void> _playFromUrl(String url) async {
    try {
      setState(() {
        _isLoading = true;
        _videoScale = 1.0; // ✅ reset zoom
        _videoOffset = Offset.zero;
      });

      await _player.open(Media(url), play: true);
      await _restoreGainAfterOpen();

      _syncFromPlayerState();
    } catch (e) {
      Fluttertoast.showToast(
        msg: "${_t('player_link_play_failed_prefix')} $e",
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
      _videoScale = 1.0; // ✅ reset zoom
      _videoOffset = Offset.zero;
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

    // The file lookup above can take a while (MediaStore/cloud-backed
    // resolution); if the user backed out of the screen while it was
    // pending, `dispose()` already tore `_player` down — using it here
    // would throw on a disposed native player.
    if (!mounted) return;

    if (file != null) {
      try {
        await _player.open(Media(file.path), play: false);
        await _restoreGainAfterOpen();
        await Future.delayed(const Duration(milliseconds: 100));
        await _player.play();
      } catch (e) {
        if (mounted) {
          Fluttertoast.showToast(
            msg: "${_t('player_playback_failed_prefix')} $e",
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
        }
      }
    } else {
      Fluttertoast.showToast(
        msg: _t('player_video_file_not_found'),
        gravity: ToastGravity.CENTER,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _applyEqualizer() async {
    // Gain now flows through exactly one path (boost × equalizer).
    await _applyPlayerVolume();
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

      // The rendered video box changes with the fit mode, so an offset that
      // was valid before can now push the picture off screen.
      _clampOffset();
    });

    showCenterToast(context, _resizeMode.name.toUpperCase());
  }

  /// The toast currently on screen, so it can be removed exactly once.
  OverlayEntry? _activeToast;
  Timer? _toastTimer;

  void showCenterToast(BuildContext context, String message) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    // Never stack toasts — remove the previous one first.
    _toastTimer?.cancel();
    _activeToast?.remove();
    _activeToast = null;

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
                color: Colors.black.withValues(alpha:0.85),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.3),
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

    overlay.insert(entry);
    _activeToast = entry;

    // The old code called `entry.remove()` from an unguarded Future.delayed —
    // if the screen closed within 900 ms that threw on an already-removed entry.
    _toastTimer = Timer(const Duration(milliseconds: 900), () {
      if (!identical(_activeToast, entry)) return;
      entry.remove();
      _activeToast = null;
    });
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

      if (data == null) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: _t('player_screenshot_failed_empty_frame'),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 14,
          );
        }
        return;
      }

      // ✅ Ask for gallery permission before saving
      final ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: _t('player_storage_permission_denied'),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.CENTER,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 14,
          );
        }
        return;
      }

      // ✅ Actually save the bytes to the gallery
      final fileName =
          'screenshot_${DateTime.now().millisecondsSinceEpoch}.png';
      final AssetEntity? saved = await PhotoManager.editor.saveImage(
        data,
        filename: fileName,
      );

      if (context.mounted) {
        Fluttertoast.showToast(
          msg: saved != null
              ? _t('player_screenshot_saved')
              : _t('player_screenshot_save_failed'),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.CENTER,
          backgroundColor: saved != null ? Colors.green : Colors.red,
          textColor: Colors.white,
          fontSize: 14,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${_t('player_screenshot_failed_prefix')} $e')));
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

    // Apply immediately — the old code waited 3 seconds *before* flipping the
    // filter, which made the button feel broken. The badge still shows briefly.
    setState(() {
      _hdrOn = !_hdrOn;
      _selectedFilter = _hdrOn ? 'hdr' : '';
      _showHdrOverlay = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (mounted) {
      setState(() => _showHdrOverlay = false);
    }
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
      currentBoost: _volumeBoost,
      maxBoostPercent: _maxBoost,
      boostEnabled: _boostReady,
      onVolumeChange: (v) async {
        final clamped = v.clamp(0.0, 1.0);
        await VolumeController.instance.setVolume(clamped);
        if (!mounted) return;
        setState(() {
          _systemVolume = clamped * 100;
        });
      },
      onBoostChange: (b) async {
        await _setVolumeBoost(b);
      },
    );
  }

  /// ✅ Manual boost control (100–150%) for people who don't want to swipe.
  void _openBoostDialog() {
    if (!_boostReady) {
      showCenterToast(context, _t('player_boost_not_supported'));
      return;
    }

    double temp = _volumeBoost;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: const Color(0xFF11131A),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: Color(0xFFFF8A00)),
              const SizedBox(width: 10),
              Text(
                _t('volume_boost_title'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${temp.round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Slider(
                value: temp,
                min: 100,
                max: _maxBoost,
                divisions: ((_maxBoost - 100) / 10).round(),
                activeColor: const Color(0xFFFF8A00),
                inactiveColor: Colors.white24,
                onChanged: (v) {
                  setLocal(() => temp = v);
                  _setVolumeBoost(v); // live apply
                },
              ),
              Text(
                // _maxBoost is 150 now, so the old `temp > 200` check could
                // never fire — the distortion hint starts in the top third.
                temp > 130
                    ? _t('volume_hint_distort')
                    : _t('player_boost_hint_normal'),
                style: TextStyle(
                  color: temp > 130 ? Colors.orangeAccent : Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _setVolumeBoost(100);
                Navigator.pop(ctx);
              },
              child:
              Text(_t('common_reset'), style: const TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_t('common_done'),
                  style: const TextStyle(color: Colors.greenAccent)),
            ),
          ],
        ),
      ),
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
      Offset localPosition,
      Offset delta,
      BuildContext context,
      ) {
    final screenHeight = MediaQuery.of(context).size.height;
    // ✅ #6: trigger when the touch starts near the BOTTOM edge (bottom ~12%)
    // and the finger is moving UP. Old check (dy > height*1) was impossible.
    if (localPosition.dy > screenHeight * 0.88 && delta.dy < -5) {
      _showBottomBarTemporarily();
    }
  }

  // =========================================================
  // ✅ SCALE ENGINE: 1 finger = MX pan, 2 finger = ZOOM
  // =========================================================
  /// Abandons any in-flight single-finger pan.
  ///
  /// Needed when a pinch interrupts a drag: the old code only flipped the
  /// `_panIs*` flags, leaving `_pendingSeekPos` and `_seekThrottle` armed. Since
  /// `_onScaleEnd` early-returns while zooming, `_panEndLogic()` never ran, so
  /// that stale position was applied on the NEXT drag — the video jumped back
  /// to wherever the interrupted seek had been.
  void _abortPan() {
    _panActive = false;
    _panIsHorizontal = false;
    _panIsVertical = false;
    _verticalDragLeft = false;
    _verticalDragRight = false;

    _seekThrottle?.cancel();
    _seekThrottle = null;
    _pendingSeekPos = null;

    _hideSeekOverlay(immediate: true);
    _hideSeekBubble(immediate: true);
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (_isLocked) return;

    if (details.pointerCount >= 2) {
      _isZooming = true;
      _baseScaleOnGesture = _videoScale;
      _abortPan();
      return;
    }

    _isZooming = false;
    _panStartLogic(details.localFocalPoint);
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    if (_isLocked) return;

    // ---------- 2 FINGER ZOOM ----------
    if (details.pointerCount >= 2) {
      if (!_isZooming) {
        // A second finger landed mid-drag — drop the pan cleanly.
        _isZooming = true;
        _baseScaleOnGesture = _videoScale;
        _abortPan();
      }

      final newScale =
      (_baseScaleOnGesture * details.scale).clamp(_minScale, _maxScale);

      setState(() {
        _videoScale = newScale;

        // ⚠️ Do NOT apply `details.focalPointDelta` here.
        //
        // During a pinch, focalPointDelta is the drift of the midpoint between
        // the two fingers. Real fingers never pinch symmetrically, so that
        // midpoint wanders every frame — feeding it into `_videoOffset` made
        // the video slide up/down while the user was only trying to zoom.
        //
        // Repositioning belongs to the single-finger drag (_panUpdateLogic),
        // which only runs once we're already zoomed in.
        if (_videoScale <= 1.0) {
          _videoOffset = Offset.zero;
        } else {
          // Zooming back out shrinks the allowed offset range, so re-clamp to
          // keep the frame from staying stuck off-centre.
          _clampOffset();
        }

        _showZoomBadge = true;
      });

      _zoomBadgeTimer?.cancel();
      _zoomBadgeTimer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showZoomBadge = false);
      });
      return;
    }

    // ---------- 1 FINGER (MX pan) ----------
    if (_isZooming) return; // pinch ke baad bacha hua single finger ignore
    await _panUpdateLogic(details.localFocalPoint, details.focalPointDelta);
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isZooming) {
      _isZooming = false;
      // Nothing to commit: _abortPan() already cleared the pan state when the
      // pinch began, so no stale seek can leak into the next gesture.
      return;
    }
    _panEndLogic();
  }

  // ----- pan logic (same as before, sirf Offset based) -----
  void _panStartLogic(Offset localPosition) async {
    _panActive = true;
    _panIsHorizontal = false;
    _panIsVertical = false;

    _panStart = localPosition;
    _panStartPos = _player.state.position;

    // ✅ boost-aware: one continuous 0.._maxBoost scale
    _panStartVolume = _combinedVolume;

    // ✅ immediate default so first swipe has no jitter
    _panStartBrightness = _brightness;
    try {
      _panStartBrightness = await ScreenBrightness().application;
    } catch (_) {}

    _hideSeekOverlay(immediate: true);
    _hideSeekBubble(immediate: true);
  }

  Future<void> _panUpdateLogic(Offset localPosition, Offset delta) async {
    if (!_panActive || _isLocked) return;

    // ✅ Zoomed video stays LOCKED in place — a single finger must never
    //    scroll/reposition the zoomed picture. The zoom stays centered and the
    //    single-finger drag falls through to the normal seek / brightness /
    //    volume gestures instead. (Repositioning is intentionally disabled per
    //    request: after pinch-zoom, one finger should not slide the frame.)

    _onUserInteractionFromBottom(localPosition, delta, context);

    final size = MediaQuery.of(context).size;
    final dxTotal = localPosition.dx - _panStart.dx;
    final dyTotal = localPosition.dy - _panStart.dy;

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

      // Fixed rate: swiping the full screen width == _seekSecondsPerScreenWidth
      // of video, no matter how long the clip is.
      final relative = dxTotal / size.width;
      final offsetMs =
      (relative * _seekSecondsPerScreenWidth * 1000).toInt();

      int newMs = _panStartPos.inMilliseconds + offsetMs;
      newMs = newMs.clamp(0, duration.inMilliseconds);

      final newPos = Duration(milliseconds: newMs);
      _throttledSeek(newPos);

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
      final dragDelta = (-dyTotal / h); // swipe up => +ve

      if (_verticalDragLeft) {
        final b = (_panStartBrightness + dragDelta * _briSpeed).clamp(0.0, 1.0);
        _brightness = b;

        try {
          await ScreenBrightness().setApplicationScreenBrightness(b);
        } catch (_) {}

        setState(() => _showBrightnessOverlay = true);

        _brightnessTimer?.cancel();
        _brightnessTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showBrightnessOverlay = false);
        });
      } else if (_verticalDragRight) {
        // ✅ ONE continuous scale: 0..100 moves the device, 100.._maxBoost
        //    moves the software boost. No remapping, so the meter just keeps
        //    filling from where it was — it only changes colour at the gate.
        //    Without boost support the gesture simply stops at 100, as before.
        final ceiling = _boostReady ? _maxBoost : 100.0;
        final c = (_panStartVolume + dragDelta * _volSpeed).clamp(0.0, ceiling);

        final double sys = c <= 100 ? c : 100;
        final double boost = c <= 100 ? 100 : c;

        setState(() {
          _systemVolume = sys;
          _volumeBoost = boost;
          _showVolumeOverlay = true;
        });

        _handleVolumeEdgeHaptic(c);

        _volThrottle?.cancel();
        _volThrottle = Timer(const Duration(milliseconds: 35), () async {
          await VolumeController.instance.setVolume(_systemVolume / 100);
          await _applyPlayerVolume();
        });

        _volumeTimer?.cancel();
        _volumeTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _showVolumeOverlay = false);
        });
      }
    }
  }

  void _panEndLogic() {
    _panActive = false;
    _panIsHorizontal = false;
    _panIsVertical = false;
    _verticalDragLeft = false;
    _verticalDragRight = false;

    // ✅ make sure final seek position is applied
    if (_pendingSeekPos != null) {
      _player.seek(_pendingSeekPos!);
      _pendingSeekPos = null;
    }

    _hideSeekOverlay(immediate: false);
    _hideSeekBubble(immediate: false);
  }

  // ✅ Throttled seek: instant first seek, then at most every 80ms
  void _throttledSeek(Duration pos) {
    _pendingSeekPos = pos;
    if (_seekThrottle?.isActive ?? false) return;

    _player.seek(pos);
    _seekThrottle = Timer(const Duration(milliseconds: 80), () {
      if (_pendingSeekPos != null) {
        _player.seek(_pendingSeekPos!);
      }
    });
  }

  /// Haptic ticks at the three meaningful points of the volume swipe:
  /// silence (0), the boost gate (100 — device maxed, software gain starts)
  /// and the top of the boost range (_maxBoost).
  void _handleVolumeEdgeHaptic(double c) {
    final now = DateTime.now();
    if (now.difference(_lastHapticAt).inMilliseconds < 180) return;

    int edge = -1;
    if (c <= 0.0) {
      edge = 0;
    } else if (c >= _maxBoost - 0.5) {
      edge = 2;
    } else if (c >= 99.0 && c <= 101.0) {
      edge = 1; // boost gate
    }

    if (edge == -1) {
      _lastHapticEdge = -1;
      return;
    }
    if (edge == _lastHapticEdge) return;

    _lastHapticEdge = edge;
    _lastHapticAt = now;

    if (edge == 1) {
      HapticFeedback.selectionClick();
    } else {
      HapticFeedback.mediumImpact();
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

  /// Double tap left/right to skip 10 s.
  ///
  /// The `_skipDirection` / `_showSkipOverlay` flags that used to be set here
  /// were never rendered — `_showSeekOverlayText` is what actually draws the
  /// ±10 s badge — so they have been dropped.
  void _onDoubleTapDown(TapDownDetails details) {
    if (_isLocked) return;

    final width = MediaQuery.of(context).size.width;
    final position = _player.state.position;
    final duration = _player.state.duration;
    if (duration.inMilliseconds <= 0) return;

    final rewinding = details.localPosition.dx < width / 2;
    final deltaMs = rewinding ? -10000 : 10000;

    final newPos = Duration(
      milliseconds:
      (position.inMilliseconds + deltaMs).clamp(0, duration.inMilliseconds),
    );

    _player.seek(newPos);
    setState(() {
      _currentPosition = newPos;
      _bubblePos = newPos;
    });

    _showSeekOverlayText(rewinding ? "-00:10" : "+00:10");
    _showSeekBubbleNow();
  }

  // =========================================================

  /// Hands the live player over to the floating (PiP) window.
  ///
  /// Ownership moves with the player: after this we must NOT dispose it, and
  /// the floating window becomes responsible for it. The boost gain travels
  /// with it too, since it lives on the player itself.
  void _moveToFloating() {
    if (!_hasLocalList) return;
    if (FloatingVideoManager.isActive) return;

    _ownsPlayer = false; // floating owns it now
    FloatingVideoManager.show(
      context,
      _player,
      _controller,
      widget.videos,
      _currentIndex,
    );
  }

  @override
  void dispose() {
    // ⚠️ Order matters: cancel every subscription/timer BEFORE tearing the
    // player down. The old code disposed the player first, so in-flight
    // position/duration events still called setState() on a dead State.
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
    _playingSub?.cancel();
    _volumeSubscription?.cancel();

    _hideTimer?.cancel();
    _systemUiTimer?.cancel();
    _brightnessTimer?.cancel();
    _volumeTimer?.cancel();
    _volThrottle?.cancel();
    _seekThrottle?.cancel();
    _seekOverlayTimer?.cancel();
    _seekBubbleTimer?.cancel();
    _zoomBadgeTimer?.cancel();

    // Remove any center-toast overlay still scheduled for removal.
    _toastTimer?.cancel();
    _activeToast?.remove();
    _activeToast = null;

    // Dispose only what we still own. `_ownsPlayer` is set to false the moment
    // the player is handed to the floating window.
    if (_ownsPlayer) {
      try {
        _player.dispose();
      } catch (_) {
        // Already disposed by whoever else held it.
      }
    }

    // Always restore the system brightness, otherwise the screen stays stuck
    // at whatever the swipe gesture set.
    ScreenBrightness().resetApplicationScreenBrightness().catchError((Object _) {});

    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Fires on MediaQuery changes too (e.g. rotation), where the rendered
    // video box changes and a previously valid offset may now be out of range.
    _clampOffset();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // guard: this fires after dispose otherwise
      if (_isLocked) return;
      setState(() => _controlsVisible = true);
      _startHideTimer();
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
      barrierLabel: _t('player_controls_barrier_label'),
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha:0.55),
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
                  color: Colors.black.withValues(alpha:0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha:0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha:0.7),
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
                          Expanded(
                            child: Text(
                              _t('player_controls_title'),
                              style: const TextStyle(
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

                    Divider(color: Colors.white.withValues(alpha:0.12), height: 1),

                    // ✅ Scroll Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _sheetTitle(_t('player_quick_actions')),
                            const SizedBox(height: 10),

                            // ✅ same controls
                            _controlGrid([
                              _controlItem(
                                icon: Icons.camera_alt,
                                label: _t('player_action_screenshot'),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _takeScreenshot();
                                },
                              ),
                              _controlItem(
                                icon: Icons.screen_rotation,
                                label: _t('player_action_rotate'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _toggleOrientation();
                                },
                              ),
                              _controlItem(
                                icon: Icons.headphones,
                                label: _audioOnly ? _t('player_action_video_on') : _t('player_action_audio_only'),
                                active: _audioOnly,
                                onTap: () async {
                                  Navigator.pop(context);
                                  await _toggleAudioOnly();
                                },
                              ),
                              _controlItem(
                                icon: Icons.color_lens,
                                label: _t('player_action_filters'),
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
                                label: _t('player_action_hdr'),
                                active: _selectedFilter == 'hdr',
                                onTap: () async {
                                  Navigator.pop(context);
                                  await toggleHdr();
                                },
                              ),
                              _controlItem(
                                icon: Icons.volume_up,
                                label: _t('volume_title'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _openVolumeDialog();
                                },
                              ),
                              // ✅ NEW: volume boost
                              _controlItem(
                                icon: Icons.graphic_eq,
                                label: _t('player_action_boost'),
                                active: _isBoosting,
                                disabled: !_boostReady,
                                onTap: !_boostReady
                                    ? null
                                    : () {
                                  Navigator.pop(context);
                                  _openBoostDialog();
                                },
                              ),
                              _controlItem(
                                icon: Icons.speed,
                                label: _t('player_action_speed'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _openSpeedDialog();
                                },
                              ),
                              _controlItem(
                                icon: Icons.picture_in_picture_alt,
                                label: _t('player_action_pip'),
                                disabled: !_hasLocalList,
                                onTap: !_hasLocalList
                                    ? null
                                    : () {
                                  Navigator.pop(context); // close sheet only
                                  _moveToFloating();
                                },
                              ),
                            ]),

                            const SizedBox(height: 14),
                            Divider(color: Colors.white.withValues(alpha:0.12)),
                            const SizedBox(height: 12),

                            _sheetTitle(_t('player_playback_section')),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.center,
                              children: [
                                _pillButton(
                                  icon: _isLocked ? Icons.lock : Icons.lock_open,
                                  label: _isLocked ? _t('player_locked') : _t('player_lock'),
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
                                  globalPlayPause.isPlaying ? _t('common_pause') : _t('common_play'),
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
                                  label: _t('player_prev'),
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
                                  label: _t('player_next'),
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
                                  label: _t('player_resize'),
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
              color: Colors.black.withValues(alpha:0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha:0.10)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.6),
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
                      Expanded(
                        child: Text(
                          _t('player_controls_title'),
                          style: const TextStyle(
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

                Divider(color: Colors.white.withValues(alpha:0.12), height: 1),

                // ✅ scrollable body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sheetTitle(_t('player_quick_actions')),
                        const SizedBox(height: 10),

                        // ✅ SAME ICONS (fixed size portrait/landscape)
                        _controlGrid([
                          _controlItem(
                            icon: Icons.camera_alt,
                            label: _t('player_action_screenshot'),
                            onTap: () async {
                              Navigator.pop(context);
                              await _takeScreenshot();
                            },
                          ),
                          _controlItem(
                            icon: Icons.screen_rotation,
                            label: _t('player_action_rotate'),
                            onTap: () {
                              Navigator.pop(context);
                              _toggleOrientation();
                            },
                          ),
                          _controlItem(
                            icon: Icons.headphones,
                            label: _audioOnly ? _t('player_action_video_on') : _t('player_action_audio_only'),
                            active: _audioOnly,
                            onTap: () async {
                              Navigator.pop(context);
                              await _toggleAudioOnly();
                            },
                          ),
                          _controlItem(
                            icon: Icons.color_lens,
                            label: _t('player_action_filters'),
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
                            label: _t('player_action_hdr'),
                            active: _selectedFilter == 'hdr',
                            onTap: () async {
                              Navigator.pop(context);
                              await toggleHdr();
                            },
                          ),
                          _controlItem(
                            icon: Icons.volume_up,
                            label: _t('volume_title'),
                            onTap: () {
                              Navigator.pop(context);
                              _openVolumeDialog();
                            },
                          ),
                          // ✅ NEW: volume boost
                          _controlItem(
                            icon: Icons.graphic_eq,
                            label: _t('player_action_boost'),
                            active: _isBoosting,
                            disabled: !_boostReady,
                            onTap: !_boostReady
                                ? null
                                : () {
                              Navigator.pop(context);
                              _openBoostDialog();
                            },
                          ),
                          _controlItem(
                            icon: Icons.speed,
                            label: _t('player_action_speed'),
                            onTap: () {
                              Navigator.pop(context);
                              _openSpeedDialog();
                            },
                          ),
                          _controlItem(
                            icon: Icons.picture_in_picture_alt,
                            label: _t('player_action_pip'),
                            disabled: !_hasLocalList,
                            onTap: !_hasLocalList
                                ? null
                                : () {
                              Navigator.pop(context); // close sheet only
                              _moveToFloating();
                            },
                          ),
                        ]),

                        const SizedBox(height: 14),
                        Divider(color: Colors.white.withValues(alpha:0.12)),
                        const SizedBox(height: 12),

                        _sheetTitle(_t('player_playback_section')),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            _pillButton(
                              icon: _isLocked ? Icons.lock : Icons.lock_open,
                              label: _isLocked ? _t('player_locked') : _t('player_lock'),
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
                              label: globalPlayPause.isPlaying ? _t('common_pause') : _t('common_play'),
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
                              label: _t('player_prev'),
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
                              label: _t('player_next'),
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
                              label: _t('player_resize'),
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
              ? Colors.white.withValues(alpha:0.18)
              : Colors.white.withValues(alpha:0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? Colors.white.withValues(alpha:0.22)
                : Colors.white.withValues(alpha:0.10),
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
              ? Colors.white.withValues(alpha:0.18)
              : Colors.white.withValues(alpha:0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha:0.12)),
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


  // =========================================================
  // ✅ HUD OVERLAYS — one unified, production-grade glass style
  //    used by every transient gesture badge (zoom %, seek delta,
  //    time preview) and the brightness / volume meters. Keeping the
  //    look in these two helpers means every overlay stays consistent.
  // =========================================================

  /// Soft "pop-in" wrapper so a badge scales + fades up when it appears.
  Widget _hudPopIn({required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.82, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (_, v, c) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: v, child: c),
      ),
      child: child,
    );
  }

  /// Frosted-glass pill: icon + text. Used for zoom %, seek ±, time preview.
  Widget _hudPill({
    required IconData icon,
    required String text,
    Color? accent,
    double fontSize = 14,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent ?? Colors.white, size: fontSize + 5),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vertical brightness / volume meter — a matched pair so left (brightness)
  /// and right (volume) read as the same control.
  ///
  /// The fill is drawn as TWO stacked segments so the boost range continues
  /// from where the device volume ended instead of restarting at the bottom:
  ///
  ///   [baseFraction]  purple  — device volume (0..100)
  ///   remainder       orange  — software boost (100.._maxBoost)
  ///
  /// [gate] draws a thin tick at the 100% mark so the hand-over point is
  /// visible. Callers that have a single value (brightness) simply omit both
  /// and get the old single-colour behaviour.
  Widget _hudMeter({
    required IconData icon,
    required double fraction, // total fill 0..1
    required int value,
    bool boost = false,
    double? baseFraction,
    double? gate,
  }) {
    const double trackH = 150;
    const double trackW = 8;

    const Color baseA = Color(0xFF7C4DFF);
    const Color baseB = Color(0xFF9D6BFF);
    const Color boostA = Color(0xFFFF8A00);
    const Color boostB = Color(0xFFFFC857);

    final accent = boost ? boostA : ColorSelect.maineColor;

    final f = fraction.clamp(0.0, 1.0);
    final baseF = (baseFraction ?? f).clamp(0.0, f);
    final boostF = (f - baseF).clamp(0.0, 1.0);

    return _hudPopIn(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.40),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  boost ? '$value%' : '$value',
                  style: TextStyle(
                    color: boost ? boostB : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (boost) ...[
                  const SizedBox(height: 2),
                  Text(
                    _t('volume_boost_badge'),
                    style: TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  width: trackW,
                  height: trackH,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(trackW),
                  ),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    clipBehavior: Clip.none,
                    children: [
                      // ---- 100% gate tick ----
                      if (gate != null)
                        Positioned(
                          bottom: trackH * gate.clamp(0.0, 1.0),
                          child: Container(
                            width: trackW,
                            height: 2,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),

                      // ---- device volume / brightness segment ----
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOutCubic,
                        width: trackW,
                        height: trackH * baseF,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [baseA, baseB],
                          ),
                          borderRadius: BorderRadius.circular(trackW),
                          boxShadow: [
                            BoxShadow(
                              color: baseA.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),

                      // ---- boost segment: continues from the gate ----
                      if (boostF > 0)
                        Positioned(
                          bottom: trackH * baseF,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            curve: Curves.easeOutCubic,
                            width: trackW,
                            height: trackH * boostF,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [boostA, boostB],
                              ),
                              borderRadius: BorderRadius.circular(trackW),
                              boxShadow: [
                                BoxShadow(
                                  color: boostA.withValues(alpha: 0.6),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Icon(icon, color: boost ? boostB : Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =================== BUILD (UI SAME) =====================
  @override
  Widget build(BuildContext context) {
    _lang = context.watch<LocaleProvider>().locale.languageCode;
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final double equalizerBottom = isLandscape ? 70 : 130;
    final playSize = isLandscape ? 22.sp : 45.sp;
    final sideSize = isLandscape ? 15.sp : 28.sp;
    final bottomPadding = isLandscape ? 0.sp : 40.sp;

    final maxMs = _totalDuration.inMilliseconds;
    final safeMax = (maxMs <= 0 ? 1 : maxMs);
    final posMs = _currentPosition.inMilliseconds.clamp(0, safeMax);

    // ✅ Volume meter geometry — ONE scale for device + boost.
    final double _volScale = _boostReady ? _maxBoost : 100.0;
    final double _volTotal = _isBoosting ? _volumeBoost : _systemVolume;

    final String appBarTitle =
    _hasLocalList
        ? (widget.videos[_currentIndex].title ?? '')
        : (_hasUrl ? widget.initialUrl!.trim() : _t('player_streaming_title'));

    // ✅ Transform wrapper for pinch-to-zoom
    final videoWidget = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..translate(_videoOffset.dx, _videoOffset.dy)
        ..scale(_videoScale),
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(
          _getColorMatrix(_selectedFilter, hdrIntensity: 0.8),
        ),
        child: Video(
          controller: _controller,
          fit:
          _resizeMode == VideoResizeMode.fit
              ? BoxFit.contain // whole frame, letterboxed
              : _resizeMode == VideoResizeMode.fill
              ? BoxFit.cover // fill screen, keep aspect, crop overflow
              : _resizeMode == VideoResizeMode.zoom
              ? BoxFit.fitWidth // zoom to width, crop top/bottom
              : BoxFit.fill, // stretch: distort to exactly fill screen
          controls: null,
        ),
      ),
    );

    // `WillPopScope` is never invoked once the manifest sets
    // android:enableOnBackInvokedCallback="true" (Android 13+ predictive back),
    // so the PiP hand-off silently stopped working. `PopScope` is the API that
    // works with the new back dispatcher.
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Only hand over to PiP for local playlists; URL streams have no queue.
        // if (_hasLocalList) _moveToFloating();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,

        // ✅ Scale engine (1 finger = pan, 2 finger = zoom)
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,

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

              // ✅ Center tap zone — single tap toggles play/pause.
              //    `HitTestBehavior.opaque` keeps the tap here instead of
              //    letting it fall through to `_onScreenTap` (controls
              //    show/hide). Pan / pinch still reach the parent detector, so
              //    seek, brightness, volume and zoom behave exactly as before.
              //    The icon is only built while paused.
              if (!_isLocked)
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.32,
                    height: MediaQuery.of(context).size.height * 0.28,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlayPause,
                      // Swallow the double tap so the center never triggers the
                      // ±10 s skip.
                      onDoubleTap: () {},
                      child: globalPlayPause.isPlaying
                          ? const SizedBox.expand()
                          : Center(
                        child: IgnorePointer(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: playSize + 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // ✅ Center seek overlay
              if (_showSeekOverlay)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: _hudPopIn(
                        child: _hudPill(
                          icon: _seekOverlayText.startsWith('-')
                              ? Icons.fast_rewind_rounded
                              : Icons.fast_forward_rounded,
                          text: _seekOverlayText,
                          accent: ColorSelect.maineColor,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                ),

              // ✅ Zoom level badge
              if (_showZoomBadge)
                Positioned(
                  top: 70,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _hudPopIn(
                        child: _hudPill(
                          icon: Icons.zoom_in_rounded,
                          text: "${(_videoScale * 100).round()}%",
                          accent: ColorSelect.maineColor,
                        ),
                      ),
                    ),
                  ),
                ),

              // ✅ Seek bubble (time preview) — sits just below the top badges
              if (_showSeekBubble)
                Positioned(
                  top: 120,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _hudPopIn(
                        child: _hudPill(
                          icon: Icons.schedule_rounded,
                          text:
                          "${_formatDuration(_bubblePos)}  /  ${_formatDuration(_totalDuration)}",
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),

              // brightness overlay
              if (_showBrightnessOverlay)
                Align(
                  alignment: const Alignment(-0.85, 0),
                  child: IgnorePointer(
                    child: _hudMeter(
                      icon: _brightness > 0.5
                          ? Icons.brightness_high_rounded
                          : Icons.brightness_low_rounded,
                      fraction: _brightness,
                      value: (_brightness * 100).round(),
                    ),
                  ),
                ),

              // ✅ volume overlay (boost-aware, continuous fill)
              if (_showVolumeOverlay)
                Align(
                  alignment: const Alignment(0.85, 0),
                  child: IgnorePointer(
                    child: _hudMeter(
                      icon: _isBoosting
                          ? Icons.graphic_eq_rounded
                          : _systemVolume <= 0
                          ? Icons.volume_off_rounded
                          : _systemVolume < 50
                          ? Icons.volume_down_rounded
                          : Icons.volume_up_rounded,
                      fraction: _volTotal / _volScale,
                      baseFraction: _systemVolume / _volScale,
                      gate: _boostReady ? 100 / _volScale : null,
                      value: _volTotal.round(),
                      boost: _isBoosting,
                    ),
                  ),
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
                        color: Colors.black.withValues(alpha:0.45),
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
                                  color: Colors.black.withValues(alpha:0.65),
                                  blurRadius: 35,
                                  spreadRadius: 4,
                                ),
                              ],
                              border: Border.all(
                                color: Colors.white.withValues(alpha:0.12),
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
                                          Colors.white.withValues(alpha: 0.35),
                                          Colors.white.withValues(alpha: 0.05),
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
                                  _t('player_hdr_processing'),
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
                                      ? _t('player_hdr_turning_off')
                                      : _t('player_hdr_turning_on'),
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
                      color: Colors.black.withValues(alpha:0.5),
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
                      color: Colors.black.withValues(alpha:0.4),
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
                              appOpenManager.showInterstitialIfAllowed(
                                onContinue: () {
                                  if (!mounted) return;
                                  ScreenBrightness()
                                      .resetApplicationScreenBrightness()
                                      .catchError((Object _) {});
                                  Navigator.pop(context);
                                },
                              );
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
                          onBackPressedMore: openControlsSheetSmart,
                        )
                            : Container(
                          child: _StreamTopBar(
                            title: appBarTitle,
                            onBack: () {
                              appOpenManager.showInterstitialIfAllowed(
                                onContinue: () {
                                  if (!mounted) return;
                                  ScreenBrightness()
                                      .resetApplicationScreenBrightness()
                                      .catchError((Object _) {});
                                  Navigator.pop(context);
                                },
                              );
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
                                      _moveToFloating();
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
  /// `MM:SS`, or `H:MM:SS` once the clip runs past an hour.
  ///
  /// The old version only emitted `MM:SS` using `inMinutes.remainder(60)`, so
  /// hours were silently dropped: a 1:20:15 film displayed as "20:15" and a
  /// 2:00:00 one as "00:00".
  String _formatDuration(Duration d) {
    final negative = d.isNegative;
    final abs = negative ? -d : d;

    final hours = abs.inHours;
    final minutes = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = abs.inSeconds.remainder(60).toString().padLeft(2, '0');

    final text = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
    return negative ? '-$text' : text;
  }

  Future<void> _togglePlayPause() async {
    try {
      await (_player.state.playing ? _player.pause() : _player.play());
    } catch (_) {
      // Transient native-player state; nothing else to do about it here.
    }
  }

  Future<void> _seekBy(Duration offset) async {
    final duration = _player.state.duration;
    final maxMs = duration.inMilliseconds;

    var targetMs = (_currentPosition + offset).inMilliseconds;
    // clamp only if we know the duration; else just guard against negative
    if (maxMs > 0) {
      targetMs = targetMs.clamp(0, maxMs);
    } else if (targetMs < 0) {
      targetMs = 0;
    }

    final newPos = Duration(milliseconds: targetMs);
    await _player.seek(newPos);

    if (!mounted) return;
    setState(() {
      _currentPosition = newPos;
      _bubblePos = newPos;
    });
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