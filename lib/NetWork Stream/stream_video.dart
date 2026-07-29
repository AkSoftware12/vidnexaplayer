import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videoplayer/Utils/color.dart';

import '../VideoPLayer/4kPlayer/4k_player.dart';
import '../ads/app_open_ad_manager.dart';

class VideoPlayerStream extends StatefulWidget {
  const VideoPlayerStream({super.key});

  @override
  _VideoPlayerStreamState createState() => _VideoPlayerStreamState();
}

class _VideoPlayerStreamState extends State<VideoPlayerStream> {
  final appOpenManager = AppOpenAdManager();

  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  /// Accepts only well-formed absolute http(s)/rtsp/rtmp urls.
  /// Previously any text at all was handed straight to the player.
  static bool _isPlayableUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) return false;
    const allowed = {'http', 'https', 'rtsp', 'rtmp', 'rtmps'};
    return allowed.contains(uri.scheme.toLowerCase());
  }

  Future<void> _loadVideo() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      _showSnackBar('Please enter a video URL');
      return;
    }
    if (!_isPlayableUrl(url)) {
      _showSnackBar('Enter a full URL, e.g. https://example.com/video.mp4');
      return;
    }

    setState(() => _isLoading = true);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayerFixed(
          videos: const [],
          initialUrl: url,
        ),
      ),
    );

    // The user may have popped this screen too while the player was open.
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.black87,
        content: Text(
          message,
          style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 14),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Stream Video',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: ColorSelect.maineColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo[50]!, Colors.blue[50]!],
          ),
        ),
        child: Center(
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Stream Your Video',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.indigo[900],
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: 'Enter Video URL',
                      labelStyle: GoogleFonts.poppins(color: Colors.grey[600]),
                      prefixIcon: const Icon(Icons.link, color: Colors.blueAccent),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    style: GoogleFonts.poppins(fontSize: 16),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 24),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _loadVideo,
                      icon: _isLoading
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.play_arrow, size: 28),
                      label: Text(
                        _isLoading ? 'Loading...' : 'Play Now',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar:appOpenManager.bannerWidget(),

    );
  }
}