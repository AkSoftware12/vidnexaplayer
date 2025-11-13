import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';

/// ============================================================
/// FloatingVideoManager: displays a draggable overlay that
/// continues playing video across routes.
/// ============================================================
// ============================================================
// 🔥 GLOBAL SYNC CLASS — (Play/Pause sync between windows)
// ============================================================
class PlayPauseSync extends ChangeNotifier {
  bool isPlaying = false;

  void update(bool value) {
    isPlaying = value;
    notifyListeners();
  }
}

final globalPlayPause = PlayPauseSync();

// ============================================================
// 🟦 FLOATING VIDEO MANAGER
// ============================================================
class FloatingVideoManager {
  static OverlayEntry? _entry;
  static Player? _player;
  static VideoController? _controller;
  static List<AssetEntity>? _videos;
  static int _currentIndex = 0;
  static Offset _offset = const Offset(20, 100);

  static StreamSubscription<bool>? _playingSub;
  static bool _showControls = true;
  static Timer? _hideTimer;

  static void _showControlsTemporarily() {
    _showControls = true;
    _entry?.markNeedsBuild();
    _hideTimer?.cancel();

    _hideTimer = Timer(const Duration(seconds: 5), () {
      _showControls = false;
      _entry?.markNeedsBuild();
    });
  }

  /// Show floating player
  static void show(
      BuildContext context,
      Player player,
      VideoController controller,
      List<AssetEntity> videos,
      int currentIndex,
      ) {
    if (_entry != null) return;

    _player = player;
    _controller = controller;
    _videos = videos;
    _currentIndex = currentIndex;

    // LISTEN PLAY/PAUSE — GLOBAL SYNC
    _playingSub?.cancel();
    _playingSub = _player!.stream.playing.listen((playing) {
      globalPlayPause.update(playing); // 🔥 SYNC state global
      _entry?.markNeedsBuild();
    });

    _entry = OverlayEntry(builder: (overlayContext) {
      return Positioned(
        left: _offset.dx,
        top: _offset.dy,
        child: GestureDetector(
          onTap: _showControlsTemporarily,
          onPanUpdate: (details) {
            _offset += details.delta;
            _entry?.markNeedsBuild();
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 250.sp,
              height: 140.sp,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Video(controller: _controller!, controls: null),
                    ),
                  ),

                  // ==============================
                  // CONTROLS - AUTO HIDE
                  // ==============================
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedOpacity(
                      opacity: _showControls ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: Colors.black54,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        height: 36.sp,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            // ------------------------------------------------
                            // 🔥 Play / Pause synced with FullScreen Player
                            // ------------------------------------------------
                            IconButton(
                              icon: Icon(
                                globalPlayPause.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                              onPressed: () async {
                                _showControlsTemporarily();

                                if (globalPlayPause.isPlaying) {
                                  await _player?.pause();
                                } else {
                                  await _player?.play();
                                }
                              },
                            ),

                            // FullScreen
                            IconButton(
                              icon: Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                              onPressed: () {
                                _showControlsTemporarily();

                                final ctx = overlayContext;
                                hide();

                                Navigator.of(ctx).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenVideoPlayer(
                                      videos: _videos!,
                                      initialIndex: _currentIndex,
                                      externalPlayer: _player,
                                      externalController: _controller,
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Close
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                              onPressed: () {
                                _showControlsTemporarily();
                                hide();
                                _player?.pause();
                              },
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
        ),
      );
    });

    Overlay.of(context)!.insert(_entry!);
    _showControlsTemporarily();
  }

  static void hide() {
    _playingSub?.cancel();
    _hideTimer?.cancel();
    _entry?.remove();
    _entry = null;
  }

  static bool get isActive => _entry != null;
}

// ============================================================
// 🎛 CustomVideoControls (unchanged)
// ============================================================
class CustomVideoControls extends StatefulWidget {
  final Player player;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const CustomVideoControls({
    super.key,
    required this.player,
    this.onNext,
    this.onPrevious,
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
    return GestureDetector(
      onTap: () => setState(() => _visible = !_visible),
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Container(
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Slider(
                        value: _progress.clamp(0.0, 1.0),
                        onChanged: (v) {
                          final newPos = _duration * v;
                          widget.player.seek(newPos);
                        },
                        activeColor: Colors.redAccent,
                        inactiveColor: Colors.white24,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_format(_position),
                              style: const TextStyle(color: Colors.white, fontSize: 12)),
                          Text(_format(_duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.skip_previous_rounded),
                              color: Colors.white,
                              iconSize: 30,
                              onPressed: widget.onPrevious),
                          IconButton(
                              icon: const Icon(Icons.replay_10),
                              color: Colors.white,
                              iconSize: 28,
                              onPressed: () => _seekBy(const Duration(seconds: -10))),

                          IconButton(
                            icon: Icon(
                              globalPlayPause.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              color: Colors.white,
                              size: 50.sp,
                            ),
                            onPressed: () async {
                              if (globalPlayPause.isPlaying) {
                                await widget.player?.pause();
                              } else {
                                await widget.player?.play();
                              }
                            },
                          ),

                          IconButton(
                              icon: const Icon(Icons.forward_10),
                              color: Colors.white,
                              iconSize: 28,
                              onPressed: () => _seekBy(const Duration(seconds: 10))),
                          IconButton(
                              icon: const Icon(Icons.skip_next_rounded),
                              color: Colors.white,
                              iconSize: 30,
                              onPressed: widget.onNext),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 🎬 FullScreenVideoPlayer with global floating overlay support
// ============================================================
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
    final weightedGain = (bassGain * 0.6 + midGain * 0.3 + trebleGain * 0.1) / 15.0;
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
          0.6, 0, 0, 0, 0,
          0, 0.6, 0, 0, 0,
          0, 0, 0.6, 0, 0,
          0, 0, 0, 1.0, 0,
        ];
      case "blue":
        return [
          0.4, 0.2, 0.2, 0, 0,
          0.2, 0.4, 0.2, 0, 0.05,
          0.3, 0.3, 1.3, 0, 0.15,
          0, 0, 0, 1, 0,
        ];
      case "warm":
        return [
          1.6, 0.3, 0.1, 0, -30,
          0.2, 1.4, 0.1, 0, -30,
          0.1, 0.2, 1.1, 0, -20,
          0, 0, 0, 1.0, 0,
        ];
      case "sepia":
        return [
          0.5, 0.8, 0.2, 0, 0,
          0.4, 0.7, 0.2, 0, 0,
          0.2, 0.5, 0.1, 0, 0,
          0, 0, 0, 1, 0,
        ];
      case "neon":
        return [
          1.2, 0.3, 0.8, 0, 0.1,
          0.2, 0.7, 1.0, 0, 0.05,
          0.8, 0.2, 1.4, 0, 0.1,
          0, 0, 0, 1, 0,
        ];
      default:
        return [
          1, 0, 0, 0, 0,
          0, 1, 0, 0, 0,
          0, 0, 1, 0, 0,
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

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  Future<void> _takeScreenshot() async {
    try {
      final Uint8List? data = await _player.screenshot(format: 'image/png');
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

  void _onUserInteractionFromBottom(DragUpdateDetails details, BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (details.localPosition.dy > screenHeight * 0.9 && details.delta.dy < -5) {
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

  void _onDoubleTapDown(TapDownDetails details) {
    if (_isLocked) return;
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;
    final position = _player.state.position;
    final duration = _player.state.duration;
    if (duration.inMilliseconds <= 0) return;
    if (dx < width / 2) {
      // Left side: rewind 10 seconds
      final newPositionMs = (position.inMilliseconds - 10000).clamp(0, duration.inMilliseconds);
      _player.seek(Duration(milliseconds: newPositionMs));
      setState(() {
        _skipDirection = -1;
        _showSkipOverlay = true;
      });
    } else {
      // Right side: forward 10 seconds
      final newPositionMs = (position.inMilliseconds + 10000).clamp(0, duration.inMilliseconds);
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == widget.videos.length - 1;
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
        onVerticalDragUpdate: (details) => _onUserInteractionFromBottom(details, context),
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onDoubleTapDown: _onDoubleTapDown,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Stack(
            children: [
              Positioned.fill(child: videoWidget),

              // Show skip overlay when double tapped
              if (_showSkipOverlay)
                Center(
                  child: Icon(
                    _skipDirection == -1 ? Icons.replay_10 : Icons.forward_10,
                    color: Colors.white,
                    size: 80,
                  ),
                ),

              // Locked overlay
              if (_isLocked)
                Center(
                  child: GestureDetector(
                    onTap: _toggleLock,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
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
                CustomVideoControls(
                  player: _player,
                  onNext: _playNext,
                  onPrevious: _playPrevious,
                ),

              // Filters overlay
              if (!_isLocked && _filtersVisible)
                Positioned(
                  bottom: filtersBottom,
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
                        _buildFilterButton("Normal", Colors.white, "normal"),
                        _buildFilterButton("Dark", Colors.black87, "dark"),
                        _buildFilterButton("Blue", HexColor('#0000FF'), "blue"),
                        _buildFilterButton("Warm HDR", Colors.deepOrangeAccent, "warm"),
                        _buildFilterButton("Sepia", Colors.redAccent, "sepia"),
                        _buildFilterButton("Neon", Colors.purpleAccent, "neon"),
                      ],
                    ),
                  ),
                ),

              // Equalizer overlay
              if (!_isLocked && _equalizerVisible)
                Positioned(
                  bottom: equalizerBottom,
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
                        _buildSlider("Bass (60Hz)", bassGain, (v) => setState(() => bassGain = v)),
                        _buildSlider("Mid (1kHz)", midGain, (v) => setState(() => midGain = v)),
                        _buildSlider("Treble (10kHz)", trebleGain, (v) => setState(() => trebleGain = v)),
                      ],
                    ),
                  ),
                ),

              // Logo overlay at end
              if (_showLogo && isLast)
                AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/appblue.png', width: 120, height: 120),
                        const SizedBox(height: 16),
                        const Text(
                          'Vidnexa Player',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Left side controls
              Positioned(
                top: sideControlsTop,
                left: 0,
                child: Column(
                  children: [
                    IconButton(
                      icon: Icon(_isLocked ? Icons.lock : Icons.lock_open),
                      color: _isLocked ? Colors.green : Colors.white,
                      iconSize: 32,
                      onPressed: _toggleLock,
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt),
                      color: Colors.white,
                      iconSize: 28,
                      onPressed: _isLocked ? null : _takeScreenshot,
                    ),
                    IconButton(
                      icon: const Icon(Icons.headphones),
                      color: _audioOnly ? Colors.greenAccent : Colors.white,
                      iconSize: 28,
                      onPressed: _isLocked ? null : _toggleAudioOnly,
                    ),
                  ],
                ),
              ),

              // Right side controls including PiP
              Positioned(
                top: sideControlsTop,
                right: 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.equalizer),
                      color: Colors.white,
                      iconSize: 28,
                      onPressed: _isLocked ? null : _toggleEqualizer,
                    ),
                    IconButton(
                      icon: const Icon(Icons.filter_alt),
                      color: Colors.white,
                      iconSize: 28,
                      onPressed: _isLocked ? null : _toggleFilters,
                    ),
                    GestureDetector(
                      onTap: _isLocked ? null : _cyclePlaybackRate,
                      child: Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_playbackRate.toStringAsFixed(1)}x',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.screen_rotation),
                      color: Colors.white,
                      iconSize: 28,
                      onPressed: _isLocked ? null : _toggleOrientation,
                    ),
                    // Picture-in-picture button: show overlay and close page
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt),
                      color: Colors.white,
                      iconSize: 28,
                      onPressed: _isLocked
                          ? null
                          : () {
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
        ),
      ),
    );
  }
}