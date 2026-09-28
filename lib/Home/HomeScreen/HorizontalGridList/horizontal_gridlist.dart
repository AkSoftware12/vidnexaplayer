import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../../../DeviceSpace/device_space.dart';
import '../../../NetWork Stream/stream_video.dart';
import '../../../NotifyListeners/LanguageProvider/home_strings.dart';
import '../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../Utils/app_palette.dart';
import '../../../features/gallery/presentation/pages/gallery_home_page.dart';
import '../../../StatusSaverScreen/whatsapp_download.dart';
import '../../../VideoPLayer/VideoList/video_list.dart';
import '../../HomeBottomnavigation/home_bottomNavigation.dart'; // for AssetPathEntity

class PropertyTypeModel {
  final String imageUrl;
  final String text;
  final Color color;
  final Color color2;
  final String mb;
  final int count;

  /// Where this tile goes.
  ///
  /// Was an `if (index == 0) … else if (index == 1) …` chain in the item
  /// builder, which meant the tile order and the navigation order were two
  /// separate lists that had to be kept in sync by hand — inserting anything
  /// anywhere but the end silently sent every tile after it to the wrong
  /// screen.
  final void Function(BuildContext context) open;

  /// Paint the asset white before drawing it.
  ///
  /// The tiles' own artwork is already white, so it is left untinted. Assets
  /// borrowed from elsewhere in the app are not: `files.png` is a black
  /// outline that the drawer tints itself, and dropped straight onto this
  /// blue-violet gradient it read as a hole.
  final bool tintWhite;

  PropertyTypeModel({
    required this.imageUrl,
    required this.text,
    required this.color,
    required this.color2,
    required this.mb,
    required this.count,
    required this.open,
    this.tintWhite = false,
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
        // NOTE: `text` holds a HomeStrings key, not literal display copy —
        // it is translated at render time (see itemBuilder below) so this
        // list doesn't need to know the current language.
        PropertyTypeModel(
          imageUrl: 'assets/videos.png',
          text: 'home_cat_all_videos',
          color: Colors.deepOrange,
          color2: Colors.orangeAccent,
          mb: '12.4 GB',
          count: 245,
          open: (context) => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'AllVideosScreen'),
              builder: (context) => VideoFolderScreen(
                folderName: 'All Videos',
                videos: widget.album,
              ),
            ),
          ),
        ),
        PropertyTypeModel(
          imageUrl: 'assets/image.png',
          text: 'home_cat_images',
          color: Colors.pinkAccent,
          color2: Colors.redAccent,
          mb: '5.6 GB',
          count: 1032,
          open: (context) => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'GalleryHomeScreen'),
              builder: (context) => const GalleryHomePage(),
            ),
          ),
        ),
        // Moved here off the home app bar, where it was a bare purple folder
        // square sitting next to the drawer button with nothing naming it.
        // It is a media category like the rest, so it belongs in the row that
        // says so — and here it gets a label.
        PropertyTypeModel(
          imageUrl: 'assets/files.png',
          text: 'home_cat_files',
          tintWhite: true,
          color: const Color(0xFF3B82F6),
          color2: const Color(0xFF9333EA),
          mb: '0 GB',
          count: 0,
          open: (context) => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'DeviceSpaceScreen'),
              builder: (context) => const DeviceSpaceScreen(),
            ),
          ),
        ),
        PropertyTypeModel(
          imageUrl: 'assets/downloadlist.png',
          text: 'home_cat_status_saver',
          color: const Color(0xFF25D366),
          color2: const Color(0xFF7ED89F),
          mb: '3.2 GB',
          count: 27,
          open: (context) => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'StatusSaverScreen'),
              builder: (context) => const StatusSaverHomePage(),
            ),
          ),
        ),
        PropertyTypeModel(
          imageUrl: 'assets/link.img.png',
          text: 'home_cat_network',
          color: Colors.blueAccent,
          color2: Colors.lightBlueAccent,
          mb: '3.2 GB',
          count: 27,
          open: (context) => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'NetworkStreamScreen'),
              builder: (context) => const VideoPlayerStream(),
            ),
          ),
        ),

        // Music sits last on purpose: the bottom bar already has a Music tab,
        // so this tile is the second way to the same screen and does not need
        // one of the spots that are visible without scrolling.
        PropertyTypeModel(
          imageUrl: 'assets/musics.png',
          text: 'home_cat_music',
          color: Colors.deepPurple,
          color2: Colors.purpleAccent,
          mb: '2.2 GB',
          count: 312,
          open: (context) => Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: 'OfflineMusicScreen'),
              builder: (context) => const HomeBottomNavigation(bottomIndex: 1),
            ),
          ),
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6.sp),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(8.sp),
                    ),
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 16.sp,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(width: 8.sp),

                  /// 👉 Title + Subtitle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        HomeStrings.t(lang, 'home_media_categories_title'),
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppPalette.textH,
                        ),
                      ),
                      Text(
                        HomeStrings.t(lang, 'home_media_categories_subtitle'), // 👈 subtitle
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 7.sp,
                          fontWeight: FontWeight.w400,
                          color: AppPalette.textS,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              Container(
                padding: EdgeInsets.all(5.sp),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withValues(alpha:0.08),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: AppPalette.textB,
                  size: 15.sp,
                ),
              ),
            ],
          ),
        ),

        SizedBox(
          height: 60.sp,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            padding: EdgeInsets.symmetric(horizontal: 5.sp, vertical: 0.sp),
            // physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = items[index];
              return GestureDetector(
                onTap: () => item.open(context),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  margin: EdgeInsets.symmetric(
                    horizontal: 3.sp,
                    vertical: 0.sp,
                  ),
                  width: 80.sp,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item.color, item.color2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10.sp),
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20.sp),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha:0.08),
                              Colors.transparent,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(5.sp),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: Container(
                                height: 30.sp,
                                width: 30.sp,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha:0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(6.sp),
                                  child: Image.asset(
                                    item.imageUrl,
                                    color: item.tintWhite ? Colors.white : null,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              HomeStrings.t(lang, item.text),
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
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
          ),
        ),
        SizedBox(height: 5.sp),
      ],
    );
  }
}
