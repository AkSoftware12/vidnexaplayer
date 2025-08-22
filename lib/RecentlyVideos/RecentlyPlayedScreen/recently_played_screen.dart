import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as path;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../../Utils/color.dart';
import '../../VideoPLayer/video_player.dart';
import '../RecentlyPlayedManager/recently_played_manager.dart';


class RecentlyPlayedScreen extends StatefulWidget {
  final bool horizontalView;
  final  List<String> recentVideos;
  const RecentlyPlayedScreen({super.key,  this.horizontalView=false, required this.recentVideos});

  @override
  _RecentlyPlayedScreenState createState() => _RecentlyPlayedScreenState();
}

class _RecentlyPlayedScreenState extends State<RecentlyPlayedScreen> {
  // List<String> _recentVideos = [];
  bool isLoading = false;
  String errorMessage = '';
  bool _isGridView = true;
  bool _isHorizontalView =false ;

  @override
  void initState() {
    super.initState();
    _isHorizontalView=widget.horizontalView;
    // _loadRecentVideos();
  }

  // Future<void> _loadRecentVideos() async {
  //   try {
  //     final videos = await RecentlyPlayedManager.getVideos();
  //     setState(() {
  //       _recentVideos = videos;
  //       isLoading = false;
  //       errorMessage = videos.isEmpty ? 'No recently played videos found.' : '';
  //     });
  //   } catch (e) {
  //     setState(() {
  //       isLoading = false;
  //       errorMessage = 'Error loading videos: $e';
  //     });
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:(widget.horizontalView==false)?
    AppBar(
        title: Text(
          'Recently Videos',
          style: GoogleFonts.poppins(
            fontSize: 15.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.grey[100],
        elevation: 2,
        actions: [
          if(widget.horizontalView==false)
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
                if(widget.horizontalView==true)
                  GestureDetector(
                  onTap: () {
                    setState(() {
                      _isGridView = false;
                      _isHorizontalView = true;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isHorizontalView
                          ? ColorSelect.maineColor
                          : Colors.grey.shade200,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                    ),
                    child: Icon(
                      Icons.view_carousel,
                      color: _isHorizontalView ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ):null,
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
      if (!videoPath.startsWith('http')) {
        final thumbnailPath = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          imageFormat: ImageFormat.PNG,
          maxHeight: 720,
          quality: 75,
        );
        _thumbnailCache[videoPath] = thumbnailPath;
        return thumbnailPath;
      }
      return null;
    } catch (e) {
      print('Error generating thumbnail for $videoPath: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:widget.horizontalView? Colors.white:Colors.grey[100],
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
                horizontalOffset: 50.0,
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerScreen(
                            videos: widget.videos
                                .where((path) => !path.startsWith('http'))
                                .map((path) => File(path))
                                .toList(),
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.4,
                      margin: EdgeInsets.symmetric(horizontal: 5.sp),
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
                                        child: snapshot.hasData &&
                                            snapshot.data != null
                                            ? Image.file(
                                          File(snapshot.data!),
                                          width: double.infinity,
                                          // height: 80.sp,
                                          fit: BoxFit.cover,
                                        )
                                            : Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.all(Radius.circular(10.sp)),
                                            image: DecorationImage(
                                              image: AssetImage(
                                                  'assets/video_thumbnail.jpg'),
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
                                              _getVideoDuration(videoPath),
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
                                      // if (!isNetwork)
                                      //   Positioned(
                                      //     bottom: 2,
                                      //     right: 4,
                                      //     child: Container(
                                      //       padding: const EdgeInsets.symmetric(
                                      //           horizontal: 6, vertical: 2),
                                      //       decoration: BoxDecoration(
                                      //         color: ColorSelect.maineColor,
                                      //         borderRadius:
                                      //         BorderRadius.circular(4),
                                      //       ),
                                      //       child: Text(
                                      //         '${(File(videoPath).lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                      //         style: TextStyle(
                                      //           fontSize: 9.sp,
                                      //           color: Colors.white,
                                      //           fontWeight: FontWeight.w600,
                                      //         ),
                                      //       ),
                                      //     ),
                                      //   ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            // SizedBox(
                            //   height: 30.sp,
                            //   child: Row(
                            //     children: [
                            //       SizedBox(width: 5.sp),
                            //       Expanded(
                            //         child: Text(
                            //           path.basename(videoPath),
                            //           style: GoogleFonts.poppins(
                            //             fontSize: 11.sp,
                            //             fontWeight: FontWeight.w700,
                            //             color: Colors.black,
                            //           ),
                            //           maxLines: 1,
                            //           overflow: TextOverflow.ellipsis,
                            //         ),
                            //       ),
                            //       PopupMenuButton<String>(
                            //         icon: const Icon(
                            //           Icons.more_vert,
                            //           color: Colors.black54,
                            //           size: 20,
                            //         ),
                            //         onSelected: (value) {
                            //           ScaffoldMessenger.of(context).showSnackBar(
                            //             SnackBar(
                            //               content: Text('Selected: $value'),
                            //               backgroundColor: Colors.deepPurple,
                            //               behavior: SnackBarBehavior.floating,
                            //               shape: RoundedRectangleBorder(
                            //                 borderRadius:
                            //                 BorderRadius.circular(8),
                            //               ),
                            //             ),
                            //           );
                            //         },
                            //         itemBuilder: (context) => [
                            //           const PopupMenuItem(
                            //             value: 'share',
                            //             child: Text('Share'),
                            //           ),
                            //           const PopupMenuItem(
                            //             value: 'delete',
                            //             child: Text('Delete'),
                            //           ),
                            //           const PopupMenuItem(
                            //             value: 'info',
                            //             child: Text('Info'),
                            //           ),
                            //         ],
                            //       ),
                            //     ],
                            //   ),
                            // ),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videos: widget.videos
                              .where((path) => !path.startsWith('http'))
                              .map((path) => File(path))
                              .toList(),
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
                                        borderRadius:
                                        BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: AssetImage(
                                              'assets/video_thumbnail.jpg'),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius:
                                          BorderRadius.circular(4),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          videos: widget.videos
                              .where((path) => !path.startsWith('http'))
                              .map((path) => File(path))
                              .toList(),
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
                            future: _getVideoThumbnail(videoPath),
                            builder: (context, snapshot) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(5.sp)),
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
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(5.sp)),
                                        image: DecorationImage(
                                          image: AssetImage(
                                              'assets/video_thumbnail.jpg'),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.2),
                                          borderRadius:
                                          BorderRadius.circular(4),
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: ColorSelect.maineColor,
                                          borderRadius:
                                          BorderRadius.circular(4),
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