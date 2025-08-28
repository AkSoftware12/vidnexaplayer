import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:instamusic/Utils/color.dart';
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

class _DashBoardScreenState extends State<OfflineMusicTabScreen> with SingleTickerProviderStateMixin {
  PageController _pageController = PageController(initialPage: 0);
  int _selectedIndex = 0;
  bool isLiked = false;
  bool download = false;
  int selectIndex = 0;
  bool _hasPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      PermissionStatus status;

      if (Platform.isAndroid) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo? androidInfo;

        try {
          androidInfo = await deviceInfo.androidInfo;
        } catch (e) {
          print('Error getting Android device info: $e');
          setState(() {
            _hasPermission = false;
            _isLoading = false;
          });
          _showPermissionDeniedDialog();
          return;
        }

        if (androidInfo.version.sdkInt >= 33) {
          status = await Permission.audio.status;
          if (!status.isGranted) {
            status = await Permission.audio.request();
          }
        } else {
          status = await Permission.storage.status;
          if (!status.isGranted) {
            status = await Permission.storage.request();
          }
        }
      } else {
        status = await Permission.audio.status;
        if (!status.isGranted) {
          status = await Permission.audio.request();
        }
      }

      setState(() {
        _hasPermission = status.isGranted;
        _isLoading = false;
      });

      if (!status.isGranted || status.isPermanentlyDenied) {
        _showPermissionDeniedDialog();
      }
    } catch (e) {
      print('Error checking permissions: $e');
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      _showPermissionDeniedDialog();
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
                // if (Navigator.canPop(context)) {
                //   Navigator.pop(context);
                // }
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: CircularProgressIndicator(
            color: ColorSelect.maineColor,
          ),
        ),
      );
    }

    if (!_hasPermission) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Music Access Permission Required',
                style: GoogleFonts.poppins(
                  fontSize: TextSizes.textlarge,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              SizedBox(height: 20.sp),
              ElevatedButton(
                onPressed: _checkPermissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorSelect.maineColor,
                  padding: EdgeInsets.symmetric(horizontal: 20.sp, vertical: 10.sp),
                ),
                child: Text(
                  'Request Permission',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: TextSizes.textmedium,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: EdgeInsets.all(0.0),
          child: SizedBox(
            height: 40.sp,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                GestureDetector(
                  onTap: () {
                    _onItemTapped(0);
                  },
                  child: Card(
                    color: _selectedIndex == 0
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Songs',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: _selectedIndex == 0
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
                ),
                GestureDetector(
                  onTap: () {
                    _onItemTapped(1);
                  },
                  child: Card(
                    color: _selectedIndex == 1
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Artists',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: _selectedIndex == 1
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
                ),
                GestureDetector(
                  onTap: () {
                    _onItemTapped(2);
                  },
                  child: Card(
                    color: _selectedIndex == 2
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Albums',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: _selectedIndex == 2
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
                ),
                GestureDetector(
                  onTap: () {
                    _onItemTapped(3);
                  },
                  child: Card(
                    color: _selectedIndex == 3
                        ? ColorSelect.maineColor
                        : Colors.white,
                    child: SizedBox(
                      width: 80.sp,
                      child: Padding(
                        padding: EdgeInsets.all(8.sp),
                        child: Center(
                          child: Text(
                            'Genres',
                            style: GoogleFonts.poppins(
                              textStyle: TextStyle(
                                color: _selectedIndex == 3
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
                ),
              ],
            ),
          ),
        ),
      ),
      body: PageView(
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
      ),
    );
  }

  @override
  void dispose() {
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