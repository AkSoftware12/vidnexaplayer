import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path/path.dart' as path;

import '../../Utils/color.dart';
import '../4kPlayer/4k_player.dart';
import '../video_player.dart';

class VideoFolderScreen extends StatefulWidget {
  final String folderName;
  final AssetPathEntity videos;

  const VideoFolderScreen({
    super.key,
    required this.folderName,
    required this.videos,
  });

  @override
  _VideoFolderScreenState createState() => _VideoFolderScreenState();
}

class _VideoFolderScreenState extends State<VideoFolderScreen>
    with SingleTickerProviderStateMixin {
  bool _isGridView = false;

  List<AssetEntity> _photos = [];
  bool _isLoading = true;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _loadPhotos();
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  Future<void> _loadPhotos() async {
    final List<AssetEntity> photos = await widget.videos.getAssetListRange(
      start: 0,
      end: 1000,
    );
    setState(() {
      _photos = photos;
      _isLoading = false;
      _controller.forward();
    });
  }

  Future<void> _onPhotoDeleted(BuildContext context, String videoPath) async {
    try {
      // 🧹 Delete the video file
      await deleteVideoFromDevice(context, videoPath);

      // 🔄 Reload the photos list after deletion
      await _loadPhotos();

      // 🪄 Refresh UI
      setState(() {});

      // ✅ Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🗑️ Video deleted successfully')),
      );
    } catch (e) {
      // ⚠️ Handle any error gracefully
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to delete video: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:  EdgeInsets.only(bottom:50.sp),
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            '${widget.folderName} ${'(${_photos.length.toString()})'}',
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
                        color: _isGridView ? ColorSelect.maineColor2 : Colors.grey.shade200,
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
                        color: !_isGridView ? ColorSelect.maineColor2 : Colors.grey.shade200,
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
            ),
          ],
        ),
        body: _isGridView ? _buildGridView() : _buildListView(),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return PhotoTile(
          photo: _photos[index],
          photos: _photos,
          initialIndex: index,
          onInfo: () {
            _showVideoInfo(_photos[index]);
          },
          onDelete: () async {
            final file = await _photos[index].file;
            if (file != null) {
              // 🧹 Delete file from storage
              await _onPhotoDeleted(context, file.path);

              // 🪄 Remove it from the list & refresh UI
              setState(() {
                _photos.removeAt(index);
              });

            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Unable to access video file')),
              );
            }
          },
          onShare: () async {
            // Wait for file to load
            final file = await _photos[index].file;
            if (file != null) {
              _shareVideo(context, file.path);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Unable to access video file')),
              );
            }
          },
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
      itemCount: _photos.length,
      itemBuilder: (context, index) {
        return GridviewList(
          photo: _photos[index],
          photos: _photos,
          initialIndex: index,
          onDelete: () async {
            final file = await _photos[index].file;
            if (file != null) {
              // 🧹 Delete file from storage
              await _onPhotoDeleted(context, file.path);

              // 🪄 Remove it from the list & refresh UI
              setState(() {
                _photos.removeAt(index);
              });

            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Unable to access video file')),
              );
            }
          },

          onInfo: () {
            _showVideoInfo(_photos[index]);

          },
          onShare: () async {
            // Wait for file to load
            final file = await _photos[index].file;
            if (file != null) {
              _shareVideo(context, file.path);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('❌ Unable to access video file')),
              );
            }
          },
        );
      },
    );
  }

  Future<void> deleteVideoFromDevice(
    BuildContext context,
    String videoPath,
  ) async {
    // 1️⃣ Permission check
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Permission denied"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2️⃣ Confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text("Delete Video"),
            content: const Text("Are you sure you want to delete this video?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.teal),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Delete",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // 3️⃣ Fetch all video asset paths
    final paths = await PhotoManager.getAssetPathList(type: RequestType.video);

    for (final p in paths) {
      final int total =
          await p.assetCountAsync; // ✅ Correct way to get asset count
      final assets = await p.getAssetListRange(start: 0, end: total);

      for (final asset in assets) {
        final file = await asset.file;
        if (file != null && file.path == videoPath) {
          try {
            final result = await PhotoManager.editor.deleteWithIds([asset.id]);
            if (result.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Video deleted from device"),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Failed to delete video"),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Error deleting video: $e"),
                backgroundColor: Colors.red,
              ),
            );
          }
          return; // Exit once video is deleted
        }
      }
    }
  }

  Future<void> _shareVideo(BuildContext context, String videoPath) async {
    try {

      final file = File(videoPath);
      if (!await file.exists()) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ File not found')),
        );
        return;
      }

      final ext = path.extension(videoPath).replaceFirst('.', '').toLowerCase();
      final shareFile = XFile(videoPath, mimeType: 'video/$ext');

      // small artificial delay (ensure dialog paints)
      await Future.delayed(const Duration(milliseconds: 300));

      await Share.shareXFiles(
        [shareFile],
        text: '🎥 Watch this video: ${path.basename(videoPath)}',
      );

    } catch (e, st) {
      debugPrint('Error sharing: $e\n$st');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to share video')),
      );
    } finally {
      // Navigator.pop(context); // hide loader
    }
  }

  Future<void> _showVideoInfo(AssetEntity photo) async {
    if (photo.file.toString().startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Info not available for network videos',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

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
          content: FutureBuilder<File?>(
            future: photo.file,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return const Text(
                  'File not found',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                );
              }

              final file = snapshot.data!;
              final size = (file.lengthSync() / (1024 * 1024));
              final duration = photo.videoDuration;
              final durationText = _formatDuration(duration);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Name', photo.title ?? 'Unknown'),
                  SizedBox(height: 12),
                  _buildInfoRow('Path', file.path),
                  SizedBox(height: 12),
                  _buildInfoRow('Size', '${size.toStringAsFixed(2)} MB'),
                  SizedBox(height: 12),
                  _buildInfoRow('Duration', durationText),
                  SizedBox(height: 12),
                  _buildInfoRow(
                    'Last Modified',
                    photo.createDateTime?.toString().split('.')[0] ?? 'Unknown',
                  ),
                ],
              );
            },
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
          style: TextStyle(fontWeight: FontWeight.w400, color: Colors.black),
        ),
      ],
    );
  }
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }

}

class PhotoTile extends StatelessWidget {
  final AssetEntity photo;
  final List<AssetEntity> photos;
  final int initialIndex;
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final VoidCallback onShare;

  const PhotoTile({
    super.key,
    required this.photo,
    required this.photos,
    required this.initialIndex,
    required this.onDelete,
    required this.onInfo,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {

        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>  FullScreenVideoPlayer(
                  videos: photos,
                  initialIndex: initialIndex,
                ),

                // VideoPlayerScreen(
                //   videos: photos,
                //   initialIndex: initialIndex,
                // ),
          ),
        );
      },
      child: Card(
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 6.sp, horizontal: 8.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.sp),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.sp, vertical: 6.sp),
          child: Row(
            children: [
              FutureBuilder<Widget>(
                future: _buildThumbnail(context),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      width: 100.sp,
                      height: 70.sp,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10.sp),
                      ),
                      child: const Center(child: CupertinoActivityIndicator()),
                    );
                  }
                  if (snapshot.hasData) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10.sp),
                          child: SizedBox(
                            width: 100.sp,
                            height: 70.sp,
                            child: snapshot.data!,
                          ),
                        ),
                        Icon(
                          Icons.play_circle_fill,
                          color: Colors.white.withOpacity(0.8),
                          size: 28.sp,
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: FutureBuilder<File?>(
                              future: photo.file,
                              builder: (context, snapshot) {
                                // Initialize duration safely
                                Duration? duration;
                                if (snapshot.connectionState == ConnectionState.done &&
                                    snapshot.hasData &&
                                    snapshot.data != null) {
                                  duration = photo.videoDuration;
                                }

                                // If duration is not yet available, show a loading indicator or nothing
                                if (duration == null) {
                                  return const SizedBox.shrink();
                                }

                                return Text(
                                  _formatDuration(duration),
                                  style: GoogleFonts.poppins(
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
                  }
                  return Container(
                    width: 100.sp,
                    height: 70.sp,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10.sp),
                    ),
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.grey,
                      size: 30.sp,
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
                      photo.title ?? 'Untitled',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 5.sp),
                    FutureBuilder<File?>(
                      future: photo.file,
                      builder: (context, snapshot) {
                        double sizeMB = 0;
                        Duration? duration;

                        if (snapshot.hasData && snapshot.data != null) {
                          final file = snapshot.data!;
                          try {
                            if (file.existsSync()) {
                              sizeMB = file.lengthSync() / (1024 * 1024);
                            } else {
                              sizeMB = 0; // File missing, fallback to 0
                            }
                          } catch (e) {
                            // If any unexpected error occurs while reading file
                            debugPrint('Error reading file size: $e');
                            sizeMB = 0;
                          }

                          duration = photo.videoDuration;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sizeMB > 0 ? '${sizeMB.toStringAsFixed(2)} MB' : 'File missing',
                              style: GoogleFonts.poppins(
                                fontSize: 10.sp,
                                color: sizeMB > 0 ? Colors.grey[600] : Colors.redAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            if (duration != null)
                              Text(
                                _formatDuration(duration),
                                style: GoogleFonts.poppins(
                                  fontSize: 10.sp,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        );
                      },
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
                      MediaQuery.of(context).size.width -
                          details.globalPosition.dx,
                      MediaQuery.of(context).size.height,
                    ),
                    items: [
                      _buildMenuItem(Icons.play_circle, "Play", Colors.blue),
                      _buildMenuItem(Icons.delete, "Delete", Colors.red),
                      _buildMenuItem(Icons.info, "Info", Colors.teal),
                      _buildMenuItem(Icons.share, "Share", Colors.black54),
                    ],
                  ).then((value) async {
                    if (value == "Play") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => VideoPlayerScreen(
                                videos: photos,
                                initialIndex: initialIndex,
                              ),
                        ),
                      );
                    } else if (value == "Delete") {
                      onDelete();
                    } else if (value == "Info") {
                      onInfo();
                    } else if (value == "Share") {
                      onShare();

                    }
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(left: 4.sp),
                  child: Icon(
                    Icons.more_vert,
                    color: Colors.black87,
                    size: 18.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds high-quality thumbnail from AssetEntity
  Future<Widget> _buildThumbnail(BuildContext context) async {
    final thumbSize = ThumbnailSize(512, 512);
    final thumbData = await photo.thumbnailDataWithSize(thumbSize, quality: 90);
    if (thumbData == null) {
      return Container(color: Colors.grey.shade300);
    }
    return Image.memory(
      thumbData,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    IconData icon,
    String text,
    Color color,
  ) {
    return PopupMenuItem(
      value: text,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 8),
          Text(text, style: GoogleFonts.poppins(fontSize: 12.sp)),
        ],
      ),
    );
  }



  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }
}

class GridviewList extends StatelessWidget {
  final AssetEntity photo;
  final List<AssetEntity> photos;
  final int initialIndex;
  final VoidCallback onDelete;
  final VoidCallback onInfo;
  final VoidCallback onShare;



  const GridviewList({
    super.key,
    required this.photo,
    required this.photos,
    required this.initialIndex,
    required this.onDelete, required this.onInfo, required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoPlayerScreen(
              videos: photos,
              initialIndex: initialIndex,
            ),
          ),
        );
      },
      child: Card(
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 5.sp, horizontal: 5.sp),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5.sp),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 0.sp, vertical: 0.sp),
          child: Column(
            children: [
              FutureBuilder<Widget>(
                future: _buildThumbnail(context),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      width: double.infinity,
                      height: 100.sp,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(5.sp),
                      ),
                      child: const Center(child: CupertinoActivityIndicator()),
                    );
                  }

                  if (!snapshot.hasData) {
                    return Container(
                      width: double.infinity,
                      height: 100.sp,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(5.sp),
                      ),
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 30.sp,
                      ),
                    );
                  }

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.only(topLeft: Radius.circular(5.sp),topRight: Radius.circular(5.sp)),
                        child: SizedBox(
                          width: double.infinity,
                          height: 140.sp,
                          child: snapshot.data!,
                        ),
                      ),
                      Icon(
                        Icons.play_circle_fill,
                        color: Colors.white.withOpacity(0.8),
                        size: 28.sp,
                      ),
                      // --- Size top right ---
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: FutureBuilder<File?>(
                          future: photo.file,
                          builder: (context, snapshot) {
                            if (snapshot.hasData && snapshot.data != null) {
                              final file = snapshot.data!;
                              double sizeMB = file.lengthSync() / (1024 * 1024);
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: ColorSelect.maineColor2,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${sizeMB.toStringAsFixed(2)} MB',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                      // --- Duration bottom right ---
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
                          child: Text(
                            _formatDuration(photo.videoDuration),
                            style: GoogleFonts.poppins(
                              fontSize: 9.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 5.sp,),
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding:  EdgeInsets.all(5.sp),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            photo.title ?? 'Untitled',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (details) {
                      showMenu(
                        context: context,
                        position: RelativeRect.fromLTRB(
                          details.globalPosition.dx,
                          details.globalPosition.dy,
                          MediaQuery.of(context).size.width -
                              details.globalPosition.dx,
                          MediaQuery.of(context).size.height,
                        ),
                        items: [
                          _buildMenuItem(Icons.play_circle, "Play", Colors.blue),
                          _buildMenuItem(Icons.delete, "Delete", Colors.red),
                          _buildMenuItem(Icons.info, "Info", Colors.teal),
                          _buildMenuItem(Icons.share, "Share", Colors.black54),
                        ],
                      ).then((value) async {
                        if (value == "Play") {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => VideoPlayerScreen(
                                videos: photos,
                                initialIndex: initialIndex,
                              ),
                            ),
                          );
                        } else if (value == "Delete") {
                          onDelete();
                        } else if (value == "Info") {
                          onInfo();
                        } else if (value == "Share") {
                          onShare();
                        }
                      });
                    },
                    child: Padding(
                      padding: EdgeInsets.only(left: 4.sp),
                      child: Icon(
                        Icons.more_vert,
                        color: Colors.black87,
                        size: 18.sp,
                      ),
                    ),
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Widget> _buildThumbnail(BuildContext context) async {
    final thumbSize = ThumbnailSize(512, 512);
    final thumbData = await photo.thumbnailDataWithSize(thumbSize, quality: 90);
    if (thumbData == null) {
      return Container(color: Colors.grey.shade300);
    }
    return Image.memory(
      thumbData,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }

  PopupMenuItem<String> _buildMenuItem(
      IconData icon, String text, Color color) {
    return PopupMenuItem(
      value: text,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(width: 8),
          Text(text, style: GoogleFonts.poppins(fontSize: 12.sp)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "${duration.inHours > 0 ? '${twoDigits(duration.inHours)}:' : ''}$minutes:$seconds";
  }
}

