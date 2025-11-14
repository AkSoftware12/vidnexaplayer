import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:videoplayer/Utils/color.dart';

class CustomVideoAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBackPressed;
  final bool isLandscape; // <-- add this
  final List<AssetEntity> videos;
  final int currentIndex; // Currently playing video
  final ValueChanged<int>? onVideoSelected; // Callback to play selected video

  const CustomVideoAppBar({
    required this.title,
    required this.onBackPressed,
    required this.videos,
    this.currentIndex = 0,
    this.onVideoSelected,
    super.key,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // height: isLandscape ? 25.sp : null,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
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
                  fontSize: isLandscape ? 7.sp : 16.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4.sp),
            // CC Button
            // _buildIconButton(
            //   icon: Icons.closed_caption,
            //   onPressed: () => print('CC toggled'),
            //   tooltip: 'Toggle Captions',
            // ),
            // SizedBox(width: 4.sp),
            // // Music Button
            // _buildIconButton(
            //   icon: Icons.music_note,
            //   onPressed: () => print('Music toggled'),
            //   tooltip: 'Toggle Music',
            // ),
            SizedBox(width: 4.sp),
            // Playlist Button
            _buildIconButton(
              icon: Icons.playlist_play_sharp,
              onPressed: () => _showVideoList(context),
              tooltip: 'Playlist',
            ),
            SizedBox(width: 4.sp),
            // // Other Button (optional)
            // _buildIconButton(
            //   icon: Icons.arrow_drop_down_circle_rounded,
            //   onPressed: () => print('Other action'),
            //   tooltip: 'Other',
            // ),
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
    if (videos == null) return;

    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    Widget sheetContent(ScrollController? scrollController) {
      return ClipRRect(
        borderRadius: isLandscape
            ? const BorderRadius.horizontal(left: Radius.circular(24))
            : const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5), // semi-transparent
              borderRadius: isLandscape
                  ? const BorderRadius.horizontal(left: Radius.circular(24))
                  : const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      height: 4,
                      width: 40,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    "Playlist",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        bool isPlaying = index == currentIndex;
                        // String name = videos.path.split('/').last;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isPlaying
                                ? Colors.amber.withOpacity(0.15)
                                : Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isPlaying
                                  ? Colors.amberAccent.withOpacity(0.9)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.pop(context);
                              if (onVideoSelected != null) {
                                onVideoSelected!(index);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    height: 42,
                                    width: 42,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: isPlaying
                                          ? const LinearGradient(
                                        colors: [Colors.amber, Colors.orange],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      )
                                          : const LinearGradient(
                                        colors: [Colors.grey, Colors.white30],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.play_arrow_rounded
                                          : Icons.videocam_rounded,
                                      color: isPlaying
                                          ? Colors.black
                                          : Colors.white.withOpacity(0.9),
                                      size: 26,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Text(
                                          videos[index].title.toString(),
                                          style: TextStyle(
                                            color: isPlaying
                                                ? Colors.amberAccent
                                                : Colors.white70,
                                            fontWeight: isPlaying
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 15,
                                            decoration: TextDecoration.none,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isPlaying)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.amberAccent, width: 1),
                                      ),
                                      child: const Text(
                                        "Playing",
                                        style: TextStyle(
                                          color: Colors.amberAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.none,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isLandscape) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black38,
        pageBuilder: (_, __, ___) {
          return Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.35,
              heightFactor: 1.0,
              child: Material(
                color: Colors.transparent,
                child: sheetContent(ScrollController()),
              ),
            ),
          );
        },
        transitionBuilder: (_, anim, __, child) {
          final curvedAnim = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero)
                .animate(curvedAnim),
            child: FadeTransition(opacity: curvedAnim, child: child),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.4,
            minChildSize: 0.25,
            maxChildSize: 0.9,
            builder: (context, scrollController) =>
                sheetContent(scrollController),
          );
        },
      );
    }
  }
}
