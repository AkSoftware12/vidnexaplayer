import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Home/HomeBottomnavigation/home_bottomNavigation.dart';

class PermissionPage extends StatefulWidget {
  const PermissionPage({super.key});

  @override
  State<PermissionPage> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<PermissionPage> {
  @override
  void initState() {
    super.initState();
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(),
            Container(),
            Container(),
            Container(),


            Column(
              children: [

                SizedBox(
                    height: 130.sp,
                    width: 130.sp,
                    child: Image.asset('assets/appblue.png')),

                SizedBox(
                  height: 60.sp,
                ),


                Center(
                  child: Text('Grant Permission',
                    style: GoogleFonts.openSans(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,

                    ),

                  ),
                ),
                Padding(
                  padding:  EdgeInsets.all(5.sp),
                  child: Center(
                    child: Text('Please grant permission to access all \n  video files on your device ',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,

                      ),
                    ),
                  ),
                ),

                Center(
                  child: Padding(
                    padding:  EdgeInsets.only(top: 28.sp),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        SizedBox(),

                        Center(
                          child: Container(
                            width: 200.sp,
                            child: Row(
                              children: [

                                SizedBox(
                                  height: 20.sp,
                                    width: 20.sp,

                                    child: Image.asset('assets/video_camera.png',color: Colors.white,)),
                                // Icon(Icons.videocam, color: Colors.black,),

                                SizedBox(width: 25.sp,),
                                Text('All Video formats',
                                  style: GoogleFonts.openSans(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,

                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(),

                      ],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding:  EdgeInsets.only(top: 10.sp),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        SizedBox(),

                        Center(
                          child: Container(
                            width: 200.sp,
                            child: Row(
                              children: [
                                SizedBox(
                                    height: 20.sp,
                                    width: 20.sp,

                                    child: Image.asset('assets/subtitle.png',color: Colors.white,)),

                                SizedBox(width: 25.sp,),
                                Text('Subtitle files',
                                  style: GoogleFonts.openSans(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,

                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(),

                      ],
                    ),
                  ),
                ),
              ],
            ),


        Padding(
          padding:  EdgeInsets.only(left: 20.sp,right: 20.sp),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                width: double.infinity, // Full width
                height: 50, // Height 60
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [ColorSelect.maineColor, ColorSelect.maineColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(15), // Rounded corners with radius 30
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: () {
                      requestPermissions();
                    },
                    child: Center(
                      child: Text(
                        'ALL PERMISSION',
                        style: GoogleFonts.openSans(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,

                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap:(){

                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const HomeBottomNavigation(bottomIndex: 0,)),
                      );


                    },
                    child: SizedBox(
                      width: 100.sp,
                      child: Center(
                        child: Text('Not Now',
                          style:TextStyle(
                              color: ColorSelect.subtextColor,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 20.sp,
                  )
                ],
              ),
            ),

            Container(),


          ],
        ),
      ),
    );

  }
}
