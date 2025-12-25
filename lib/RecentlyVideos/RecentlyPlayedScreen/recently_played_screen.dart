import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../Home/HomeScreen/home_screen.dart';
import '../../Utils/color.dart';
import '../../VideoPLayer/video_player.dart';
import '../RecentlyPlayedManager/recently_played_manager.dart';

class RecentlyPlayedScreen extends StatefulWidget {
  final bool horizontalView;
  final List<String> recentVideos;
  const RecentlyPlayedScreen({super.key, this.horizontalView = false, required this.recentVideos});

  @override
  _RecentlyPlayedScreenState createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  bool isLoading = false;
  String errorMessage = '';
  bool _isGridView = true;
  bool _isHorizontalView = false;

  @override
  void initState() {
    super.initState();
    _isHorizontalView = widget.horizontalView;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: (widget.horizontalView == false)
          ? AppBar(
        title: Text(
          'Recently Played Videos',
          style: GoogleFonts.poppins(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.grey[100],
        elevation: 2,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = true;
                      _isHorizontalView = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isGridView && !_isHorizontalView
                          ? ColorSelect.maineColor
                          : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: Icon(
                      Icons.grid_view,
                      color: _isGridView && !_isHorizontalView
                          ? Colors.white
                          : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = false;
                      _isHorizontalView = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !_isGridView && !_isHorizontalView
                          ? ColorSelect.maineColor
                          : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Icon(
                      Icons.list,
                      color: !_isGridView && !_isHorizontalView
                          ? Colors.white
                          : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      )
          : null,
      body: isLoading
          ? Center(
        child: CupertinoActivityIndicator(
          radius: 25,
          color: ColorSelect.maineColor,
          animating: true,
        ),
      )
          : errorMessage.isNotEmpty
          ? Center(
        child: Text(
          errorMessage,
          style: GoogleFonts.poppins(
            fontSize: 16.sp,
            color: Colors.grey,
          ),
        ),
      )
          : RecentlyPlayedVideos(
        gridView: _isGridView,
        horizontalView: _isHorizontalView,
        videos: widget.recentVideos,
      ),
    );
  }
}

class RecentlyPlayedVideos extends StatefulWidget {
  final bool gridView;
  final bool horizontalView;
  final List<String> videos;

  const RecentlyPlayedVideos({
    super.key,
    required this.gridView,
    required this.horizontalView,
    required this.videos,
  });

  @override
  _RecentlyPlayedVideosState createState() => _RecentlyPlayedVideosState();
}

class _RecentlyPlayedVideosState extends State<RecentlyPlayedVideos> {
  final Map<String, String?> _thumbnailCache = {};
  final Map<String, Duration?> _durationCache = {};

  Future<String?> _getVideoThumbnail(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 720,
        quality: 75,
      );

      _thumbnailCache[videoPath] = thumbnailPath;
      return thumbnailPath;
    } catch (e) {
      print('Error generating thumbnail for $videoPath: $e');
      _thumbnailCache[videoPath] = null;
      return null;
    }
  }

  Future<Duration?> _getVideoDuration(String videoPath) async {
    if (_durationCache.containsKey(videoPath)) {
      return _durationCache[videoPath];
    }

    try {
      if (!videoPath.startsWith('http')) {
        final controller = VideoPlayerController.file(File(videoPath));
        await controller.initialize();
        final duration = controller.value.duration;
        await controller.dispose();
        _durationCache[videoPath] = duration;
        return duration;
      }
      return null;
    } catch (e) {
      print('Error getting duration for $videoPath: $e');
      return null;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _deleteVideo(String videoPath, int index) async {
    if (videoPath.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete network videos'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Video', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete "${path.basename(videoPath)}"?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // await File(videoPath).delete();
        await RecentlyPlayedManager.removeVideo(videoPath);
        setState(() {
          widget.videos.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video deleted successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting video: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }


  Future<void> _shareVideo(String videoPath, int index) async {
    try {
      // Check if the video is a URL or local file
      if (videoPath.startsWith('http')) {
        // Share network video URL
        await Share.share(
          'Check out this video: $videoPath',
          subject: 'Shared Video: ${path.basename(videoPath)}',
        );

      } else {
        // Share local video file
        final file = File(videoPath);

        // Check if file exists and is valid
        if (!await file.exists() || await file.length() == 0) {
          throw Exception('Video file not found or empty');
        }

        // Check file size (WhatsApp video limit: 100 MB)
        final fileSize = await file.length();
        const maxVideoSize = 100 * 1024 * 1024; // 100 MB
        if (fileSize > maxVideoSize) {
          throw Exception('Video exceeds WhatsApp size limit (100 MB). Try compressing it.');
        }

        // Check file format
        const supportedFormats = ['mp4', 'avi', 'mkv', '3gp', 'mov'];
        final extension = path.extension(videoPath).toLowerCase().replaceFirst('.', '');
        if (!supportedFormats.contains(extension)) {
          throw Exception('Unsupported video format: $extension. Convert to MP4 or similar.');
        }

        // Prepare files to share (video only, excluding thumbnail for simplicity)
        final shareFiles = <XFile>[XFile(videoPath, mimeType: 'video/$extension')];

        // Share the video
        await Share.shareXFiles(
          shareFiles,
          // text: 'Check out this video: ${path.basename(videoPath)}',
          // subject: 'Shared Video',
        );

        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text('Video shared successfully'),
        //     backgroundColor: Colors.green,
        //     behavior: SnackBarBehavior.floating,
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(8),
        //     ),
        //   ),
        // );
      }
    } catch (e, stackTrace) {
      // Log error for debugging
      print('Error sharing video: $e\nStackTrace: $stackTrace');

    }
  }
  Future<void> _showVideoInfo(String videoPath) async {
    if (videoPath.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Info not available for network videos',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

    final file = File(videoPath);
    final stats = await file.stat();
    final duration = await _getVideoDuration(videoPath);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.video_file, color: ColorSelect.maineColor, size: 30),
              SizedBox(width: 8),
              Text(
                'Video Info',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: ColorSelect.maineColor,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Name', path.basename(videoPath)),
              SizedBox(height: 12),
              _buildInfoRow('Path', videoPath),
              SizedBox(height: 12),
              _buildInfoRow('Size', '${(stats.size / (1024 * 1024)).toStringAsFixed(2)} MB'),
              SizedBox(height: 12),
              _buildInfoRow('Duration', _formatDuration(duration)),
              SizedBox(height: 12),
              _buildInfoRow('Last Modified', stats.modified.toString().split('.')[0]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: ColorSelect.maineColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w400,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.horizontalView ? Colors.white : Colors.grey[100],
      body: widget.horizontalView
          ? _buildHorizontalView()
          : widget.gridView
          ? _buildGridView()
          : _buildListView(),
    );
  }

  Widget _buildHorizontalView() {
    return SizedBox(
      height: 130.sp,
      child: AnimationLimiter(
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.all(5.sp),
          itemCount: widget.videos.length,
          itemBuilder: (context, index) {
            final videoPath = widget.videos[index];
            final isNetwork = videoPath.startsWith('http');
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                horizontalOffset: 0.0,
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () {

                      // ✅ Video play करने पर recently played update करें
                      Provider.of<VideoProvider>(context, listen: false)
                          .addToRecentlyPlayed(videoPath);
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => VideoPlayerScreen(
                      //       videos: widget.videos
                      //           .where((path) => !path.startsWith('http'))
                      //           .map((path) => File(path))
                      //           .toList(),
                      //       initialIndex: index,
                      //     ),
                      //   ),
                      // );
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      margin: EdgeInsets.symmetric(horizontal: 0.sp),
                      child: Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.sp),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: FutureBuilder<String?>(
                                future: _getVideoThumbnail(videoPath),
                                builder: (context, snapshot) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.all(Radius.circular(10.sp)),
                                        child: snapshot.hasData && snapshot.data != null
                                            ? Image.file(
                                          File(snapshot.data!),
                                          width: double.infinity,
                                          height: 110.sp,
                                          fit: BoxFit.cover,
                                        )
                                            : Container(
                                          width: double.infinity,
                                          height: 110.sp,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.all(Radius.circular(10.sp)),
                                            image: DecorationImage(
                                              image: AssetImage('assets/video_thumbnail.jpg'),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.play_circle_filled,
                                        size: 30.sp,
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                      if (!isNetwork)
                                        Positioned(
                                          bottom: 2,
                                          left: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: FutureBuilder<Duration?>(
                                              future: _getVideoDuration(videoPath),
                                              builder: (context, snapshot) {
                                                return Text(
                                                  _formatDuration(snapshot.data),
                                                  style: TextStyle(
                                                    fontSize: 9.sp,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            SizedBox(
                              height: 25.sp,
                              child: Row(
                                children: [
                                  SizedBox(width: 5.sp),
                                  Expanded(
                                    child: Text(
                                      path.basename(videoPath),
                                      style: GoogleFonts.poppins(
                                        fontSize: 8.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTapDown: (details) {
                                      showMenu(
                                        context: context,
                                        position: RelativeRect.fromLTRB(
                                          details.globalPosition.dx,
                                          details.globalPosition.dy,
                                          MediaQuery.of(context).size.width - details.globalPosition.dx,
                                          MediaQuery.of(context).size.height,
                                        ),
                                        items: [
                                          PopupMenuItem(
                                            value: "Play",
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.play_circle, size: 20.sp, color: ColorSelect.maineColor),
                                                SizedBox(width: 8),
                                                Text("Play", style: GoogleFonts.poppins()),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: "delete",
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.delete, size: 20.sp, color: Colors.red),
                                                SizedBox(width: 8),
                                                Text("Delete", style: GoogleFonts.poppins()),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: "info",
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,

                                              children: [
                                                Icon(Icons.info, size: 20.sp, color: Colors.blue),
                                                SizedBox(width: 8),
                                                Text("Info", style: GoogleFonts.poppins()),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: "share",
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.share, size: 20.sp, color: Colors.black54),
                                                SizedBox(width: 8),
                                                Text("Share", style: GoogleFonts.poppins()),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ).then((value) {
                                        if (value == "share") {
                                          _shareVideo(videoPath, index);
                                        } else if (value == "delete") {
                                          _deleteVideo(videoPath, index);
                                        } else if (value == "info") {
                                          _showVideoInfo(videoPath);
                                        } else if (value == "Play") {
                                          // Navigator.push(
                                          //   context,
                                          //   MaterialPageRoute(
                                          //     builder: (context) => VideoPlayerScreen(
                                          //       videos: widget.videos
                                          //           .where((path) => !path.startsWith('http'))
                                          //           .map((path) => File(path))
                                          //           .toList(),
                                          //       initialIndex: index,
                                          //     ),
                                          //   ),
                                          // );
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom:0.sp),
                                      child: SizedBox(
                                        height: 30.sp,
                                        width: 30.sp,
                                        child: Center(
                                          child: Icon(
                                            Icons.more_vert,
                                            color: Colors.black,
                                            size: 15.sp,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildListView() {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          final videoPath = widget.videos[index];
          final isNetwork = videoPath.startsWith('http');
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
                  onTap: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => VideoPlayerScreen(
                    //       videos: widget.videos
                    //           .where((path) => !path.startsWith('http'))
                    //           .map((path) => File(path))
                    //           .toList(),
                    //       initialIndex: index,
                    //     ),
                    //   ),
                    // );
                  },
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5.sp, vertical: 5.sp),
                      child: Row(
                        children: [
                          FutureBuilder<String?>(
                            future: _getVideoThumbnail(videoPath),
                            builder: (context, snapshot) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: snapshot.hasData && snapshot.data != null
                                        ? Image.file(
                                      File(snapshot.data!),
                                      width: 100.sp,
                                      height: 60.sp,
                                      fit: BoxFit.cover,
                                    )
                                        : Container(
                                      width: 100.sp,
                                      height: 60.sp,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: AssetImage('assets/video_thumbnail.jpg'),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.play_circle_filled,
                                    size: 30.sp,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  if (!isNetwork)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: FutureBuilder<Duration?>(
                                          future: _getVideoDuration(videoPath),
                                          builder: (context, snapshot) {
                                            return Text(
                                              _formatDuration(snapshot.data),
                                              style: TextStyle(
                                                fontSize: 10.sp,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          SizedBox(width: 10.sp),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  path.basename(videoPath),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 5.sp),
                                if (!isNetwork)
                                  Row(
                                    children: [
                                      Text(
                                        '${(File(videoPath).lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10.sp,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTapDown: (details) {
                                  showMenu(
                                    context: context,
                                    position: RelativeRect.fromLTRB(
                                      details.globalPosition.dx,
                                      details.globalPosition.dy,
                                      MediaQuery.of(context).size.width - details.globalPosition.dx,
                                      MediaQuery.of(context).size.height,
                                    ),
                                    items: [
                                      PopupMenuItem(
                                        value: "Play",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_circle, size: 20.sp, color: ColorSelect.maineColor),
                                            SizedBox(width: 8),
                                            Text("Play", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: "delete",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete, size: 20.sp, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text("Delete", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: "info",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,

                                          children: [
                                            Icon(Icons.info, size: 20.sp, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text("Info", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: "share",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.share, size: 20.sp, color: Colors.black54),
                                            SizedBox(width: 8),
                                            Text("Share", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ).then((value) {
                                    if (value == "share") {
                                      _shareVideo(videoPath, index);
                                    } else if (value == "delete") {
                                      _deleteVideo(videoPath, index);
                                    } else if (value == "info") {
                                      _showVideoInfo(videoPath);
                                    } else if (value == "Play") {
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute(
                                      //     builder: (context) => VideoPlayerScreen(
                                      //       videos: widget.videos
                                      //           .where((path) => !path.startsWith('http'))
                                      //           .map((path) => File(path))
                                      //           .toList(),
                                      //       initialIndex: index,
                                      //     ),
                                      //   ),
                                      // );
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(bottom:0.sp),
                                  child: SizedBox(
                                    height: 30.sp,
                                    width: 30.sp,
                                    child: Center(
                                      child: Icon(
                                        Icons.more_vert,
                                        color: Colors.black,
                                        size: 15.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridView() {
    return AnimationLimiter(
      child: GridView.builder(
        padding: EdgeInsets.all(5.sp),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
        ),
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          final videoPath = widget.videos[index];
          final isNetwork = videoPath.startsWith('http');
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
                  onTap: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => VideoPlayerScreen(
                    //       videos: widget.videos
                    //           .where((path) => !path.startsWith('http'))
                    //           .map((path) => File(path))
                    //           .toList(),
                    //       initialIndex: index,
                    //     ),
                    //   ),
                    // );
                  },
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5.sp),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FutureBuilder<String?>(
                            future: _getVideoThumbnail(videoPath),
                            builder: (context, snapshot) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(5.sp)),
                                    child: snapshot.hasData && snapshot.data != null
                                        ? Image.file(
                                      File(snapshot.data!),
                                      width: double.infinity,
                                      height: 160.sp,
                                      fit: BoxFit.cover,
                                    )
                                        : Container(
                                      width: double.infinity,
                                      height: 160.sp,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(5.sp)),
                                        image: DecorationImage(
                                          image: AssetImage('assets/video_thumbnail.jpg'),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.play_circle_filled,
                                    size: 45.sp,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                  if (!isNetwork)
                                    Positioned(
                                      bottom: 2,
                                      left: 3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                        ),
                                        child: FutureBuilder<Duration?>(
                                          future: _getVideoDuration(videoPath),
                                          builder: (context, snapshot) {
                                            return Text(
                                              _formatDuration(snapshot.data),
                                              style: TextStyle(
                                                fontSize: 9.sp,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  if (!isNetwork)
                                    Positioned(
                                      bottom: 2,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ColorSelect.maineColor,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${(File(videoPath).lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        SizedBox(
                          height: 30.sp,
                          child: Row(
                            children: [
                              SizedBox(width: 5.sp),
                              Expanded(
                                child: Text(
                                  path.basename(videoPath),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTapDown: (details) {
                                  showMenu(
                                    context: context,
                                    position: RelativeRect.fromLTRB(
                                      details.globalPosition.dx,
                                      details.globalPosition.dy,
                                      MediaQuery.of(context).size.width - details.globalPosition.dx,
                                      MediaQuery.of(context).size.height,
                                    ),
                                    items: [
                                      PopupMenuItem(
                                        value: "Play",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_circle, size: 20.sp, color: ColorSelect.maineColor),
                                            SizedBox(width: 8),
                                            Text("Play", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: "delete",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.delete, size: 20.sp, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text("Delete", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: "info",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,

                                          children: [
                                            Icon(Icons.info, size: 20.sp, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text("Info", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: "share",
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.share, size: 20.sp, color: Colors.black54),
                                            SizedBox(width: 8),
                                            Text("Share", style: GoogleFonts.poppins()),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ).then((value) {
                                    if (value == "share") {
                                      _shareVideo(videoPath, index);
                                    } else if (value == "delete") {
                                      _deleteVideo(videoPath, index);
                                    } else if (value == "info") {
                                      _showVideoInfo(videoPath);
                                    } else if (value == "Play") {
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute(
                                      //     builder: (context) => VideoPlayerScreen(
                                      //       videos: widget.videos
                                      //           .where((path) => !path.startsWith('http'))
                                      //           .map((path) => File(path))
                                      //           .toList(),
                                      //       initialIndex: index,
                                      //     ),
                                      //   ),
                                      // );
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: EdgeInsets.only(bottom:0.sp),
                                  child: SizedBox(
                                    height: 30.sp,
                                    width: 30.sp,
                                    child: Center(
                                      child: Icon(
                                        Icons.more_vert,
                                        color: Colors.black,
                                        size: 15.sp,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}