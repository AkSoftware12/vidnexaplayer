import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';


// ============================================================
// 🎛 Custom Video Controls
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
                            icon: Icon(_isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_fill),
                            color: Colors.white,
                            iconSize: 50,
                            onPressed: _togglePlayPause,
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
// 🎬 FullScreenVideoPlayer with Filters + Equalizer
// ============================================================
class FullScreenVideoPlayer extends StatefulWidget {
  final List<AssetEntity> videos;
  final int initialIndex;

  const FullScreenVideoPlayer({
    super.key,
    required this.videos,
    required this.initialIndex,
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

  // Equalizer sliders
  double bassGain = 0.0;
  double midGain = 0.0;
  double trebleGain = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _player = Player();
    _controller = VideoController(_player);
    _loadVideo();

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

  // ✅ FIXED Equalizer: never mutes, smooth volume change
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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentIndex == widget.videos.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '${_currentIndex + 1} / ${widget.videos.length}',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
        children: [
          // 🎥 Video with color filter
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(
                _getColorMatrix(_selectedFilter),
              ),
              child: Video(controller: _controller, controls: null),
            ),
          ),

          // 🎛 Controls
          CustomVideoControls(
            player: _player,
            onNext: _playNext,
            onPrevious: _playPrevious,
          ),

          // 🎨 Filters
          Positioned(
            bottom: 120,
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

          // 🎚 Equalizer
          Positioned(
            bottom: 130,
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

          // 🖼 Logo overlay on last video
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
        ],
      ),
    );
  }
}
