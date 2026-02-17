import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:videoplayer/Utils/color.dart';
import '../../Utils/textSize.dart';

import 'OfflineSongs/presentation/pages/home/views/albums_view.dart';
import 'OfflineSongs/presentation/pages/home/views/artists_view.dart';
import 'OfflineSongs/presentation/pages/home/views/genres_view.dart';
import 'OfflineSongs/presentation/pages/home/views/songs_view.dart';

class OfflineMusicTabScreen extends StatefulWidget {
  const OfflineMusicTabScreen({super.key});

  @override
  State<OfflineMusicTabScreen> createState() => _OfflineMusicTabScreenState();
}

class _OfflineMusicTabScreenState extends State<OfflineMusicTabScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  int _selectedIndex = 0;

  /// ✅ cache to prevent flicker when coming back to this screen
  static bool? _lastKnownGranted;

  /// ✅ when false => permission status is still being checked (NO card)
  bool _permissionChecked = false;

  bool _hasPermissions = false;
  bool _isPermanentlyDenied = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addObserver(this);

    // ✅ instant UI based on last known status (prevents flash)
    if (_lastKnownGranted != null) {
      _hasPermissions = _lastKnownGranted!;
    }

    // ✅ silent re-check in background
    _checkPermissionStatusOnly();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkPermissionStatusOnly();
    }
  }

  Future<int> _getAndroidSdkInt() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.version.sdkInt;
  }

  Future<PermissionStatus> _currentPermissionStatus() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt >= 33) {
        return Permission.audio.status; // READ_MEDIA_AUDIO
      } else {
        return Permission.storage.status; // READ_EXTERNAL_STORAGE
      }
    } else if (Platform.isIOS) {
      return Permission.mediaLibrary.status;
    }
    return PermissionStatus.granted;
  }

  Future<PermissionStatus> _requestPermission() async {
    if (Platform.isAndroid) {
      final sdkInt = await _getAndroidSdkInt();
      if (sdkInt >= 33) {
        return Permission.audio.request();
      } else {
        return Permission.storage.request();
      }
    } else if (Platform.isIOS) {
      return Permission.mediaLibrary.request();
    }
    return PermissionStatus.granted;
  }

  /// ✅ no dialog, only check status (silent)
  Future<void> _checkPermissionStatusOnly() async {
    bool granted = false;
    bool permanentDenied = false;

    try {
      final status = await _currentPermissionStatus();
      granted = status.isGranted;
      permanentDenied = status.isPermanentlyDenied;
    } catch (_) {
      // keep existing state if something fails
      granted = _hasPermissions;
      permanentDenied = false;
    }

    if (!mounted) return;

    setState(() {
      _hasPermissions = granted;
      _isPermanentlyDenied = permanentDenied;
      _permissionChecked = true;
    });

    _lastKnownGranted = granted;
  }

  Future<void> _handlePermissionButton() async {
    final status = await _requestPermission();
    if (!mounted) return;

    setState(() {
      _hasPermissions = status.isGranted;
      _isPermanentlyDenied = status.isPermanentlyDenied;
      _permissionChecked = true;
    });

    _lastKnownGranted = status.isGranted;
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: ScrollConfiguration(
        behavior: const ConstantScrollBehavior(),
        child: Column(
          children: [
            _buildTopTabs(),

            Expanded(
              child: _hasPermissions
                  ? _buildTabsPageView()
                  : (!_permissionChecked)
                  ? const SizedBox() // ✅ NO permission card flash
                  : _buildPermissionDeniedCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabs() {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.background,
      automaticallyImplyLeading: false,
      title: SizedBox(
        height: 40.sp,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _buildTab('Songs', 0),
            _buildTab('Artists', 1),
            _buildTab('Albums', 2),
            _buildTab('Genres', 3),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Card(
        color: _selectedIndex == index ? ColorSelect.maineColor : Colors.white,
        child: SizedBox(
          width: 80.sp,
          child: Padding(
            padding: EdgeInsets.all(8.sp),
            child: Center(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  textStyle: TextStyle(
                    color: _selectedIndex == index
                        ? Colors.white
                        : ColorSelect.maineColor,
                    fontSize: TextSizes.textmedium,
                    fontWeight: FontWeight.bold,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabsPageView() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) => setState(() => _selectedIndex = index),
      children: [
        SongsView(
          color: Theme.of(context).colorScheme.background,
          colortext: Theme.of(context).colorScheme.secondary,
        ),
        ArtistsView(
          color: Theme.of(context).colorScheme.background,
          colortext: Theme.of(context).colorScheme.secondary,
        ),
        AlbumsView(
          color: Theme.of(context).colorScheme.background,
          colortext: Theme.of(context).colorScheme.secondary,
        ),
        GenresView(
          color: Theme.of(context).colorScheme.background,
          colortext: Theme.of(context).colorScheme.secondary,
        ),
      ],
    );
  }

  Widget _buildPermissionDeniedCard() {
    return Padding(
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
              Icon(Icons.music_off_rounded, color: Colors.red, size: 48.sp),
              SizedBox(height: 16.sp),
              Text(
                'Music Permission Required',
                style: GoogleFonts.poppins(
                  textStyle: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.sp),
              Text(
                'Offline songs show karne ke liye audio/storage permission chahiye.',
                style: GoogleFonts.poppins(
                  textStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.sp),
              if (_isPermanentlyDenied)
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Open Settings',
                    style: GoogleFonts.poppins(
                      textStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: _handlePermissionButton,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorSelect.maineColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }
}

class ConstantScrollBehavior extends ScrollBehavior {
  const ConstantScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => child;

  @override
  TargetPlatform getPlatform(BuildContext context) => TargetPlatform.android;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}
