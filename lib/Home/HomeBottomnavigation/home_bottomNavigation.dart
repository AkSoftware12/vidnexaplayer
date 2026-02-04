import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as badges;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:new_version_plus/new_version_plus.dart';
// import 'package:imagewidget/imagewidget.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/Photo/image_album.dart';
import 'package:videoplayer/Utils/color.dart';
import '../../DarkMode/dark_mode.dart';
import '../../DarkMode/styles/theme_data_style.dart';
import '../../DeviceSpace/device_space.dart';
import '../../Docouments/docouments.dart';
import '../../LocalMusic/MiniPlayer/mini_player.dart';
import '../../NetWork Stream/stream_video.dart';
import '../../Notification/notification.dart';
import '../../NotifyListeners/AppBar/app_bar_color.dart';
import '../../NotifyListeners/AppBar/colorList.dart';
import '../../NotifyListeners/UserData/user_data.dart';
import '../../Pdf/pdf_screen.dart';
import '../../SplashScreen/splash_screen.dart';
import '../../Utils/textSize.dart';
import '../../VideoPLayer/AllVideo/all_videos.dart';
import '../../app_store/app_store.dart';
import '../../main.dart';
import '../HomeScreen/home2.dart' hide navigatorKey;
import '../HomeScreen/home_screen.dart' hide navigatorKey;
import '../Me/me.dart';
import '../OfflineMusic/offline_music_tab.dart';
import '../YoutubeScreen/playlists_screen.dart';

class HomeBottomNavigation extends StatefulWidget {
  final int bottomIndex;

  const HomeBottomNavigation({super.key, this.bottomIndex = 0});

  @override
  State<HomeBottomNavigation> createState() => _HomeBottomNavigationState();
}

class _HomeBottomNavigationState extends State<HomeBottomNavigation> {
  final GlobalKey<CustomBottomBarState> bottomNavigationKey =
      GlobalKey<CustomBottomBarState>();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int currentPage = 0;
  String currentVersion = '';
  String release = "";
  String? userName;
  String userImage = "";

  // GlobalKey bottomNavigationKey = GlobalKey();

  void _toggleTheme(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDarkMode = !(prefs.getBool('isDarkMode') ?? false);
    prefs.setBool('isDarkMode', isDarkMode);
    (context as Element).markNeedsBuild();
  }



  @override
  void initState() {
    super.initState();
    checkForVersion(context);

    _getUsername();
    currentPage = widget.bottomIndex;

    final newVersion = NewVersionPlus(
      iOSId: 'com.vidnexa.videoplayer', androidId: 'com.vidnexa.videoplayer', androidPlayStoreCountry: "es_ES", androidHtmlReleaseNotes: true, //support country code
    );
    final ver = VersionStatus(
      appStoreLink: '',
      localVersion: '',
      storeVersion: '',
      releaseNotes: '',
      originalStoreVersion: '',
    );
    advancedStatusCheck(newVersion);

  }


  basicStatusCheck(NewVersionPlus newVersion) async {
    final version = await newVersion.getVersionStatus();
    if (version != null) {
      release = version.releaseNotes ?? "";
      setState(() {});
    }
    newVersion.showAlertIfNecessary(
      context: context,
      launchModeVersion: LaunchModeVersion.external,
    );
  }

  Future<void> advancedStatusCheck(NewVersionPlus newVersion) async {
    final status = await newVersion.getVersionStatus();
    if (status != null) {
      debugPrint(status.releaseNotes);
      debugPrint(status.appStoreLink);
      debugPrint(status.localVersion);
      debugPrint(status.storeVersion);
      debugPrint(status.canUpdate.toString());

      if (status.canUpdate) {
        // Show the custom dialog instead of the default showUpdateDialog
        showDialog(
          context: navigatorKey.currentContext!,
          barrierDismissible: false, // Matches allowDismissal: false
          builder: (BuildContext context) {
            return CustomUpgradeDialog(currentVersion: status.localVersion, newVersion: status.storeVersion, releaseNotes: [status.releaseNotes.toString()],);
          },
        );
      }
    }
  }
  Future<void> checkForVersion(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    return (await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                HexColor('#3b82f6'),
                ColorSelect.maineColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.all(20.sp),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Exit App',
                style: GoogleFonts.openSans(
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontSize: TextSizes.textlarge,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(height: 10.sp),
              Text(
                'Are you sure you want to exit the app?',
                style: GoogleFonts.openSans(
                  textStyle: TextStyle(
                    color: Colors.white70,
                    fontSize: TextSizes.textmedium,
                  ),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20.sp),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.sp,
                        vertical: 10.sp,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          color: Colors.purple,
                          fontSize: TextSizes.textmedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20.sp,
                        vertical: 10.sp,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Exit',
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: TextSizes.textmedium,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    )) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppBarColorProvider>(context, listen: false).loadColor();
    });

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        key: _scaffoldKey,
        // Assign the key to the Scaffold
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      _scaffoldKey.currentState?.openDrawer(); // Open the drawer
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.apps, color: Colors.black),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Folder icon button with purple background
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceSpaceScreen(),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            HexColor('#3b82f6'), // Purple
                            Colors.purple,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(Icons.folder, color: Colors.white),
                    ),
                  ),
                ],
              ),
              // Grid icon
              // SizedBox(
              //   height: 40.sp,
              //     child: Image.asset('assets/logo_blue_text.png')),

              Row(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => NotificationScreen(),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(Icons.notifications_none,
                              color: Colors.black),
                        ),
                      ),
                      // Positioned(
                      //   top: 0, // 👈 ye line badli
                      //   right: 0,
                      //   child: badges.Badge(
                      //     label: const Text(
                      //       '15',
                      //       style: TextStyle(color: Colors.white, fontSize: 10),
                      //     ),
                      //   ),
                      // )
                    ],
                  ),

                  const SizedBox(width: 0),

                ],
              ),
            ],
          ),
        ),

        body:Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: Center(
                child: _getPage(currentPage),
              ),
            ),

            const MiniPlayer(),   // 👈 YAHI ADD KARNA HAI
          ],
        ),
        bottomNavigationBar: CustomBottomBar(
          initialSelection: widget.bottomIndex,
          key: bottomNavigationKey,
          onTabChangedListener: (position) {
            setState(() {
              currentPage = position;
            });
          },
        ),
        drawer: Drawer(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            width: MediaQuery.sizeOf(context).width * .7,
            // backgroundColor: ColorSelect.maineColor,
            child: SettingsScreen(
              user: userName??'User Name',
              userImage: userImage, currentVersion: currentVersion,
            )),
      ),
    );
  }

  Widget _getPage(int page) {
    switch (page) {
      case 0:
        return DemoHomeScreen();
      case 1:
        return OfflineMusicTabScreen();
      case 2:
        return YouTubeTopPlaylists();
      case 3:
        return UserProfilePage();
      default:
        return HomeScreen(); // Fallback to HomeScreen
    }
  }

  void _getUsername() async {
    AppStore appStore = AppStore();
    String name = await appStore.getUserName();
    setState(() {
      userName = name;
    });
  }


}

class CustomBottomBar extends StatefulWidget {
  final int initialSelection;
  final ValueChanged<int> onTabChangedListener;
  final GlobalKey<CustomBottomBarState> key;

  const CustomBottomBar({
    required this.initialSelection,
    required this.onTabChangedListener,
    required this.key,
  }) : super(key: key);

  @override
  CustomBottomBarState createState() => CustomBottomBarState();
}

class CustomBottomBarState extends State<CustomBottomBar> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialSelection;
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index;
        });
        widget.onTabChangedListener(index);
      },
      backgroundColor: ColorSelect.maineColor2,
      selectedItemColor: ColorSelect.textcolor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: GoogleFonts.openSans(
        textStyle: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      unselectedLabelStyle: GoogleFonts.openSans(
        textStyle: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
      items: [
        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/home.svg',color: Colors.grey,),
          label: 'Home',

          activeIcon: Container(
            padding: EdgeInsets.all(5.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor,
              // Grey background for selected icon
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/home.svg',
              color: Colors.white,
            ),

            // Icon(Icons.account_circle, color: Colors.white),
          ),
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/music.svg',color: Colors.grey,),
          label: 'Music',
          activeIcon: Container(
            padding: EdgeInsets.all(3.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/music.svg',
              color: Colors.white,
            ),
          ),
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/online_video.svg',color: Colors.grey,),
          label: 'Online',
          activeIcon: Container(
            padding: EdgeInsets.all(3.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor,
              // Grey background for selected icon
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/online_video.svg',
              color: Colors.white,
            ),
          ),
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/account.svg',color: Colors.grey,),
          label: 'Profile',
          activeIcon: Container(
            padding: EdgeInsets.all(3.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor,
              // Grey background for selected icon
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/account.svg',
              color: Colors.white,
            ),

            // Icon(Icons.account_circle, color: Colors.white),
          ),
        ),
      ],
    );
  }
}




class SettingsScreen extends StatelessWidget {
  final String user;
  final String userImage;
  final String currentVersion;
  final TextSizes textSizes = TextSizes();

  SettingsScreen({
    super.key,
    required this.user,
    required this.userImage,
    required this.currentVersion,
  });

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel>(context);

    return Scaffold(
      body: Column(
        children: [
          SizedBox(height: 30.sp),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                  height: 50.sp,
                  child: Image.asset('assets/logo_blue_text.png')),
              Padding(
                padding: EdgeInsets.only(right: 10.sp),
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Icon(
                    Icons.close,

                    // FontAwesomeIcons.xmark,
                    color: Colors.black54,
                    size: 22.sp,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 0.sp),
          Container(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(10.sp),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      HexColor('#3b82f6'),
                      Colors.purple,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.all(10.sp),
                child: Row(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 50.sp,
                        height: 50.sp,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                        ),
                        child:user.imagePath != null
                            ? CircleAvatar(
                          radius: 60,
                          backgroundImage: FileImage(File(user.imagePath!)),
                        )
                            : const CircleAvatar(
                          radius: 60,
                          child: Icon(Icons.person, size: 60),
                        )),
                      ),

                    SizedBox(width: 10.sp),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          user.name != null
                              ? Text.rich(
                            TextSpan(
                              text: user.name,
                              style: GoogleFonts.radioCanada(
                                textStyle: TextStyle(
                                  color:
                                  Colors.white,
                                  fontSize: 17.sp,
                                  // Adjust font size as needed
                                  fontWeight:
                                  FontWeight
                                      .bold, // Adjust font weight as needed
                                ),
                              ),
                            ),
                            textAlign:
                            TextAlign
                                .start, // Ensure text starts at the beginning
                          )
                              : Text.rich(
                            TextSpan(
                              text: 'User',
                              style: GoogleFonts.radioCanada(
                                textStyle: TextStyle(
                                  color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  fontSize: 17.sp,
                                  // Adjust font size as needed
                                  fontWeight:
                                  FontWeight
                                      .bold, // Adjust font weight as needed
                                ),
                              ),
                            ),
                            textAlign:
                            TextAlign
                                .start, // Ensure text starts at the beginning
                          ),

                          Text(
                            'Premium Member',
                            style: GoogleFonts.radioCanada(
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: TextSizes.textsmall,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(
            thickness: 2.sp,
            color: Colors.grey,
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[

                // Drawer List
                ListTile(
                  leading: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#800000'),
                          HexColor('#800000'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: Icon(
                      Icons.apps,
                      color: Colors.white,
                    ),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Track Performance',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
                // SizedBox(height: 10.sp),
                // ListTile(
                //   leading: Container(
                //     height: 35.sp,
                //     width: 35.sp,
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(12),
                //       gradient: LinearGradient(
                //         colors: [
                //           HexColor('#9A6324'),
                //           HexColor('#9A6324'),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //     ),
                //     padding: EdgeInsets.all(10.sp),
                //     child: Image.asset('assets/videos_img.png'),
                //   ),
                //   title: Column(
                //     mainAxisAlignment: MainAxisAlignment.start,
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         'All Videos',
                //         style: GoogleFonts.openSans(
                //           textStyle: TextStyle(
                //             color: Colors.black,
                //             fontSize: TextSizes.textmedium14,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //       Text(
                //         'View counts and analytics',
                //         style: GoogleFonts.openSans(
                //           textStyle: TextStyle(
                //             color: Colors.grey,
                //             fontSize: 9.sp,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                //   onTap: () {
                //     Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (context) => AllVideosScreen(icon: 'AppBar',),
                //       ),
                //     );
                //   },
                // ),
                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    height: 35.sp,
                    width: 35.sp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#808000'),
                          HexColor('#808000'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: Image.asset('assets/image-gallery.png'),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Photos',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Captured Bliss',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    height: 35.sp,
                    width: 35.sp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#911eb4'),
                          HexColor('#911eb4'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: Image.asset('assets/music_img.png'),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Musics',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Melodic Echoes',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomeBottomNavigation(
                          bottomIndex: 1,
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    height: 35.sp,
                    width: 35.sp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#4363d8'),
                          HexColor('#4363d8'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: Image.asset('assets/link.img.png'),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VidStream',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Instant Video, One Click Away',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerStream(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    height: 35.sp,
                    width: 35.sp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#469990'),
                          HexColor('#469990'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: Image.asset('assets/folder_img.png'),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'File Manager',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'All Files, Anywhere, Anytime',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceSpaceScreen(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    height: 35.sp,
                    width: 35.sp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#dcbeff'),
                          HexColor('#dcbeff'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(0.sp),
                    child: Icon(Icons.notifications_none, color: Colors.white),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Stay Updated, Never Miss Out',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NotificationScreen(),
                      ),
                    );
                  },
                ),

                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#334155'),
                          HexColor('#334155'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: SvgPicture.asset(
                      'assets/privacy.svg',
                      color: Colors.white,
                    ),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Privacy',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Privacy & security',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () async {
                    final Uri _url = Uri.parse('https://www.freeprivacypolicy.com/live/3a47e749-0364-44f5-8cc3-559f2cd90336');
                    if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
                    throw 'Could not launch $_url';
                    }
                  },
                ),

                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    height: 35.sp,
                    width: 35.sp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.blue.shade50,
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: Icon(Icons.share,
                        color: Colors.blue, size: 17.sp),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share App',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'Invite your friends',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Share.share(
                      'Check out this Vidnexa Video Player App: https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer&pcampaignid=web_share',
                      subject: 'Download this App',
                    );
                  },
                ),
                // Extra space at the bottom for better scrolling
              ],
            ),
          ),

          Container(
            color: Colors.white,
            child: Padding(
              padding: EdgeInsets.all(3.sp),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  // gradient: LinearGradient(
                  //   colors: [
                  //     // HexColor('#3b82f6'),
                  //     ColorSelect.maineColor,
                  //     ColorSelect.maineColor,
                  //   ],
                  //   begin: Alignment.topLeft,
                  //   end: Alignment.bottomRight,
                  // ),
                ),
                padding: EdgeInsets.all(3.sp),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [


                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                              height: 25.sp,
                              child: Image.asset('assets/logo_blue_text.png',)),

                          Padding(
                            padding:  EdgeInsets.only(left: 27.sp),
                            child: Text(
                              'Version : $currentVersion',
                              style: GoogleFonts.radioCanada(
                                textStyle: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20.sp),
        ],
      ),
    );
  }
}

