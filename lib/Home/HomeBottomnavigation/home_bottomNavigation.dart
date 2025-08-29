import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as badges;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:icons_plus/icons_plus.dart';
// import 'package:imagewidget/imagewidget.dart';
import 'package:instamusic/HexColorCode/HexColor.dart';
import 'package:instamusic/Utils/color.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upgrader/upgrader.dart';
import '../../DarkMode/dark_mode.dart';
import '../../DarkMode/styles/theme_data_style.dart';
import '../../DeviceSpace/device_space.dart';
import '../../NetWork Stream/stream_video.dart';
import '../../Notification/notification.dart';
import '../../NotifyListeners/AppBar/app_bar_color.dart';
import '../../NotifyListeners/AppBar/colorList.dart';
import '../../Photo/photo.dart';
import '../../Utils/textSize.dart';
import '../../VideoPLayer/AllVideo/all_videos.dart';
import '../../app_store/app_store.dart';
import '../HomeScreen/home_screen.dart';
import '../Me/me.dart';
import '../OfflineMusic/offline_music_tab.dart';

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
    _getUsername();
    currentPage = widget.bottomIndex;
    checkForVersion(context);
    // TESTING: Clear saved settings to force show upgrade dialog every time
    Upgrader.clearSavedSettings(); // Remove this line for production
  }

  Future<void> checkForVersion(BuildContext context) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    currentVersion = packageInfo.version;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppBarColorProvider>(context, listen: false).loadColor();
    });

    return Scaffold(
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
                    Positioned(
                      top: 0, // 👈 ye line badli
                      right: 0,
                      child: badges.Badge(
                        label: const Text(
                          '6',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                    )
                  ],
                ),

                const SizedBox(width: 16),

                // Profile picture with green dot
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const HomeBottomNavigation(
                                bottomIndex: 3,
                              )),
                    );
                  },
                  child: Stack(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        // If backgroundImage is not set or fails to load, the child (Icon) will be displayed
                        backgroundImage: NetworkImage(
                            'https://img.freepik.com/free-photo/young-bearded-man-with-striped-shirt_273609-5677.jpg'), // Uncomment and replace with your image path
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      body: UpgradeAlert(
        upgrader: Upgrader(
          debugLogging: true,
          debugDisplayAlways: true,
          debugDisplayOnce: true,
        ),
        child: Container(
          decoration: BoxDecoration(color: Colors.white),
          child: Center(
            child: _getPage(currentPage),
          ),
        ),
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
            user: userName??'',
            userImage: userImage,
          )),
    );
  }

  Widget _getPage(int page) {
    switch (page) {
      case 0:
        return HomeScreen();
      case 1:
        return OfflineMusicTabScreen();
      case 2:
        return AllVideosScreen();
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

  void _getUserimage() async {
    AppStore appStore = AppStore();
    String image = await appStore.getUserImage();
    setState(() {
      userImage = image;
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
      backgroundColor: Colors.white,
      selectedItemColor: ColorSelect.maineColor,
      unselectedItemColor: Colors.black,
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
          icon: SvgPicture.asset('assets/home.svg'),
          label: 'Home',
          activeIcon: Container(
            padding: EdgeInsets.all(3.sp),
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
          icon: SvgPicture.asset('assets/music.svg'),
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
          icon: SvgPicture.asset('assets/video_svg.svg'),
          label: 'Video',
          activeIcon: Container(
            padding: EdgeInsets.all(3.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor,
              // Grey background for selected icon
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/video_svg.svg',
              color: Colors.white,
            ),
          ),
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/account.svg'),
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
  final String currentVersion = "1.0.0"; // Example version, replace with actual version
  final TextSizes textSizes = TextSizes();

  SettingsScreen({
    super.key,
    required this.user,
    required this.userImage,
  });

  @override
  Widget build(BuildContext context) {
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
                        child: userImage.isNotEmpty
                            ? Image.asset('assets/avtar.jpg')
                            : Image.asset('assets/avtar.jpg'),
                      ),
                    ),
                    SizedBox(width: 10.sp),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user,
                            style: GoogleFonts.radioCanada(
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: TextSizes.textlarge,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                SizedBox(height: 10.sp),
                ListTile(
                  leading: Container(
                    height: 35.sp,
                    width: 35.sp,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          HexColor('#9A6324'),
                          HexColor('#9A6324'),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(10.sp),
                    child: Image.asset('assets/videos_img.png'),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All Videos',
                        style: GoogleFonts.openSans(
                          textStyle: TextStyle(
                            color: Colors.black,
                            fontSize: TextSizes.textmedium14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'View counts and analytics',
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
                        builder: (context) => AllVideosScreen(),
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
                        builder: (context) => SimpleExamplePage(),
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



                // SizedBox(height: 10.sp),
                // ListTile(
                //   leading: Container(
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(12),
                //       gradient: LinearGradient(
                //         colors: [
                //           HexColor('#2563eb'),
                //           HexColor('#2563eb'),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //     ),
                //     padding: EdgeInsets.all(10.sp),
                //     child: SvgPicture.asset(
                //       'assets/cleaner.svg',
                //       color: Colors.white,
                //     ),
                //   ),
                //   title: Column(
                //     mainAxisAlignment: MainAxisAlignment.start,
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         'Cleaner',
                //         style: GoogleFonts.openSans(
                //           textStyle: TextStyle(
                //             color: Colors.black,
                //             fontSize: TextSizes.textmedium14,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //       Text(
                //         'Clean junk files',
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
                //   onTap: () {},
                // ),
                // SizedBox(height: 10.sp),
                // ListTile(
                //   leading: Container(
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(12),
                //       gradient: LinearGradient(
                //         colors: [
                //           HexColor('#059669'),
                //           HexColor('#059669'),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //     ),
                //     padding: EdgeInsets.all(10.sp),
                //     child: SvgPicture.asset(
                //       'assets/game.svg',
                //       color: Colors.white,
                //     ),
                //   ),
                //   title: Column(
                //     mainAxisAlignment: MainAxisAlignment.start,
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         'Game',
                //         style: GoogleFonts.openSans(
                //           textStyle: TextStyle(
                //             color: Colors.black,
                //             fontSize: TextSizes.textmedium14,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //       Text(
                //         'Play mini games',
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
                //   onTap: () {},
                // ),
                // SizedBox(height: 10.sp),
                // ListTile(
                //   leading: Container(
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(12),
                //       gradient: LinearGradient(
                //         colors: [
                //           HexColor('#db2777'),
                //           HexColor('#db2777'),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //     ),
                //     padding: EdgeInsets.all(10.sp),
                //     child: SvgPicture.asset(
                //       'assets/languge.svg',
                //       color: Colors.white,
                //     ),
                //   ),
                //   title: Column(
                //     mainAxisAlignment: MainAxisAlignment.start,
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         'Language',
                //         style: GoogleFonts.openSans(
                //           textStyle: TextStyle(
                //             color: Colors.black,
                //             fontSize: TextSizes.textmedium14,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //       Text(
                //         'Change app language',
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
                //   onTap: () {},
                // ),
                // SizedBox(height: 10.sp),
                // ListTile(
                //   leading: Container(
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(12),
                //       gradient: LinearGradient(
                //         colors: [
                //           HexColor('#ca8a04'),
                //           HexColor('#ca8a04'),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //     ),
                //     padding: EdgeInsets.all(10.sp),
                //     child: SvgPicture.asset(
                //       'assets/theme.svg',
                //       color: Colors.white,
                //     ),
                //   ),
                //   title: Column(
                //     mainAxisAlignment: MainAxisAlignment.start,
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         'Theme',
                //         style: GoogleFonts.openSans(
                //           textStyle: TextStyle(
                //             color: Colors.black,
                //             fontSize: TextSizes.textmedium14,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //       Text(
                //         'Customize appearance',
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
                //   onTap: () {},
                // ),
                // SizedBox(height: 10.sp),
                // ListTile(
                //   leading: Container(
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(12),
                //       gradient: LinearGradient(
                //         colors: [
                //           HexColor('#d97706'),
                //           HexColor('#d97706'),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //     ),
                //     padding: EdgeInsets.all(10.sp),
                //     child: SvgPicture.asset(
                //       'assets/star.svg',
                //       color: Colors.white,
                //     ),
                //   ),
                //   title: Column(
                //     mainAxisAlignment: MainAxisAlignment.start,
                //     crossAxisAlignment: CrossAxisAlignment.start,
                //     children: [
                //       Text(
                //         'Premium',
                //         style: GoogleFonts.openSans(
                //           textStyle: TextStyle(
                //             color: Colors.black,
                //             fontSize: TextSizes.textmedium14,
                //             fontWeight: FontWeight.bold,
                //           ),
                //         ),
                //       ),
                //       Text(
                //         'Unlock all features',
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
                //   trailing: Container(
                //     padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                //     decoration: BoxDecoration(
                //       color: Colors.orange,
                //       borderRadius: BorderRadius.circular(10),
                //     ),
                //     child: Text(
                //       'PRO',
                //       style: TextStyle(color: Colors.white),
                //     ),
                //   ),
                //   onTap: () {},
                // ),
                //



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
                  gradient: LinearGradient(
                    colors: [
                      // HexColor('#3b82f6'),
                      ColorSelect.maineColor,
                      ColorSelect.maineColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: EdgeInsets.all(3.sp),
                child: Row(
                  children: [
                    SizedBox(width: 10.sp),

                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8.sp),
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey.shade200,
                            Colors.grey.shade200,
                            // HexColor('#3b82f6'), // Purple
                            // HexColor('#3b82f6'), // Purple
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding:  EdgeInsets.all(3.sp),
                      child: SizedBox(
                        height: 20.sp,
                          width: 20.sp,
                          child: Image.asset('assets/appblue.png', ))
                    ),
                    SizedBox(width: 10.sp),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              height: 25.sp,
                              child: Image.asset('assets/logo_blue_text.png',color: Colors.white,)),

                          Text(
                            '  Version : $currentVersion',
                            style: GoogleFonts.radioCanada(
                              textStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
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
          SizedBox(height: 0.sp),
        ],
      ),
    );
  }
}