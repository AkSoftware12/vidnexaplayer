import 'package:audio_service/audio_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:photo_manager/photo_manager.dart';

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
  late VideoController _controller;
  bool _isLoading = true;
  bool _isPlaying = true;
  Player? _player;


  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    setState(() => _isLoading = true);
    final file = await widget.videos[_currentIndex].file;
    if (file != null) {
      final player = Player();
      _controller = VideoController(player);
      await player.open(Media(file.path));
      setState(() => _isLoading = false);
      player.play();
      _isPlaying = true;
    }
  }

  Future<void> _playNext() async {
    if (_currentIndex < widget.videos.length - 1) {
      _currentIndex++;
      await _controller.player.stop();
      _loadVideo();
    }
  }

  Future<void> _playPrevious() async {
    if (_currentIndex > 0) {
      _currentIndex--;
      await _controller.player.stop();
      _loadVideo();
    }
  }

  @override
  void dispose() {
    _controller.player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '${_currentIndex + 1}/${widget.videos.length}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: Video(controller: _controller,
              controls:  null, // 👈 Hides slider, duration, zoom, etc.

            ),
          ),
          Positioned.fill(
            child: CustomVideoControls(player:_player),
          ),
        ],
      ),
    );
  }

}


class CustomVideoControls extends StatefulWidget {
  final Player? player;
  const CustomVideoControls({super.key, required this.player});

  @override
  State<CustomVideoControls> createState() => _CustomVideoControlsState();
}

class _CustomVideoControlsState extends State<CustomVideoControls> {
  bool _visible = true;

  @override
  Widget build(BuildContext context) {
    final player = widget.player;

    return GestureDetector(
      onTap: () => setState(() => _visible = !_visible),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ▶️ / ⏸️  Play-Pause button
          AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: StreamBuilder<bool>(
              stream: player?.stream.playing, // ✅ correct stream
              initialData: player?.state.playing,
              builder: (context, snapshot) {
                final isPlaying = snapshot.data ?? false;

                return GestureDetector(
                  onTap: () async {
                    if (isPlaying) {
                      await player?.pause();
                    } else {
                      await player?.play();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                );
              },
            ),
          ),

          // 🔙 Back button
          Positioned(
            top: 25,
            left: 16,
            child: AnimatedOpacity(
              opacity: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),

          // ⏳ Buffering indicator
          StreamBuilder<bool>(
            stream: player?.stream.buffering, // ✅ correct stream
            initialData: player?.state.buffering,
            builder: (context, snapshot) {
              final isBuffering = snapshot.data ?? false;
              return isBuffering
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

