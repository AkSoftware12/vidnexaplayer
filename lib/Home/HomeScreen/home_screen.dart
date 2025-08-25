import 'dart:io';
import 'package:carousel_slider/carousel_slider.dart' show CarouselOptions, CarouselSlider;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:instamusic/DeviceSpace/device_space.dart';
import 'package:instamusic/Utils/color.dart';
import 'package:instamusic/VideoPLayer/AllVideo/all_videos.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../HexColorCode/HexColor.dart';
import '../../Model/property_type.dart';
import '../../NetWork Stream/stream_video.dart';
import '../../Photo/photo.dart';
import '../../RecentlyVideos/RecentlyPlayedManager/recently_played_manager.dart';
import '../../RecentlyVideos/RecentlyPlayedScreen/recently_played_screen.dart';
import '../../Utils/textSize.dart';
import '../../VideoPLayer/VideoList/video_list.dart';
import 'package:path/path.dart' as path;
import '../HomeBottomnavigation/home_bottomNavigation.dart';
import 'package:permission_handler/permission_handler.dart'; // Add permission_handler

class SearchData {
  final String imageUrl;
  final Color backgroundColor;
  final String text;

  SearchData({
    required this.imageUrl,
    required this.backgroundColor,
    required this.text,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  Map<String, List<File>> videosByFolder = {};
  bool isLoading = true;
  String? errorMessage;
  List<String> recentlyPlayed = [];
  bool hasPermission = true; // Track permission status



  bool _isLoadingMore = false;
  bool _hasMoreToLoad = true;
  bool _isLoading = true;
  bool _loading = false;

  AssetPathEntity? _path;
  List<AssetEntity>? _entities;
  int _totalEntitiesCount = 0;
  final int _sizePerPage = 50;

  @override
  void initState() {
    super.initState();
    _requestAssets();
    // _checkPermissions(); // Check permissions on init
    _loadRecentlyPlayed();
  }

  // Check for storage or video permissions
  Future<void> _checkPermissions() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      // For Android API >= 33, use Permission.videos; otherwise, use Permission.storage
      status = await (Platform.version.contains('13') || Platform.version.contains('14')
          ? Permission.videos.status
          : Permission.storage.status);
    } else {
      // For iOS, use Permission.photos or Permission.storage as needed
      status = await Permission.photos.status; // Use photos for iOS media access
    }

    setState(() {
      hasPermission = status.isGranted;
    });

    if (hasPermission) {
      _loadVideos(); // Load videos if permission is granted
      _requestAssets(); // Load assets for PhotoManager
    }
  }
  // Request permissions
  Future<void> _requestPermissions() async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await (Platform.version.contains('13') || Platform.version.contains('14')
          ? Permission.videos.request()
          : Permission.storage.request());
    } else {
      status = await Permission.storage.request();
    }

    setState(() {
      hasPermission = status.isGranted;
    });

    if (hasPermission) {
      _loadVideos(); // Load videos after permission is granted
    } else {
      // _showPermissionDeniedDialog();

    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Permission Required',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: TextSizes.textmedium,
            ),
          ),
          content: Text(
            'This app requires access to your music files to display offline songs. Please grant the necessary permissions.',
            style: GoogleFonts.poppins(fontSize: TextSizes.textsmall),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text(
                'Open Settings',
                style: GoogleFonts.poppins(
                  color: ColorSelect.maineColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Stay on permission screen or navigate back
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


// Request permissions and handle assets
  Future<void> _requestAssets() async {
    setState(() {
      _isLoading = true;
    });

    // Request permissions using PhotoManager
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!mounted) return;

    if (!ps.hasAccess) {
      setState(() {
        hasPermission = false;
        _isLoading = false;
      });
      await PhotoManager.openSetting(); // Open settings if permission denied
      return;
    }

    // Permission granted, update state
    setState(() {
      hasPermission = true;
    });

    // Load assets
    final PMFilter filter = FilterOptionGroup(
      imageOption: const FilterOption(
        sizeConstraint: SizeConstraint(ignoreSize: true),
      ),
    );

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      filterOption: filter,
    );

    if (!mounted || paths.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _path = paths.first;
    });

    _totalEntitiesCount = await _path!.assetCountAsync;
    final List<AssetEntity> entities = await _path!.getAssetListPaged(
      page: 0,
      size: _sizePerPage,
    );

    if (!mounted) return;

    setState(() {
      _entities = entities;
      _isLoading = false;
      _hasMoreToLoad = _entities!.length < _totalEntitiesCount;
    });

    // Load videos after assets are loaded
    await _loadVideos();
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.play_arrow),
                title: Text('Play Video'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.delete),
                title: Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Properties'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.copy),
                title: Text('Duplicate File'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.visibility_off),
                title: Text('Hide Folder Video'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadVideos() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      videosByFolder.clear();
    });

    try {
      final videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.3gp'];
      Map<String, List<File>> tempVideosByFolder = {};

      if (Platform.isAndroid) {
        List<Directory> directories = [
          Directory('/storage/emulated/0/'),
          Directory('/storage/emulated/0/Movies'),
          Directory('/storage/emulated/0/DCIM'),
          Directory('/storage/emulated/0/Download'),
          Directory('/storage/emulated/0/Videos'),
        ];

        directories = directories.where((dir) => dir.existsSync()).toList();
        await Future.wait(directories.map((dir) async {
          if (await dir.exists()) {
            await _scanDirectory(dir, videoExtensions, tempVideosByFolder);
            setState(() {
              videosByFolder = Map.from(tempVideosByFolder);
            });
          }
        }));
      } else if (Platform.isIOS) {
        Directory? dir = await Directory.systemTemp.createTemp();
        await _scanDirectory(dir, videoExtensions, tempVideosByFolder);
      }

      setState(() {
        videosByFolder = tempVideosByFolder;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading videos: $e';
      });
    }
  }

  Future<void> _scanDirectory(Directory dir, List<String> videoExtensions,
      Map<String, List<File>> tempVideosByFolder) async {
    try {
      if (dir.path.contains('/Android/data') || dir.path.contains('/Android/obb')) {
        return;
      }

      await for (var entity in dir.list(recursive: false)) {
        if (!mounted) return;
        if (entity is File &&
            videoExtensions.any((ext) => entity.path.toLowerCase().endsWith(ext))) {
          String folderPath = entity.parent.path;
          String folderName = path.basename(folderPath);
          tempVideosByFolder.putIfAbsent(folderName, () => []).add(entity);
        } else if (entity is Directory) {
          await _scanDirectory(entity, videoExtensions, tempVideosByFolder);
        }
      }
    } catch (e) {
      print('Error scanning directory ${dir.path}: $e');
    }
  }

  Future<void> _loadRecentlyPlayed() async {
    try {
      final videos = await RecentlyPlayedManager.getVideos();
      setState(() {
        recentlyPlayed = videos;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error loading videos: $e';
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });

  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadRecentlyPlayed();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: !hasPermission
          ? Center(
        child: Card(
          elevation: 4,
          margin: EdgeInsets.all(16.sp),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.sp),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.sp),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock,
                  size: 48.sp,
                  color: Colors.red,
                ),
                SizedBox(height: 16.sp),
                Text(
                  'Permission Required',
                  style: GoogleFonts.poppins(
                    textStyle: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                SizedBox(height: 8.sp),
                Text(
                  'Please allow access to videos to view content.',
                  style: GoogleFonts.poppins(
                    textStyle: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16.sp),
                ElevatedButton(
                  onPressed:  (){
                    _requestAssets();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorSelect.maineColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.sp),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24.sp, vertical: 12.sp),
                  ),
                  child: Text(
                    'Allow Permission',
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 10.sp),
            BannerSlider(),
            HorizontalGridList(),
            if (recentlyPlayed.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.all(8.sp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recently Videos',
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          color: Colors.black,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RecentlyPlayedScreen(
                              horizontalView: false,
                              recentVideos: recentlyPlayed,
                            ),
                          ),
                        ).then((value) {
                          _loadRecentlyPlayed();
                        });
                      },
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.list,
                                size: 12.sp,
                                color: ColorSelect.maineColor,
                              ),
                              Text(
                                ' See All',
                                style: GoogleFonts.openSans(
                                  textStyle: TextStyle(
                                    color: ColorSelect.maineColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 120.sp,
                child: RecentlyPlayedScreen(
                  horizontalView: true,
                  recentVideos: recentlyPlayed,
                ),
              ),
            ],
            Padding(
              padding: EdgeInsets.all(0.sp),
              child: Padding(
                padding: EdgeInsets.only(top: 8.sp),
                child: Container(
                  child: Padding(
                    padding: EdgeInsets.only(left: 10.sp, right: 10.sp),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Folders',
                          style: GoogleFonts.poppins(
                            textStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.black),
                          onPressed: _loadVideos,
                          tooltip: 'Refresh Videos',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            isLoading && videosByFolder.isEmpty
                ? Padding(
              padding: EdgeInsets.only(top: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CupertinoActivityIndicator(
                    radius: 25,
                    color: ColorSelect.maineColor,
                    animating: true,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Scanning for videos...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
                : errorMessage != null
                ? Padding(
              padding: EdgeInsets.only(top: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadVideos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
                : videosByFolder.isEmpty
                ? const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    color: Colors.grey,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No videos found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : Column(
              children: [
                ...List.generate(
                  videosByFolder.keys.length,
                      (index) {
                    String folderName = videosByFolder.keys.elementAt(index);
                    List<File> videos = videosByFolder[folderName]!;
                    final List<String> iconAssets = [
                      'assets/open-folder.png',
                      'assets/bluetooth.png',
                      'assets/open-folder.png',
                      'assets/camera2.png',
                      'assets/open-folder.png',
                      'assets/open-folder.png',
                      'assets/downloadlist.png',
                      'assets/open-folder.png',
                      'assets/open-folder.png',
                      'assets/open-folder.png',
                      'assets/open-folder.png',
                    ];
                    final List<Color> backgroundColors = [
                      Colors.blue,
                      Colors.green,
                      Colors.purple,
                      Colors.orange,
                      Colors.red,
                      Colors.teal,
                      Colors.cyan,
                      Colors.pink,
                      Colors.amber,
                      Colors.lime,
                    ];
                    String selectedIcon = iconAssets[index % iconAssets.length];
                    Color selectedColor = backgroundColors[index % backgroundColors.length];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoFolderScreen(
                              folderName: folderName,
                              videos: videos,
                            ),
                          ),
                        ).then((value) {
                          _loadRecentlyPlayed();
                        });
                      },
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 5.sp, horizontal: 5.sp),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10.sp),
                        ),
                        child: CustomFolderTile(
                          folderName: folderName,
                          videos: videos,
                          showBottomSheet: _showBottomSheet,
                          iconPath: selectedIcon,
                          color: selectedColor,
                        ),
                      ),
                    );
                  },
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceSpaceScreen(),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(10.sp),
                    child: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Container(
                        child: Row(
                          children: [
                            Container(
                              height: 35.sp,
                              width: 35.sp,
                              decoration: BoxDecoration(
                                color: Colors.purple.shade300,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Icon(
                                Icons.search,
                                color: Colors.white,
                                size: 20.sp,
                              ),
                            ),
                            SizedBox(width: 15.sp),
                            Text(
                              'Directory',
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  color: Theme.of(context).colorScheme.secondary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}

// The rest of your classes (CustomFolderTile, HorizontalGridList, BannerSlider) remain unchanged

class CustomFolderTile extends StatelessWidget {
  final String folderName;
  final List<dynamic> videos;
  final String iconPath;
  final Color color;
  final Function(BuildContext) showBottomSheet;

  const CustomFolderTile({
    Key? key,
    required this.folderName,
    required this.videos,
    required this.showBottomSheet,
    required this.iconPath,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 5.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: 8.w),

          // Leading icon container
          Container(
            height: 40.sp,
            width: 40.sp,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(15.0),
            ),
            child: Padding(
              padding: EdgeInsets.all(8.sp),
              child: Image.asset(
                iconPath,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$folderName',
                  style: GoogleFonts.poppins(
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 13.sp,
                      // Adjust font size as needed
                      fontWeight:
                          FontWeight.w600, // Adjust font weight as needed
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${videos.length} ${'Videos'}',
                  style: GoogleFonts.poppins(
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.secondary,
                      fontSize: 10.sp,
                      // Adjust font size as needed
                      fontWeight:
                          FontWeight.w500, // Adjust font weight as needed
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Trailing icon
          GestureDetector(
            onTap: () => showBottomSheet(context),
            child: Container(
              height: 40.sp,
              width: 50.sp,
              child: Icon(
                Icons.more_vert,
                size: 20.sp,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HorizontalGridList extends StatefulWidget {
  const HorizontalGridList({super.key});

  @override
  State<HorizontalGridList> createState() => _HorizontalGridListState();
}

class _HorizontalGridListState extends State<HorizontalGridList> {
  List<PropertyTypeModel> items = [
    // PropertyTypeModel(
    //   imageUrl: 'assets/customImages/prince.png',
    //   text: 'Games ',
    //   color: Colors.cyan,
    // ),
    PropertyTypeModel(
      // imageUrl: 'assets/customImages/play.png',
      imageUrl: 'assets/videos.png',
      text: 'All Videos',
      color: HexColor('#f97316'),
      color2: HexColor('#eab308'),

      mb: '124 GB',
    ),
    PropertyTypeModel(
      imageUrl: 'assets/image.png',
      text: 'Images',
      color: HexColor('#dc2626'),
      color2: HexColor('#ef4444'),
      mb: '5.6 GB',
    ),
    PropertyTypeModel(
      imageUrl: 'assets/musics.png',
      text: 'Music',
      color: HexColor('#7e22ce'),
      color2: HexColor('#9333ea'),
      mb: '2.2 GB',
    ),
    // PropertyTypeModel(
    //   imageUrl: 'assets/apps.png',
    //   text: ' Apps',
    //   color: HexColor('#2563eb'),
    //   color2: HexColor('#3b82f6'),
    //   mb: '1.5 GB',
    // ),
    // PropertyTypeModel(
    //   imageUrl: 'assets/customImages/lock.png',
    //   text: ' Privacy',
    //   color: HexColor('#2563eb'),
    //   color2: HexColor('#3b82f6'),
    //   mb: '7.2 GB',
    // ),
    PropertyTypeModel(
      imageUrl: 'assets/customImages/global_network.png',
      text: ' Network',
      color: HexColor('#2563eb'),
      color2: HexColor('#3b82f6'),
      mb: '3.2 GB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(5.sp),
      child: SizedBox(
        height: 95.sp, // Adjust height as needed
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () {
                if (index == 0) {

                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AllVideosScreen(),
                      ));
                } else if (index == 1) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SimpleExamplePage(),
                      ));
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HomeBottomNavigation(
                              bottomIndex: 1,
                            )),
                  );
                } else if (index ==3) {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerStream(),
                      ));
                }
              },
              child: Container(
                  width: MediaQuery.of(context).size.width *
                      0.3, // Adjust width as needed
                  padding: EdgeInsets.all(3.sp),
                  child: Container(
                    height: 25.sp,
                    width: MediaQuery.of(context).size.width * 0.35,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          items[index].color, // starting color
                          items[index].color2, // ending color
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10.sp),
                      // image: DecorationImage(
                      //   image: AssetImage('assets/livevideo.jpg')
                      // )
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 8.sp),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Align(
                                alignment: Alignment.topRight,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 0.sp),
                                  child: SizedBox(
                                    height: 25.sp,
                                    width: 25.sp,
                                    child: Image.asset(
                                      items[index].imageUrl,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 8.sp),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 3.sp),
                              Padding(
                                padding: EdgeInsets.only(bottom: 0.sp),
                                child: Text(
                                  items[index].text,
                                  style: GoogleFonts.poppins(
                                    textStyle: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.only(bottom: 0.sp),
                                child: Text(
                                  items[index].mb,
                                  style: GoogleFonts.poppins(
                                    textStyle: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 3.sp),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
            );
          },
        ),
      ),
    );
  }
}

class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});

  @override
  _BannerSliderState createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  final List<String> bannerImages = [
    'https://img.freepik.com/free-vector/organic-flat-abstract-music-youtube-thumbnail_23-2148921130.jpg',
    'https://img.freepik.com/free-vector/flat-design-banner-video-contest_52683-77575.jpg',
    'https://img.freepik.com/free-vector/playlist-youtube-thumbnail_23-2148600115.jpg',
    'https://images.squarespace-cdn.com/content/v1/6219238e0278bd045f89ac26/62b74316-0301-4636-a6fe-53be626fcc69/YouTube-banner-for-music-singers-channel-free.jpg',
    'https://d1csarkz8obe9u.cloudfront.net/posterpreviews/music-review-blog-youtube-banner-design-template-0f6f36593959a5fe315a97e1b3e48534_screen.jpg?ts=1566568274',
  ];

  int _currentIndex = 0;
  final CarouselController _carouselController =
      CarouselController(); // Controller for CarouselSlider

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider(
          // carouselController: _carouselController, // Assign controller to CarouselSlider
          options: CarouselOptions(
            height: 80.sp,
            // Set banner height
            autoPlay: true,
            // Auto-scroll banners
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            // Enlarge the center banner
            viewportFraction: 0.99,
            // Show partial next/previous banners
            enableInfiniteScroll: true,
            // Loop through banners
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index; // Update current index
              });
            },
          ),
          items: bannerImages.map((imageUrl) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: const EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover, // Fit image to container
                    ),
                  ),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8), // Space between carousel and dots
        SmoothPageIndicator(
          controller: PageController(initialPage: _currentIndex),
          // Use PageController for SmoothPageIndicator
          count: bannerImages.length,
          effect: WormEffect(
            dotHeight: 5.sp,
            dotWidth: 10.sp,
            activeDotColor: ColorSelect.maineColor,
            dotColor: Colors.grey.shade400,
            spacing: 3.sp,
          ),
          onDotClicked: (index) {
            // _carouselController.animateToPage(index); // Sync dot click with carousel
          },
        ),
      ],
    );
  }
}
