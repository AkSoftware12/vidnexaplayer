import 'dart:io';
import 'package:carousel_slider/carousel_slider.dart' show CarouselOptions, CarouselSlider;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide AnimatedScale;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as path;

import '../../Model/property_type.dart';
import '../../NetWork Stream/stream_video.dart';
import '../../Photo/image_album.dart';
import '../../RecentlyVideos/RecentlyPlayedScreen/recently_played_screen.dart';
import '../../VideoPLayer/AllVideo/all_videos.dart';
import '../../VideoPLayer/VideoList/video_list.dart';
import '../HomeBottomnavigation/home_bottomNavigation.dart';

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

class VideoProvider with ChangeNotifier {
  Map<String, List<File>> _videosByFolder = {};
  bool _isLoading = true;
  String? _errorMessage;
  List<String> _recentlyPlayed = [];
  bool _hasPermissions = false;

  Map<String, List<File>> get videosByFolder => _videosByFolder;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get recentlyPlayed => _recentlyPlayed;
  bool get hasPermissions => _hasPermissions;

  void setPermissions(bool value) {
    _hasPermissions = value;
    notifyListeners();
  }



  Future<void> loadVideos() async {
    _isLoading = true;
    _errorMessage = null;
    _videosByFolder.clear();
    notifyListeners();

    try {
      // Request permissions
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        _isLoading = false;
        _errorMessage = 'Permission denied for accessing media.';
        notifyListeners();
        return;
      }

      final videoExtensions = [
        '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.3gp', '.webm', '.mpeg', '.mpg'
      ];

      Map<String, List<File>> tempVideosByFolder = {};
      Set<String> addedFilePaths = {}; // ✅ to prevent duplicates

      // ✅ 1. Fetch videos via photo_manager
      final albums = await PhotoManager.getAssetPathList(type: RequestType.video);
      for (var album in albums) {
        final assetCount = await album.assetCountAsync;
        final assets = await album.getAssetListRange(start: 0, end: assetCount);
        for (var asset in assets) {
          final file = await asset.file;
          if (file != null &&
              videoExtensions.any((ext) => file.path.toLowerCase().endsWith(ext))) {

            // ✅ Skip duplicates
            if (addedFilePaths.contains(file.path)) continue;
            addedFilePaths.add(file.path);

            String folderPath = file.parent.path;
            String folderName = path.basename(folderPath);
            tempVideosByFolder.putIfAbsent(folderName, () => []).add(file);
          }
        }
      }

      // ✅ 2. Manual fallback scanning only if no videos found
      if (tempVideosByFolder.isEmpty && Platform.isAndroid) {
        List<Directory> directories = [
          Directory('/storage/emulated/0'),
          Directory('/storage/sdcard'),
        ];

        for (var dir in directories) {
          if (await dir.exists()) {
            final result = await compute(scanDirectoryInIsolate, [dir, videoExtensions]);
            result.forEach((key, files) {
              tempVideosByFolder.putIfAbsent(key, () => []);
              for (var file in files) {
                // ✅ Skip duplicates from manual scanning too
                if (!addedFilePaths.contains(file.path)) {
                  addedFilePaths.add(file.path);
                  tempVideosByFolder[key]!.add(file);
                }
              }
            });
          }
        }
      }

      if (tempVideosByFolder.isEmpty) {
        _errorMessage = 'No video files found in accessible directories.';
      }

      _videosByFolder = tempVideosByFolder;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error loading videos: $e';
      notifyListeners();
    }
  }

// ✅ SHARED_PREFERENCES से actual data load करें
  Future<void> loadRecentlyPlayed() async {
    try {
      _errorMessage = null;

      // ✅ SharedPreferences से actual recently played videos load करें
      final prefs = await SharedPreferences.getInstance();
      final recentlyPlayedJson = prefs.getStringList('recently_played_videos') ?? [];

      // ✅ JSON को File paths में convert करें
      _recentlyPlayed = recentlyPlayedJson;

      print('✅ Loaded ${ _recentlyPlayed.length } recently played videos');
      notifyListeners();
    } catch (e) {
      print('❌ Error loading recently played: $e');
      _recentlyPlayed = [];
      notifyListeners();
    }
  }

  // ✅ Video play करने पर recently played में add करें
  Future<void> addToRecentlyPlayed(String videoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // ✅ Duplicate remove करें
      List<String> currentList = prefs.getStringList('recently_played_videos') ?? [];
      currentList.remove(videoPath); // Remove if already exists
      currentList.insert(0, videoPath); // Add to beginning

      // ✅ Max 20 videos रखें
      if (currentList.length > 20) {
        currentList = currentList.sublist(0, 20);
      }

      await prefs.setStringList('recently_played_videos', currentList);
      _recentlyPlayed = currentList;
      notifyListeners();

      print('✅ Added to recently played: $videoPath');
    } catch (e) {
      print('❌ Error adding to recently played: $e');
    }
  }

  // ✅ Video remove करने के लिए
  Future<void> removeFromRecentlyPlayed(String videoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> currentList = prefs.getStringList('recently_played_videos') ?? [];
      currentList.remove(videoPath);
      await prefs.setStringList('recently_played_videos', currentList);
      _recentlyPlayed = currentList;
      notifyListeners();
    } catch (e) {
      print('❌ Error removing from recently played: $e');
    }
  }

  Future<void> deleteFolder(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text("Folder deleted successfully")),
        );
        notifyListeners();
      } else {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          SnackBar(content: Text("Folder not found")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(content: Text("Error deleting folder: $e")),
      );
    } finally {
      await loadVideos();
    }
  }
}

// Global key for ScaffoldMessenger
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


Future<Map<String, List<File>>> scanDirectoryInIsolate(List<dynamic> args) async {
  Directory dir = args[0] as Directory;
  List<String> videoExtensions = args[1] as List<String>;
  Map<String, List<File>> tempVideosByFolder = {};
  Set<String> addedFiles = {}; // ✅ To prevent duplicates

  try {
    // Skip restricted folders
    if (dir.path.contains('/Android/data') ||
        dir.path.contains('/Android/obb') ||
        dir.path.contains('/.nomedia')) {
      return tempVideosByFolder;
    }

    await for (var entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is File &&
          videoExtensions.any((ext) => entity.path.toLowerCase().endsWith(ext))) {

        // ✅ Check if this file was already added
        if (addedFiles.contains(entity.path)) continue;
        addedFiles.add(entity.path);

        String folderPath = entity.parent.path;
        String folderName = path.basename(folderPath);
        tempVideosByFolder.putIfAbsent(folderName, () => []).add(entity);

      } else if (entity is Directory) {
        try {
          final subFolderVideos = await scanDirectoryInIsolate([entity, videoExtensions]);
          // ✅ Merge subfolder videos safely (without duplicates)
          subFolderVideos.forEach((key, files) {
            tempVideosByFolder.putIfAbsent(key, () => []);
            for (var f in files) {
              if (!addedFiles.contains(f.path)) {
                addedFiles.add(f.path);
                tempVideosByFolder[key]!.add(f);
              }
            }
          });
        } catch (e) {
          print('Error scanning subdirectory ${entity.path}: $e');
        }
      }
    }
  } catch (e) {
    print('Error scanning directory ${dir.path}: $e');
  }
  return tempVideosByFolder;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {
  final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
  bool _permissionsChecked = false;
  DateTime? _lastRefreshTime;
  final Duration _debounceDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  Future<int> _getAndroidSdkInt() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    }
    return 0;
  }

  Future<void> _checkPermissions() async {
    if (_permissionsChecked) return;

    bool hasPhotosPermission = false;
    bool hasVideosPermission = false;
    int sdkInt = await _getAndroidSdkInt();

    try {
      if (Platform.isAndroid) {
        if (sdkInt < 33) {
          PermissionStatus storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            storageStatus = await Permission.storage.request();
          }
          hasPhotosPermission = storageStatus.isGranted;
          hasVideosPermission = storageStatus.isGranted;
        } else {
          hasPhotosPermission = await Permission.photos.isGranted;
          hasVideosPermission = await Permission.videos.isGranted;
          if (!hasPhotosPermission || !hasVideosPermission) {
            Map<Permission, PermissionStatus> statuses = await [
              Permission.photos,
              Permission.videos,
            ].request();
            hasPhotosPermission = statuses[Permission.photos]!.isGranted;
            hasVideosPermission = statuses[Permission.videos]!.isGranted;
          }
        }
      } else if (Platform.isIOS) {
        hasPhotosPermission = await Permission.photos.isGranted;
        hasVideosPermission = await Permission.videos.isGranted;
        if (!hasPhotosPermission || !hasVideosPermission) {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.photos,
            Permission.videos,
          ].request();
          hasPhotosPermission = statuses[Permission.photos]!.isGranted;
          hasVideosPermission = statuses[Permission.videos]!.isGranted;
        }
      }

      if (mounted) {
        setState(() {
          _permissionsChecked = true;
          Provider.of<VideoProvider>(context, listen: false)
              .setPermissions(hasPhotosPermission && hasVideosPermission);
        });

        if (hasPhotosPermission && hasVideosPermission) {
          await Provider.of<VideoProvider>(context, listen: false).loadVideos();
          await Provider.of<VideoProvider>(context, listen: false).loadRecentlyPlayed();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please grant photos and videos permissions to continue.'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking permissions: $e')),
        );
      }
    }
  }

  Future<void> _requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.photos,
        Permission.videos,
      ].request();

      bool photosGranted = statuses[Permission.photos]!.isGranted;
      bool videosGranted = statuses[Permission.videos]!.isGranted;

      if (mounted) {
        setState(() {
          Provider.of<VideoProvider>(context, listen: false).setPermissions(photosGranted && videosGranted);
        });

        if (photosGranted && videosGranted) {
          await Provider.of<VideoProvider>(context, listen: false).loadVideos();
          await Provider.of<VideoProvider>(context, listen: false).loadRecentlyPlayed();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permissions denied. Please grant access in settings.'),
              action: SnackBarAction(
                label: 'Open Settings',
                onPressed: () => openAppSettings(),
              ),
            ),
          );
          await openAppSettings();
          _permissionsChecked = false;
          await _checkPermissions();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting permissions: $e')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _permissionsChecked = false;
      _checkPermissions();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPopNext() {
    _permissionsChecked = false;
    _checkPermissions();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(2)} ${suffixes[i]}";
  }

  String _formatDateTime(DateTime dateTime) {
    final DateFormat formatter = DateFormat('dd/MM/yyyy');
    return formatter.format(dateTime);
  }

  void showFolderInfoDialog(BuildContext context, {
    required String folderName,
    required String size,
    required String location,
    required String modifiedDate,
    required List<File> videos,
  }) {
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
              Icon(Icons.folder, color: Colors.blue, size: 30),
              SizedBox(width: 8),
              Text(
                'Folder Info',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Folder Name', folderName),
              SizedBox(height: 12),
              _buildInfoRow('Size', size),
              SizedBox(height: 12),
              _buildInfoRow('Location', location),
              SizedBox(height: 12),
              _buildInfoRow('Modified Date', modifiedDate),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.black87,
            fontSize: 12.sp,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12.sp,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  void showEnhancedDogBehaviorSheet(BuildContext context, String folderName, List<File> videos, String formattedSize, String location, String date) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
      ),
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: AnimationStyle(
        duration: Duration(milliseconds: 700),
        reverseDuration: Duration(milliseconds: 500),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30.0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 15,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2.sp),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: Colors.blue),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 25.sp,
                          width: 25.sp,
                          child: Image.asset('assets/appblue.png'),
                        ),
                      ),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vidnexa Player',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: Colors.blue,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '($folderName)',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: Colors.purple,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_outlined, color: Colors.blue, size: 25.sp),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                height: 4,
                margin: EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
                children: [
                  _buildOptionCard(
                    context,
                    Icons.folder,
                    'Open',
                    Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => VideoFolderScreen(
                      //       folderName: folderName,
                      //       videos: videos,
                      //     ),
                      //   ),
                      // ).then((value) {
                      //   _permissionsChecked = false;
                      //   _checkPermissions();
                      // });
                    },
                  ),
                  _buildOptionCard(
                    context,
                    Icons.delete,
                    'Delete',
                    Theme.of(context).colorScheme.error,
                    onTap: () async {
                      Navigator.pop(context);
                      await Provider.of<VideoProvider>(context, listen: false).deleteFolder(location);
                    },
                  ),
                  _buildOptionCard(
                    context,
                    Icons.info_outline,
                    'Info',
                    Theme.of(context).colorScheme.secondary,
                    onTap: () {
                      Navigator.pop(context);
                      showFolderInfoDialog(
                        context,
                        folderName: folderName,
                        size: formattedSize,
                        location: location,
                        modifiedDate: date,
                        videos: videos,
                      );
                    },
                  ),
                  _buildOptionCard(
                    context,
                    Icons.copy,
                    'Copy',
                    Theme.of(context).colorScheme.secondary,
                    onTap: () {},
                  ),
                  _buildOptionCard(
                    context,
                    Icons.visibility_off,
                    'Hide',
                    Theme.of(context).colorScheme.secondary,
                    onTap: () {},
                  ),
                ],
              ),
              SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionCard(BuildContext context, IconData emoji, String label, Color itemColor, {required Function() onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: itemColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(5.sp),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Icon(emoji, color: itemColor, size: 22.sp),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.openSans(
                textStyle: TextStyle(
                  color: itemColor,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VideoProvider>(
      builder: (context, videoProvider, child) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: RefreshIndicator(
            onRefresh: () async {
              final now = DateTime.now();
              if (_lastRefreshTime == null || now.difference(_lastRefreshTime!) > _debounceDuration) {
                _lastRefreshTime = now;
                await Provider.of<VideoProvider>(context, listen: false).loadVideos();
                await Provider.of<VideoProvider>(context, listen: false).loadRecentlyPlayed();
              }
            },
            child: SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 10.sp),
                  BannerSlider(),
                  HorizontalGridList(),
                  if (!videoProvider.hasPermissions) ...[
                    Padding(
                      padding: EdgeInsets.all(16.sp),
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.sp),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: Colors.red,
                                size: 48.sp,
                              ),
                              SizedBox(height: 16.sp),
                              Text(
                                'Permissions Required',
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
                                'Please grant access to photos and videos to view your media content.',
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    fontSize: 14.sp,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 16.sp),
                              ElevatedButton(
                                onPressed: _requestPermissions,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Allow Permissions',
                                  style: GoogleFonts.poppins(
                                    textStyle: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    if (videoProvider.recentlyPlayed.isNotEmpty) ...[
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
                                      recentVideos: videoProvider.recentlyPlayed,
                                    ),
                                  ),
                                ).then((value) {
                                  _permissionsChecked = false;
                                  _checkPermissions();
                                });
                              },
                              child: Card(
                                child: Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.list,
                                        size: 12.sp,
                                        color: Colors.blue,
                                      ),
                                      Text(
                                        ' See All',
                                        style: GoogleFonts.openSans(
                                          textStyle: TextStyle(
                                            color: Colors.blue,
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
                          recentVideos: videoProvider.recentlyPlayed,
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
                                  icon: Icon(Icons.refresh, color: Colors.black),
                                  onPressed: () async {
                                    final now = DateTime.now();
                                    if (_lastRefreshTime == null || now.difference(_lastRefreshTime!) > _debounceDuration) {
                                      _lastRefreshTime = now;
                                      await Provider.of<VideoProvider>(context, listen: false).loadVideos();
                                    }
                                  },
                                  tooltip: 'Refresh Videos',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    videoProvider.isLoading
                        ? Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoActivityIndicator(
                            radius: 25,
                            color: Colors.blue,
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
                        : videoProvider.errorMessage != null
                        ? Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            videoProvider.errorMessage!,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Provider.of<VideoProvider>(context, listen: false).loadVideos(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text('Retry'),
                          ),
                        ],
                      ),
                    )
                        : videoProvider.videosByFolder.isEmpty
                        ? Padding(
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
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: videoProvider.videosByFolder.keys.length,
                      itemBuilder: (context, index) {
                        String folderName = videoProvider.videosByFolder.keys.elementAt(index);
                        List<File> videos = videoProvider.videosByFolder[folderName]!;
                        int totalSizeInBytes = videos.fold(0, (sum, file) => sum + (file.lengthSync()));
                        String formattedSize = _formatFileSize(totalSizeInBytes);
                        String folderPath = videos.isNotEmpty
                            ? (videos.first.parent.path.isNotEmpty ? videos.first.parent.path : 'Unknown Path')
                            : 'Unknown Path';
                        String lastModified = 'Unknown Date';
                        if (videos.isNotEmpty) {
                          try {
                            Directory folder = videos.first.parent;
                            lastModified = _formatDateTime(folder.statSync().modified);
                          } catch (e) {
                            lastModified = 'Unknown Date';
                          }
                        }

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
                            // Navigator.push(
                            //   context,
                            //   MaterialPageRoute(
                            //     builder: (context) => VideoFolderScreen(
                            //       folderName: folderName,
                            //       videos: videos,
                            //     ),
                            //   ),
                            // ).then((value) {
                            //   _permissionsChecked = false;
                            //   _checkPermissions();
                            // });
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(vertical: 5.sp, horizontal: 5.sp),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.sp),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 5.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(width: 8.w),
                                  Container(
                                    height: 40.sp,
                                    width: 40.sp,
                                    decoration: BoxDecoration(
                                      color: selectedColor,
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(8.sp),
                                      child: Image.asset(selectedIcon),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          folderName,
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              color: Theme.of(context).colorScheme.secondary,
                                              fontSize: 13.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          '${videos.length} Videos',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              color: Theme.of(context).colorScheme.secondary,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Size: $formattedSize',
                                          style: GoogleFonts.poppins(
                                            textStyle: TextStyle(
                                              color: Theme.of(context).colorScheme.secondary,
                                              fontSize: 10.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      showEnhancedDogBehaviorSheet(
                                        context,
                                        folderName,
                                        videos,
                                        formattedSize,
                                        folderPath,
                                        lastModified,
                                      );
                                    },
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
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
    PropertyTypeModel(
      imageUrl: 'assets/videos.png',
      text: 'All Videos',
      color: Colors.orange,
      color2: Colors.yellow,
      mb: '124 GB',
    ),
    PropertyTypeModel(
      imageUrl: 'assets/image.png',
      text: 'Images',
      color: Colors.red,
      color2: Colors.redAccent,
      mb: '5.6 GB',
    ),
    PropertyTypeModel(
      imageUrl: 'assets/musics.png',
      text: 'Music',
      color: Colors.purple,
      color2: Colors.purpleAccent,
      mb: '2.2 GB',
    ),
    PropertyTypeModel(
      imageUrl: 'assets/link.img.png',
      text: 'Network',
      color: Colors.blue,
      color2: Colors.blueAccent,
      mb: '3.2 GB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(5.sp),
      child: SizedBox(
        height: 95.sp,
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
                      builder: (context) => AllVideosScreen(icon: 'AppBar'),
                    ),
                  );
                } else if (index == 1) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AlbumScreen(),
                    ),
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
                    MaterialPageRoute(
                      builder: (context) => VideoPlayerStream(),
                    ),
                  );
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.3,
                padding: EdgeInsets.all(3.sp),
                child: Container(
                  height: 25.sp,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [items[index].color, items[index].color2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10.sp),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8.sp),
                      Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Align(
                          alignment: Alignment.topRight,
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
                      Padding(
                        padding: EdgeInsets.only(left: 8.sp),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 3.sp),
                            Text(
                              items[index].text,
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              items[index].mb,
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(height: 3.sp),
                          ],
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 80.sp,
            autoPlay: true,
            autoPlayInterval: Duration(seconds: 3),
            autoPlayAnimationDuration: Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            viewportFraction: 0.99,
            enableInfiniteScroll: true,
            onPageChanged: (index, reason) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
          items: bannerImages.map((imageUrl) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  margin: EdgeInsets.symmetric(horizontal: 5.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                );
              },
            );
          }).toList(),
        ),
        SizedBox(height: 8),
        SmoothPageIndicator(
          controller: PageController(initialPage: _currentIndex),
          count: bannerImages.length,
          effect: WormEffect(
            dotHeight: 5.sp,
            dotWidth: 10.sp,
            activeDotColor: Colors.blue,
            dotColor: Colors.grey.shade400,
            spacing: 3.sp,
          ),
        ),
      ],
    );
  }
}








