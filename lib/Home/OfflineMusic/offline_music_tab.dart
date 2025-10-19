import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
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
  _DashBoardScreenState createState() => _DashBoardScreenState();
}

class _DashBoardScreenState extends State<OfflineMusicTabScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late PageController _pageController;
  int _selectedIndex = 0;
  bool _hasPermissions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addObserver(this); // Add observer for lifecycle changes
    _checkPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // When app resumes, recheck permissions
      _checkPermissions();
    }
  }

  // Check audio permission for Android 14 (API 34)
  // Future<void> _checkPermissions() async {
  //   bool audioPermission;
  //
  //   if (Platform.isAndroid || Platform.isIOS) {
  //     audioPermission = await Permission.audio.isGranted;
  //   } else {
  //     audioPermission = false;
  //   }
  //
  //   if (mounted) {
  //     setState(() {
  //       _hasPermissions = audioPermission;
  //       _isLoading = false;
  //     });
  //
  //     if (_hasPermissions) {
  //       await _loadMusic(); // Load music data when permission is granted
  //     }
  //   }
  // }


  Future<int> _getAndroidSdkInt() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    }
    return 0; // Non-Android
  }

  Future<void> _checkPermissions() async {
    bool hasAudioPermission = false;
    int sdkInt = await _getAndroidSdkInt();

    if (Platform.isAndroid) {
      if (sdkInt >= 33) {
        // Android 13+: Granular media permission
        PermissionStatus status = await Permission.audio.status;
        if (!status.isGranted) {
          status = await Permission.audio.request();
        }
        hasAudioPermission = status.isGranted;
      } else {
        // Android 12 aur neeche: Storage permission
        PermissionStatus status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        hasAudioPermission = status.isGranted;
      }
    } else if (Platform.isIOS) {
      // iOS: Media library for music files
      PermissionStatus status = await Permission.mediaLibrary.status;
      if (!status.isGranted) {
        status = await Permission.mediaLibrary.request();
      }
      hasAudioPermission = status.isGranted;
    } else {
      hasAudioPermission = false;
    }

    if (mounted) {
      setState(() {
        _hasPermissions = hasAudioPermission;
        _isLoading = false;
      });

      if (_hasPermissions) {
        await _loadMusic(); // Load music if granted
      } else {
        // Optional: User ko alert dikhao ya settings open karo
        print('Audio access denied');
        // if (await Permission.audio.shouldShowRequestRationale) { /* Show rationale */ }
        // await openAppSettings(); // Settings open karne ke liye
      }
    }
  }
  // Request audio permission for Android 14 (API 34)
  Future<void> _requestPermissions() async {
    final status = await Permission.audio.request();

    bool audioGranted = status.isGranted;

    if (mounted) {
      setState(() {
        _hasPermissions = audioGranted;
        _isLoading = false;
      });

      if (_hasPermissions) {
        await _loadMusic(); // Load music data when permission is granted
      } else if (status.isPermanentlyDenied) {
        // Open app settings if permission is permanently denied
        await openAppSettings();
      }
    }
  }

  // Function to load music data and refresh the screen
  Future<void> _loadMusic() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true; // Show loading indicator while fetching songs
        });
      }

      // Placeholder for loading music data
      // Example: Use on_audio_query to fetch songs
      // final OnAudioQuery audioQuery = OnAudioQuery();
      // List<SongModel> songs = await audioQuery.querySongs();
      // Update your state or provider with the songs
      print('Loading music data...');
      // Example: Update a provider or state management solution
      // Provider.of<MusicProvider>(context, listen: false).setSongs(songs);

      // Simulate a delay to mimic song loading
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        setState(() {
          _isLoading = false; // Hide loading indicator and refresh UI
          _hasPermissions = true; // Ensure UI shows the music tabs
        });
      }
    } catch (e) {
      print('Error loading music: $e');
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide loading indicator even on error
        });
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _isLoading
          ? Center(
        child:  CupertinoActivityIndicator(
          radius: 25,
          color: ColorSelect.maineColor,
          animating: true,
        ),
      )
          : ScrollConfiguration(
        behavior: const ConstantScrollBehavior(),
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _hasPermissions
                  ? PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
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
              )
                  : _buildPermissionDeniedCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
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
              Icon(
                Icons.lock_outline,
                color: Colors.red,
                size: 48.sp,
              ),
              SizedBox(height: 16.sp),
              Text(
                'Music Access Permission Required',
                style: GoogleFonts.poppins(
                  textStyle: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.sp),
              Text(
                'This app requires access to your music files to display offline songs. Please grant the necessary permissions.',
                style: GoogleFonts.poppins(
                  textStyle: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.sp),
              ElevatedButton(
                onPressed: () async {
                  await _requestPermissions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorSelect.maineColor,
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
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
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