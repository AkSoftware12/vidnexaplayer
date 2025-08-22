import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../Utils/color.dart';
import '../video_player.dart';

class AllVideosScreen extends StatefulWidget {
  const AllVideosScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<AllVideosScreen> {
  List<File> allVideos = [];
  bool isLoading = true;
  String errorMessage = '';
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    List<File> videos = await getAllVideos();
    setState(() {
      allVideos = videos;
      isLoading = false;
      errorMessage = videos.isEmpty ? 'No videos found on this device.' : '';
    });
  }

  Future<List<File>> getAllVideos() async {
    List<File> videoFiles = [];
    List<String> videoExtensions = ['.mp4', '.mkv', '.mov', '.avi', '.wmv'];

    // Define common video directories to scan
    List<String> directoriesToScan = [
      '/storage/emulated/0/DCIM',
      '/storage/emulated/0/Movies',
      '/storage/emulated/0/Videos',
      '/storage/emulated/0/Download',
    ];

    for (String dirPath in directoriesToScan) {
      Directory? directory = Directory(dirPath);
      if (await directory.exists()) {
        try {
          await for (var entity
              in directory.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              String extension = path.extension(entity.path).toLowerCase();
              if (videoExtensions.contains(extension)) {
                print('Found video: ${entity.path}');
                videoFiles.add(entity);
              }
            }
          }
        } catch (e) {
          print('Error scanning directory $dirPath: $e');
          continue; // Continue with the next directory
        }
      } else {
        print('Directory does not exist: $dirPath');
      }
    }

    // Optionally, sort videos by name or date
    videoFiles
        .sort((a, b) => path.basename(a.path).compareTo(path.basename(b.path)));

    print('Total videos found: ${videoFiles.length}');
    return videoFiles;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Videos',
          style: TextStyle(
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isGridView
                          ? ColorSelect.maineColor
                          : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !_isGridView
                          ? ColorSelect.maineColor
                          : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
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
      body: isLoading
          ? Center(
              child: CupertinoActivityIndicator(
              radius: 25,
              color: ColorSelect.maineColor,
              animating: true,
            ))
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : AllVideos(
                  gridView: _isGridView,
                  videos: allVideos,
                ),
    );
  }
}

class AllVideos extends StatefulWidget {
  final bool gridView;
  final List<File> videos;

  const AllVideos({
    super.key,
    required this.gridView,
    required this.videos,
  });

  @override
  _VideoFolderScreenState createState() => _VideoFolderScreenState();
}

class _VideoFolderScreenState extends State<AllVideos> {
  final Map<String, String?> _thumbnailCache = {};
  final Map<String, Duration?> _durationCache = {};

  Future<String?> _getVideoThumbnail(String videoPath) async {
    if (_thumbnailCache.containsKey(videoPath)) {
      return _thumbnailCache[videoPath];
    }

    final thumbnailPath = await VideoThumbnail.thumbnailFile(
      video: videoPath,
      imageFormat: ImageFormat.PNG,
      maxHeight: 720,
      quality: 75,
    );

    _thumbnailCache[videoPath] = thumbnailPath;
    return thumbnailPath;
  }

  Future<Duration?> _getVideoDuration(String videoPath) async {
    if (_durationCache.containsKey(videoPath)) {
      return _durationCache[videoPath];
    }

    final controller = VideoPlayerController.file(File(videoPath));
    await controller.initialize();
    final duration = controller.value.duration;
    await controller.dispose();

    _durationCache[videoPath] = duration;
    return duration;
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '00:00';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: widget.gridView ? _buildGridView() : _buildListView(),
    );
  }

  Widget _buildListView() {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: widget.videos.length,
        itemBuilder: (context, index) {
          File video = widget.videos[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
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
                    margin:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 5.sp, vertical: 5.sp),
                      child: Row(
                        children: [
                          FutureBuilder<String?>(
                            future: _getVideoThumbnail(video.path),
                            builder: (context, snapshot) {
                              return snapshot.hasData && snapshot.data != null
                                  ? Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.6),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: FutureBuilder<Duration?>(
                                              future:
                                                  _getVideoDuration(video.path),
                                              builder: (context, snapshot) {
                                                return Text(
                                                  _formatDuration(
                                                      snapshot.data),
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
                                          Icons.play_circle_filled,
                                          size: 30.sp,
                                          color: ColorSelect.maineColor,
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
                                Row(
                                  children: [
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
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert,
                                    color: Colors.black54),
                                onSelected: (value) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Selected: $value'),
                                      backgroundColor: Colors.deepPurple,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Text('Share'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'info',
                                    child: Text('Info'),
                                  ),
                                ],
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
          File video = widget.videos[index];
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 2,
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: GestureDetector(
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
                                          bottom: 2,
                                          left: 3,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: FutureBuilder<Duration?>(
                                              future:
                                                  _getVideoDuration(video.path),
                                              builder: (context, snapshot) {
                                                return Text(
                                                  _formatDuration(
                                                      snapshot.data),
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
                                          bottom: 2,
                                          right: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: ColorSelect.maineColor,
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                  : Center(
                                      child: Icon(
                                        Icons.play_circle_filled,
                                        size: 45.sp,
                                        color: ColorSelect.maineColor,
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
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert,
                                  color: Colors.black54,
                                  size: 20,
                                ),
                                onSelected: (value) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Selected: $value'),
                                      backgroundColor: Colors.deepPurple,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  );
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'share',
                                    child: Text('Share'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'info',
                                    child: Text('Info'),
                                  ),
                                ],
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
