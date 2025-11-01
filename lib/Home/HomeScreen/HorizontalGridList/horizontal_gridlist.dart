import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../../NetWork Stream/stream_video.dart';
import '../../../Photo/image_album.dart';
import '../../../VideoPLayer/VideoList/video_list.dart';
import '../../HomeBottomnavigation/home_bottomNavigation.dart'; // for AssetPathEntity

class PropertyTypeModel {
  final String imageUrl;
  final String text;
  final Color color;
  final Color color2;
  final String mb;
  final int count;

  PropertyTypeModel({
    required this.imageUrl,
    required this.text,
    required this.color,
    required this.color2,
    required this.mb,
    required this.count,
  });
}

class HorizontalGridList extends StatefulWidget {
  final AssetPathEntity album;
  final int index;

  const HorizontalGridList({
    super.key,
    required this.album,
    required this.index,
  });

  @override
  State<HorizontalGridList> createState() => _HorizontalGridListState();
}

class _HorizontalGridListState extends State<HorizontalGridList> {
  List<PropertyTypeModel> items = [];

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    // ⚙️ Dummy counts for demo. You can fetch actual counts using APIs or PhotoManager.
    // For example, for videos: (await PhotoManager.getAssetPathList(type: RequestType.video))[0].assetCountAsync
    setState(() {
      items = [
        PropertyTypeModel(
          imageUrl: 'assets/videos.png',
          text: 'All Videos',
          color: Colors.deepOrange,
          color2: Colors.orangeAccent,
          mb: '12.4 GB',
          count: 245,
        ),
        PropertyTypeModel(
          imageUrl: 'assets/image.png',
          text: 'Images',
          color: Colors.pinkAccent,
          color2: Colors.redAccent,
          mb: '5.6 GB',
          count: 1032,
        ),
        PropertyTypeModel(
          imageUrl: 'assets/musics.png',
          text: 'Music',
          color: Colors.deepPurple,
          color2: Colors.purpleAccent,
          mb: '2.2 GB',
          count: 312,
        ),
        PropertyTypeModel(
          imageUrl: 'assets/link.img.png',
          text: 'Network',
          color: Colors.blueAccent,
          color2: Colors.lightBlueAccent,
          mb: '3.2 GB',
          count: 27,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110.sp,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        padding: EdgeInsets.symmetric(horizontal: 5.sp),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final item = items[index];
          return GestureDetector(
            onTap: () {
              if (index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => VideoFolderScreen(
                          folderName: 'All Videos',
                          videos: widget.album,
                        ),
                  ),
                );
              }
              // Navigator.push( // context, // MaterialPageRoute( // builder: (context) => AllVideosScreen(icon: 'AppBar'), // ), // ); }
              else if (index == 1) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AlbumScreen()),
                );
              } else if (index == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeBottomNavigation(bottomIndex: 1),
                  ),
                );
              } else if (index == 3) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => VideoPlayerStream()),
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              margin: EdgeInsets.symmetric(horizontal: 3.sp, vertical: 8.sp),
              width: 140.sp,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [item.color, item.color2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.sp),

              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.sp),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.transparent,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(10.sp),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            height: 35.sp,
                            width: 35.sp,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(6.sp),
                              child: Image.asset(
                                item.imageUrl,
                                color: Colors.white,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item.text,
                          style: GoogleFonts.poppins(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4.sp),
                        // Row(
                        //   children: [
                        //     Icon(
                        //       Icons.folder_open,
                        //       color: Colors.white,
                        //       size: 13.sp,
                        //     ),
                        //     SizedBox(width: 4.sp),
                        //     Text(
                        //       '${item.count} items',
                        //       style: GoogleFonts.poppins(
                        //         fontSize: 11.sp,
                        //         color: Colors.white.withOpacity(0.9),
                        //         fontWeight: FontWeight.w500,
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        // SizedBox(height: 2.sp),

                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
