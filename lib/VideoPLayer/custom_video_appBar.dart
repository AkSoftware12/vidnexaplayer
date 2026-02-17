import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';

class CustomVideoAppBar extends StatelessWidget {
  final String title;
  final VoidCallback onBackPressed;
  final VoidCallback onBackPressedMore;
  final bool isLandscape;
  final List<AssetEntity> videos;
  final int currentIndex;
  final ValueChanged<int>? onVideoSelected;

  const CustomVideoAppBar({
    super.key,
    required this.title,
    required this.onBackPressed,
    required this.videos,
    required this.isLandscape,
    this.currentIndex = 0,
    this.onVideoSelected,
    required this.onBackPressedMore,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final barH = isLandscape ? 46.h : 45.h;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: EdgeInsets.only(left: 10.w, right: 10.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.72),
                Colors.black.withOpacity(0.28),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
            ),
          ),
          child: SizedBox(
            height: barH,
            child: Row(
              children: [
                _glassIcon(
                  icon: Icons.arrow_back_rounded,
                  tooltip: "Back",
                  onTap: onBackPressed,
                  size: isLandscape ? 34 : 40,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isLandscape ? 5.sp : 12.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        "${currentIndex + 1}/${videos.length} • Playlist",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: isLandscape ? 4.sp : 11.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                _glassIcon(
                  icon: Icons.playlist_play_rounded,
                  tooltip: "Playlist",
                  onTap: () => _showVideoList(context),
                  size: isLandscape ? 34 : 40,
                ),
                SizedBox(width: 10.w),
                _glassIcon(
                  icon: Icons.more_vert,
                  tooltip: "All Item",
                  onTap:onBackPressedMore,
                  size: isLandscape ? 34 : 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required double size,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: size,
              width: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                border: Border.all(color: Colors.white.withOpacity(0.10)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Icon(icon, color: Colors.white, size: size * 0.55),
            ),
          ),
        ),
      ),
    );
  }

  void _showVideoList(BuildContext context) {
    final media = MediaQuery.of(context);
    final isLand = media.orientation == Orientation.landscape;

    if (isLand) {
      final panelWidth = (media.size.width * 0.40).clamp(320.0, 560.0);

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: '',
        barrierColor: Colors.black.withOpacity(0.35),
        pageBuilder: (_, __, ___) {
          return Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: panelWidth,
              height: media.size.height,
              child: Material(
                color: Colors.transparent,
                child: _PlaylistPanel(
                  videos: videos,
                  initialIndex: currentIndex, // ✅ pass initial index
                  onVideoSelected: onVideoSelected,
                  isLandscape: true,
                  scrollController: ScrollController(),
                ),
              ),
            ),
          );
        },
        transitionBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
          return SlideTransition(
            position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
            child: FadeTransition(opacity: curved, child: child),
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.42,
            minChildSize: 0.30,
            maxChildSize: 0.92,
            builder: (ctx, controller) {
              return _PlaylistPanel(
                videos: videos,
                initialIndex: currentIndex, // ✅ pass initial index
                onVideoSelected: onVideoSelected,
                isLandscape: false,
                scrollController: controller,
              );
            },
          );
        },
      );
    }
  }
}

// ✅ CHANGED: Stateful so list updates on tap
class _PlaylistPanel extends StatefulWidget {
  final List<AssetEntity> videos;
  final int initialIndex;
  final ValueChanged<int>? onVideoSelected;
  final bool isLandscape;
  final ScrollController scrollController;

  const _PlaylistPanel({
    required this.videos,
    required this.initialIndex,
    required this.onVideoSelected,
    required this.isLandscape,
    required this.scrollController,
  });

  @override
  State<_PlaylistPanel> createState() => _PlaylistPanelState();
}

class _PlaylistPanelState extends State<_PlaylistPanel> {
  late int playingIndex;

  @override
  void initState() {
    super.initState();
    playingIndex = widget.initialIndex; // ✅ local state
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final topPad = media.padding.top;
    final bottomPad = media.padding.bottom;

    return ClipRRect(
      borderRadius: widget.isLandscape
          ? const BorderRadius.horizontal(left: Radius.circular(24))
          : const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: media.size.height,
          padding: EdgeInsets.only(
            top: widget.isLandscape ? topPad : 0,
            bottom: bottomPad,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.74),
                Colors.black.withOpacity(0.56),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: SafeArea(
            top: !widget.isLandscape,
            bottom: !widget.isLandscape,
            child: Column(
              children: [
                SizedBox(height: 10.h),

                if (!widget.isLandscape)
                  Container(
                    height: 4,
                    width: 42,
                    margin: EdgeInsets.only(bottom: 12.h),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  child: Row(
                    children: [
                      Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB703), Color(0xFFFF6A00)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.22),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            )
                          ],
                        ),
                        child: const Icon(Icons.playlist_play_rounded,
                            color: Colors.black, size: 24),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Playlist",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                decoration: TextDecoration.none,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              "${playingIndex + 1}/${widget.videos.length} playing", // ✅ updated
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          height: 38,
                          width: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                        ),
                      )
                    ],
                  ),
                ),

                SizedBox(height: 10.h),

                Expanded(
                  child: ListView.builder(
                    controller: widget.scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 8.h, left: 5.w, right: 5.w),
                    itemCount: widget.videos.length,
                    itemBuilder: (context, index) {
                      final item = widget.videos[index];
                      final isPlaying = index == playingIndex;

                      return _PlaylistTileNoThumb(
                        entity: item,
                        isPlaying: isPlaying,
                        onTap: () {
                          setState(() => playingIndex = index); // ✅ UI update instantly
                          widget.onVideoSelected?.call(index);
                        },
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
}

class _PlaylistTileNoThumb extends StatelessWidget {
  final AssetEntity entity;
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlaylistTileNoThumb({
    required this.entity,
    required this.isPlaying,
    required this.onTap,
  });

  String _formatDuration(Duration d) {
    final total = d.inSeconds;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;

    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return "${two(h)}:${two(m)}:${two(s)}";
    return "${two(m)}:${two(s)}";
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.symmetric(vertical: 6.h),
      decoration: BoxDecoration(
        color: isPlaying ? Colors.orange.withOpacity(0.13) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: isPlaying ? Colors.orangeAccent.withOpacity(0.95) : Colors.white.withOpacity(0.06),
          width: 1.2,
        ),
        boxShadow: [
          if (isPlaying)
            BoxShadow(
              color: Colors.orange.withOpacity(0.22),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 5.h),
          child: Row(
            children: [
              Container(
                height: 35,
                width: 35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isPlaying
                      ? const LinearGradient(
                    colors: [Color(0xFFFFB703), Color(0xFFFF6A00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : LinearGradient(
                    colors: [Colors.white.withOpacity(0.12), Colors.white.withOpacity(0.06)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Icon(
                  isPlaying ? Icons.play_arrow_rounded : Icons.videocam_rounded,
                  color: isPlaying ? Colors.black : Colors.white.withOpacity(0.85),
                  size: 26,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.title.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isPlaying ? Colors.orangeAccent : Colors.white.withOpacity(0.88),
                        fontWeight: isPlaying ? FontWeight.w800 : FontWeight.w700,
                        fontSize: 13.5,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatDuration(entity.videoDuration),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 5.w),
              if (isPlaying)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFB703), Color(0xFFFF6A00)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    "PLAYING",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      decoration: TextDecoration.none,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white.withOpacity(0.55),
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
