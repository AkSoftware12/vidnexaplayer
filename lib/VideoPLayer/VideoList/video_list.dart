import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;

import '../../Utils/color.dart';
import '../video_player.dart';

class VideoFolderScreen extends StatefulWidget {
  final String folderName;
  final List<File> videos;

  const VideoFolderScreen({
    super.key,
    required this.folderName,
    required this.videos,
  });

  @override
  _VideoFolderScreenState createState() => _VideoFolderScreenState();
}

class _VideoFolderScreenState extends State<VideoFolderScreen> {
  bool _isGridView = false;
  final Map<String, String?> _thumbnailCache = {};
  final Map<String, Duration?> _durationCache = {};

  @override
  void initState() {
    super.initState();
    _preloadThumbnails(); // Preload thumbnails in the background
    print(widget.videos.length.toString());
  }

  @override
  void dispose() {
    _clearThumbnailCache(); // Clean up thumbnails on widget disposal
    super.dispose();
  }

  // Preload thumbnails to improve performance
  Future<void> _preloadThumbnails() async {
    for (var video in widget.videos) {
      if (!_thumbnailCache.containsKey(video.path)) {
        await _getVideoThumbnail(video.path);
      }
    }
  }

  // Clear cached thumbnails from file system
  Future<void> _clearThumbnailCache() async {
    final tempDir = await getTemporaryDirectory();
    for (var thumbnailPath in _thumbnailCache.values) {
      if (thumbnailPath != null && await File(thumbnailPath).exists()) {
        await File(thumbnailPath).delete();
      }
    }
    _thumbnailCache.clear();
  }

  Future<String?> _getVideoThumbnail(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: tempDir.path, // Save thumbnails in temp directory
        imageFormat: ImageFormat.PNG,
        maxHeight: 720,
        quality: 75,
      );

      _thumbnailCache[videoPath] = thumbnailPath;
      return thumbnailPath;
    } catch (e) {
      print('Error generating thumbnail for $videoPath: $e');
      _thumbnailCache[videoPath] = null; // Cache null to avoid repeated attempts
      return null;
    }
  }

  Future<Duration?> _getVideoDuration(String videoPath) async {
    if (_durationCache.containsKey(videoPath)) {
      return _durationCache[videoPath];
    }

    try {
      final controller = VideoPlayerController.file(File(videoPath));
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();

      _durationCache[videoPath] = duration;
      return duration;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.folderName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
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
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isGridView ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(10),
                        bottomLeft: Radius.circular(10),
                      ),
                    ),
                    child: Icon(
                      Icons.grid_view,
                      color: _isGridView ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = false;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !_isGridView ? Colors.blue : Colors.grey.shade200,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Icon(
                      Icons.list,
                      color: !_isGridView ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
      body: _isGridView ? _buildGridView() : _buildListView(),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        File video = widget.videos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videos: widget.videos,
                  initialIndex: index,
                ),
              ),
            );
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
                    future: _getVideoThumbnail(video.path),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: 100.sp,
                          height: 60.sp,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child:  CupertinoActivityIndicator(
                              radius: 15,
                              color: ColorSelect.maineColor,
                              animating: true,
                            ),
                          ),
                        );
                      }
                      return snapshot.hasData && snapshot.data != null
                          ? Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(snapshot.data!),
                              width: 100.sp,
                              height: 60.sp,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Icon(
                            Icons.play_circle_filled,
                            size: 30.sp,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FutureBuilder<Duration?>(
                                future: _getVideoDuration(video.path),
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
                      )
                          : Container(
                        width: 100.sp,
                        height: 60.sp,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 30.sp,
                            color: Colors.grey,
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(width: 10.sp),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          path.basename(video.path),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 5.sp),
                        Text(
                          '${(video.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                          _shareVideo( video.path, index);
                        } else if (value == "delete") {
                          _deleteVideo(video.path, index,context);
                        } else if (value == "info") {
                          _showVideoInfo(video.path);
                        } else if (value == "Play") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(
                                videos: widget.videos,
                                initialIndex: index,
                              ),
                            ),
                          );
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
          ),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(5.sp),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
      ),
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        File video = widget.videos[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => VideoPlayerScreen(
                  videos: widget.videos,
                  initialIndex: index,
                ),
              ),
            );
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
                    future: _getVideoThumbnail(video.path),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          width: double.infinity,
                          height: 160.sp,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(5.sp),
                            ),
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Colors.blue,
                            ),
                          ),
                        );
                      }
                      return snapshot.hasData && snapshot.data != null
                          ? Stack(
                        alignment: Alignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(5.sp)),
                            child: Image.file(
                              File(snapshot.data!),
                              width: double.infinity,
                              height: 160.sp,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Icon(
                            Icons.play_circle_filled,
                            size: 45.sp,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: FutureBuilder<Duration?>(
                                future: _getVideoDuration(video.path),
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
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${(video.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                          : Container(
                        width: double.infinity,
                        height: 160.sp,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(5.sp),
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 45.sp,
                            color: Colors.grey,
                          ),
                        ),
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
                          path.basename(video.path),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
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
                              _shareVideo( video.path, index);
                            } else if (value == "delete") {
                              _deleteVideo(video.path, index,context);
                            } else if (value == "info") {
                              _showVideoInfo(video.path);
                            } else if (value == "Play") {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VideoPlayerScreen(
                                    videos: widget.videos,
                                    initialIndex: index,
                                  ),
                                ),
                              );
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
        );
      },
    );
  }







  Future<void> _deleteVideo(String videoPath, int index, BuildContext context) async {
    // Check if the video is a network video
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

    // Request appropriate permissions
    bool hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission denied. Cannot delete video.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    // Check if file exists
    final file = File(videoPath);
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Video file not found.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    // Show confirmation dialog
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
        // Delete the file
        await file.delete();

        // Update media store (optional, for Android)
        if (Platform.isAndroid) {
          // Optionally, use a package like `media_scanner` to refresh the media store
          // Example: await MediaScanner.scanFile(videoPath);
        }

        // Update the UI
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
            content: Text('Failed to delete video. Please check permissions or file access.'),
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

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), use granular media permissions
      if (await Permission.videos.isDenied) {
        var status = await Permission.videos.request();
        if (status.isPermanentlyDenied) {
          // Prompt user to enable permission from settings
          await openAppSettings();
          return false;
        }
        if (!status.isGranted) {
          return false;
        }
      }
      // For Android 12 and below, use storage permissions
      if (await Permission.storage.isDenied) {
        var status = await Permission.storage.request();
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        }
        if (!status.isGranted) {
          return false;
        }
      }
    } else if (Platform.isIOS) {
      // For iOS, request photo library access
      var status = await Permission.photos.request();
      if (status.isPermanentlyDenied) {
        await openAppSettings();
        return false;
      }
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
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

}