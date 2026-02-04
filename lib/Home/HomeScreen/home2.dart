import 'dart:io';
import 'package:flutter/cupertino.dart' hide AnimatedScale;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide AnimatedScale;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/Utils/color.dart';
import '../../Photo/image_album.dart';
import '../../RecentlyVideos/RecentlyPlayedScreen/recently_played_screen.dart';
import '../../VideoPLayer/4kPlayer/4k_player.dart';
import '../../VideoPLayer/VideoList/video_list.dart';
import 'BannerSlider/banner_slider.dart';
import 'BottomsheetHomeScreen/bottomsheet_menu_button.dart';
import 'HorizontalGridList/horizontal_gridlist.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoProvider with ChangeNotifier {
  static const _key = 'recently_played_videos';
  static const int _max = 20;

  List<String> _recentlyPlayed = [];

  List<String> get recentlyPlayed => _recentlyPlayed;

  Future<void> loadRecentlyPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentlyPlayed = prefs.getStringList(_key) ?? [];
      notifyListeners();
    } catch (_) {
      _recentlyPlayed = [];
      notifyListeners();
    }
  }

  Future<void> addToRecentlyPlayed(String assetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList(_key) ?? [];

      list.remove(assetId);
      list.insert(0, assetId);

      if (list.length > _max) list = list.sublist(0, _max);

      await prefs.setStringList(_key, list);
      _recentlyPlayed = list;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> removeFromRecentlyPlayed(String assetId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> list = prefs.getStringList(_key) ?? [];
      list.remove(assetId);

      await prefs.setStringList(_key, list);
      _recentlyPlayed = list;
      notifyListeners();
    } catch (_) {}
  }
  void removeRecentlyPlayed(String id) {
    recentlyPlayed.remove(id);
    notifyListeners();
  }

  void removeRecentAt(int index) {
    if (index < 0 || index >= recentlyPlayed.length) return;
    recentlyPlayed.removeAt(index);
    notifyListeners();
  }

  Future<void> clearRecentlyPlayed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      _recentlyPlayed = [];
      notifyListeners();
    } catch (_) {}
  }
}

class DemoHomeScreen extends StatefulWidget {
  const DemoHomeScreen({super.key});

  @override
  State<DemoHomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<DemoHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<AssetPathEntity> _albums = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isListView = true;
  bool _isGridView = false;
  bool _isCompactView = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _requestPermissionAndLoadAlbums();
  }

  Future<void> _checkPermissionStatus() async {
    final ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth && !_hasPermission) {
      setState(() {
        _hasPermission = true;
        _isLoading = true;
      });
      await _requestPermissionAndLoadAlbums();
    }
  }

  Future<void> _requestPermissionAndLoadAlbums() async {
    setState(() => _isLoading = true);
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      _hasPermission = true;
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.video,
      );
      setState(() {
        _albums = albums;
        _isLoading = false;
      });
      _controller.forward();
    } else {
      _hasPermission = false;
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatus();
    }
  }

  Widget _buildPermissionCard() {
    return Center(
      child: Padding(
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
                Icon(Icons.lock_outline, color: Colors.red, size: 48.sp),
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

                SizedBox(height: 16.sp),
                ElevatedButton(
                  onPressed: () async {
                    await PhotoManager.openSetting();
                  },
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<VideoProvider>(
            context,
            listen: false,
          ).loadRecentlyPlayed();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: 10.sp),
              const BannerSlider(),



              _isLoading
                  ? SizedBox()
                  : !_hasPermission
                  ? _buildPermissionCard()
                  : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [

                          RecentlyPlayedSection(
                            onTap: (videos, index) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullScreenVideoPlayerFixed(
                                    videos: videos,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                          ),

                          _albums.isNotEmpty
                              ? HorizontalGridList(album: _albums[0], index: 0)
                              : const SizedBox.shrink(),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.sp,
                              vertical: 8.sp,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6.sp),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(
                                          10.sp,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.folder_open_rounded,
                                        color: Colors.blueAccent,
                                        size: 18.sp,
                                      ),
                                    ),
                                    SizedBox(width: 8.sp),
                                    Text(
                                      'Folders',
                                      style: GoogleFonts.poppins(
                                        textStyle: TextStyle(
                                          color: Colors.black87,
                                          fontSize: 15.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                Row(
                                  children: [
                                    // IconButton(
                                    //   icon: Icon(Icons.refresh, color: Colors.black),
                                    //   onPressed: () async {
                                    //     await _requestPermissionAndLoadAlbums();
                                    //   },
                                    //   tooltip: 'Refresh Videos',
                                    // ),
                                    Container(
                                      height: 32.sp,
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Row(
                                        children: [
                                          // 🔸 List View Button
                                          _buildToggleButton(
                                            icon: Icons.list,
                                            isActive: _isListView,
                                            onTap: () {
                                              setState(() {
                                                _isListView = true;
                                                _isGridView = false;
                                                _isCompactView = false;
                                              });
                                            },
                                          ),
                                          // 🔸 Grid View Button
                                          _buildToggleButton(
                                            icon: Icons.grid_view_rounded,
                                            isActive: _isGridView,
                                            onTap: () {
                                              setState(() {
                                                _isListView = false;
                                                _isGridView = true;
                                                _isCompactView = false;
                                              });
                                            },
                                          ),
                                          // 🔸 Compact View Button
                                          _buildToggleButton(
                                            icon: Icons.view_agenda_rounded,
                                            isActive: _isCompactView,
                                            onTap: () {
                                              setState(() {
                                                _isListView = false;
                                                _isGridView = false;
                                                _isCompactView = true;
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _isLoading
                              ? Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.sp),
                                  child: CircularProgressIndicator(
                                    color: Colors.blue,
                                  ),
                                ),
                              )
                              : _albums.isEmpty
                              ? Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 50.sp),
                                  child: Text(
                                    'No albums found',
                                    style: GoogleFonts.poppins(
                                      textStyle: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              : FadeTransition(
                                opacity: _fadeAnimation,
                                child: AnimatedSwitcher(
                                  duration: Duration(milliseconds: 000),
                                  switchInCurve: Curves.easeIn,
                                  switchOutCurve: Curves.easeIn,
                                  child:
                                      _isListView
                                          ? ListView.builder(
                                            key: ValueKey('listView'),
                                            shrinkWrap: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            itemCount: _albums.length,
                                            itemBuilder: (context, index) {
                                              return AlbumTile(
                                                album: _albums[index],
                                                index: index,
                                              );
                                            },
                                          )
                                          : _isGridView
                                          ? GridView.builder(
                                            key: ValueKey('gridView'),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 3.sp,
                                              vertical: 0.sp,
                                            ),
                                            shrinkWrap: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            itemCount: _albums.length,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 2,
                                                  mainAxisSpacing: 2.sp,
                                                  crossAxisSpacing: 2.sp,
                                                  childAspectRatio: 2.5,
                                                ),
                                            itemBuilder: (context, index) {
                                              return AlbumGridTile(
                                                album: _albums[index],
                                                index: index,
                                              );
                                            },
                                          )
                                          : GridView.builder(
                                            padding: EdgeInsets.all(8.w),
                                            itemCount: _albums.length,
                                            shrinkWrap: true,
                                            physics:
                                                NeverScrollableScrollPhysics(),
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: 3,
                                                  crossAxisSpacing: 2.w,
                                                  mainAxisSpacing: 2.h,
                                                  childAspectRatio: 1,
                                                ),
                                            itemBuilder: (context, index) {
                                              return AlbumGridTile3(
                                                album: _albums[index],
                                                index: index,
                                              );
                                            },
                                          ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 5.sp),
        decoration: BoxDecoration(
          color: isActive ? ColorSelect.maineColor2 : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : Colors.black,
          size: 18.sp,
        ),
      ),
    );
  }
}

class AlbumTile extends StatelessWidget {
  final AssetPathEntity album;
  final int index;

  const AlbumTile({super.key, required this.album, required this.index});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: album.assetCountAsync,
      builder: (context, snapshot) {
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
                builder:
                    (context) => VideoFolderScreen(
                      folderName: album.name,
                      videos: album,
                    ),
              ),
            );
          },
          child: AnimatedScale(
            duration: Duration(milliseconds: 500),
            scale: snapshot.hasData ? 1.0 : 1,
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
                          album.name.isNotEmpty
                              ? Text(
                                album.name,
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              )
                              : Text(
                                'SD Card',
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          SizedBox(height: 4.h),
                          Text(
                            '${snapshot.data ?? 0} Videos',
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
                          // Text(
                          //   'Size: $formattedSize',
                          //   style: GoogleFonts.poppins(
                          //     textStyle: TextStyle(
                          //       color: Theme.of(context).colorScheme.secondary,
                          //       fontSize: 10.sp,
                          //       fontWeight: FontWeight.w500,
                          //     ),
                          //   ),
                          //   maxLines: 1,
                          //   overflow: TextOverflow.ellipsis,
                          // ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        FolderBottomSheet.show(
                          context,
                          folderName: album.name,
                          videos: album,
                          formattedSize: '2.5 GB',
                          location: '/storage/emulated/0/Movies',
                          date: 'Oct 31, 2025',
                        );

                        // showEnhancedDogBehaviorSheet(
                        //   context,
                        //   folderName,
                        //   videos,
                        //   formattedSize,
                        //   folderPath,
                        //   lastModified,
                        // );
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
          ),
        );
      },
    );
  }
}

class AlbumGridTile extends StatelessWidget {
  final AssetPathEntity album;
  final int index;

  const AlbumGridTile({super.key, required this.album, required this.index});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: album.assetCountAsync,
      builder: (context, snapshot) {
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
                builder:
                    (context) => VideoFolderScreen(
                      folderName: album.name,
                      videos: album,
                    ),
              ),
            );
          },
          child: AnimatedScale(
            duration: Duration(milliseconds: 500),
            scale: snapshot.hasData ? 1.0 : 1,
            child: Container(
              margin: EdgeInsets.all(4.sp),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10.sp),
                boxShadow: [
                  BoxShadow(
                    color: selectedColor.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(3.sp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Folder icon
                    Container(
                      height: 35.sp,
                      width: 35.sp,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Image.asset(selectedIcon),
                      ),
                    ),

                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6.sp),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            album.name.isNotEmpty
                                ? Text(
                                  album.name,
                                  style: GoogleFonts.poppins(
                                    textStyle: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  maxLines: 1,
                                )
                                : Text(
                                  'SD Card',
                                  style: GoogleFonts.poppins(
                                    textStyle: TextStyle(
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.secondary,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            SizedBox(height: 4.h),
                            Text(
                              '${snapshot.data ?? 0} Videos',
                              style: GoogleFonts.poppins(
                                textStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
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
                    ),
                    GestureDetector(
                      onTap: () {
                        FolderBottomSheet.show(
                          context,
                          folderName: album.name,
                          videos: album,
                          formattedSize: '2.5 GB',
                          location: '/storage/emulated/0/Movies',
                          date: 'Oct 31, 2025',
                        );

                        // showEnhancedDogBehaviorSheet(
                        //   context,
                        //   folderName,
                        //   videos,
                        //   formattedSize,
                        //   folderPath,
                        //   lastModified,
                        // );
                      },

                      child: Container(
                        height: 40.sp,
                        width: 20.sp,
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
          ),
        );
      },
    );
  }
}

class AlbumGridTile3 extends StatelessWidget {
  final AssetPathEntity album;
  final int index;

  const AlbumGridTile3({super.key, required this.album, required this.index});

  @override
  Widget build(BuildContext context) {
    final gradients = [
      [Colors.blueAccent, Colors.purpleAccent],
      [Colors.teal, Colors.greenAccent],
      [Colors.orangeAccent, Colors.redAccent],
      [Colors.indigoAccent, Colors.deepPurpleAccent],
      [Colors.pinkAccent, Colors.orangeAccent],
    ];

    final selectedGradient = gradients[index % gradients.length];

    return FutureBuilder<int>(
      future: album.assetCountAsync,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
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
                builder:
                    (context) => VideoFolderScreen(
                      folderName: album.name,
                      videos: album,
                    ),
              ),
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: EdgeInsets.all(2.sp),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.sp),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Folder Icon
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    children: [
                      SizedBox(height: 10.sp),
                      Container(
                        height: 50.sp,
                        width: 50.sp,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white30, width: 1),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(8.sp),
                          child: Image.asset(selectedIcon),
                        ),
                      ),
                    ],
                  ),
                ),

                // Glass info overlay
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      // color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(15.r),
                        bottomRight: Radius.circular(15.r),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                album.name.isNotEmpty
                                    ? album.name
                                    : "Untitled Album",
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 0.h),
                              Text(
                                "$count videos",
                                style: GoogleFonts.poppins(
                                  textStyle: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            FolderBottomSheet.show(
                              context,
                              folderName: album.name,
                              videos: album,
                              formattedSize: '2.5 GB',
                              location: '/storage/emulated/0/Movies',
                              date: 'Oct 31, 2025',
                            );

                            // showEnhancedDogBehaviorSheet(
                            //   context,
                            //   folderName,
                            //   videos,
                            //   formattedSize,
                            //   folderPath,
                            //   lastModified,
                            // );
                          },

                          child: Container(
                            height: 40.sp,
                            width: 10.sp,
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
              ],
            ),
          ),
        );
      },
    );
  }
}
