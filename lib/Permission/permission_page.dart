import 'package:animate_do/animate_do.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Home/HomeBottomnavigation/home_bottomNavigation.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _PermissionPageState();
}

class _PermissionPageState extends State<PermissionPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.photos,
      Permission.videos,
      Permission.notification,
      Permission.storage,
      Permission.manageExternalStorage,
      Permission.audio,
    ].request();

    if (statuses[Permission.camera]!.isGranted &&
        statuses[Permission.photos]!.isGranted &&
        statuses[Permission.videos]!.isGranted &&
        statuses[Permission.notification]!.isGranted &&
        statuses[Permission.storage]!.isGranted&&
        statuses[Permission.audio]!.isGranted &&
        statuses[Permission.manageExternalStorage]!.isGranted)

    {



      // All permissions are granted
      print("All permissions are granted");
    } else {

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setBool('isLoggedIn', true);
      // One or more permissions are denied
      openAppSettingsDialog();
    }
  }
  void openAppSettingsDialog() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeBottomNavigation(bottomIndex: 0,)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor('#081740'),
      body: SingleChildScrollView(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.sp),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Hero(
                        tag: 'app_logo',
                        child: Container(
                          height: MediaQuery.of(context).size.height * 0.4,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 20.sp,
                                offset: Offset(0, 1.sp),
                              ),
                            ],
                          ),

                          child:Lottie.asset('assets/permisssion.json'),

                          // child: ClipOval(
                          //   child:Lottie.asset('assets/permission.json'),
                          //
                          //   // Image.asset(
                          //   //   'assets/appblue.png',
                          //   //   fit: BoxFit.cover,
                          //   // ),
                          // ),
                        ),
                      ),

                    ),

                    // Logo with subtle shadow
                    // SizedBox(height: 40.sp),

                    // Title
                    Text(
                      'Grant Permissions',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2.sp),

                    // Subtitle
                    Text(
                      'Please grant access to all video files on your device for the best experience',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 20.sp),

                    // Features section with cards
                    _buildFeatureCard(
                      iconPath: 'assets/video_camera.png',
                      title: 'All Video Formats',
                      subtitle: 'Support for MP4, AVI, MKV & more',
                    ),
                    SizedBox(height: 10.sp),
                    _buildFeatureCard(
                      iconPath: 'assets/subtitle.png',
                      title: 'Subtitle Files',
                      subtitle: 'SRT, ASS, VTT & embedded subs',
                    ),
                    SizedBox(height: 50.sp),

                    // Grant Permissions Button

                    FadeInUp(
                      duration: const Duration(milliseconds: 1500),
                      child:  Padding(
                        padding:  EdgeInsets.all(10.sp),
                        child: SizedBox(
                          width: double.infinity,
                          height: 55.sp,

                          child: TextButton(
                            onPressed: requestPermissions,
                            style: TextButton.styleFrom(
                              backgroundColor: HexColor('#008000'),
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(60.sp),
                                side: const BorderSide(color: Colors.white, width: 1),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.security, size: 20.sp),
                                SizedBox(width: 8.sp),
                                Text(
                                  'Grant All Permissions',
                                  style: GoogleFonts.openSans(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),



                    SizedBox(height: 35.sp),

                    // Not Now Option
                    GestureDetector(
                      onTap: () async {

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const HomeBottomNavigation(bottomIndex: 0,)),
                        );
                      },
                      child: Text(
                        'Skip for now ',
                        style: GoogleFonts.openSans(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: ColorSelect.subtextColor,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    SizedBox(height: 50.sp),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String iconPath,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(8.sp),
      decoration: BoxDecoration(
        color: HexColor('#0A1A3F').withOpacity(0.8),
        borderRadius: BorderRadius.circular(16.sp),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10.sp,
            offset: Offset(0, 4.sp),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.sp),
            ),
            child: Image.asset(
              iconPath,
              height: 20.sp,
              width: 20.sp,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 16.sp),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.openSans(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.openSans(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}