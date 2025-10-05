import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CustomVideoAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBackPressed;

  final List<FileSystemEntity>? videos; // Video list
  final int currentIndex; // Currently playing video
  final ValueChanged<int>? onVideoSelected; // Callback to play selected video

  const CustomVideoAppBar({
    required this.title,
    required this.onBackPressed,
    this.videos,
    this.currentIndex = 0,
    this.onVideoSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90.sp,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.black.withOpacity(0.8),
            Colors.black.withOpacity(0.6),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Row(
          children: [
            // Back Button
            _buildIconButton(
              icon: Icons.arrow_back,
              onPressed: onBackPressed,
              tooltip: 'Back',
            ),
            SizedBox(width: 4.sp),
            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4.sp),
            // CC Button
            _buildIconButton(
              icon: Icons.closed_caption,
              onPressed: () => print('CC toggled'),
              tooltip: 'Toggle Captions',
            ),
            SizedBox(width: 4.sp),
            // Music Button
            _buildIconButton(
              icon: Icons.music_note,
              onPressed: () => print('Music toggled'),
              tooltip: 'Toggle Music',
            ),
            SizedBox(width: 4.sp),
            // Playlist Button
            _buildIconButton(
              icon: Icons.playlist_play_sharp,
              onPressed: () => _showVideoList(context),
              tooltip: 'Playlist',
            ),
            SizedBox(width: 4.sp),
            // Other Button (optional)
            _buildIconButton(
              icon: Icons.arrow_drop_down_circle_rounded,
              onPressed: () => print('Other action'),
              tooltip: 'Other',
            ),
          ],
        ),
      ),
    );
  }

  // Reusable IconButton
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.1),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  // Modern playlist bottom sheet
  void _showVideoList(BuildContext context) {
    if (videos == null || videos!.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Playlist',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: videos!.length,
                      itemBuilder: (context, index) {
                        bool isPlaying = index == currentIndex;
                        String name = videos![index].path.split('/').last;
                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Close bottom sheet
                            if (onVideoSelected != null) {
                              onVideoSelected!(index); // Play selected video
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isPlaying
                                  ? Colors.amber.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: isPlaying
                                  ? Border.all(color: Colors.amber, width: 1.5)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isPlaying ? Icons.play_circle_fill : Icons.videocam,
                                  color: isPlaying ? Colors.amber : Colors.white,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: isPlaying ? Colors.amber : Colors.white,
                                      fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 14.sp,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
