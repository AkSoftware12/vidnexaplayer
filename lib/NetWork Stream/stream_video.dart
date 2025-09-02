import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videoplayer/Utils/color.dart';

import '../VideoPLayer/video_player.dart';

class VideoPlayerStream extends StatefulWidget {
  const VideoPlayerStream({super.key});

  @override
  _VideoPlayerStreamState createState() => _VideoPlayerStreamState();
}

class _VideoPlayerStreamState extends State<VideoPlayerStream> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _loadVideo() {
    if (_urlController.text.isEmpty) {
      _showSnackBar('Please enter a valid URL');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Navigate to the video player screen with the URL
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(videos: [], initialIndex: 0,url: _urlController.text,),
      ),
    ).then((_) {
      setState(() {
        _isLoading = false;
      });
    });
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
    );
  }
}