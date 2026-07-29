import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:new_version_plus/new_version_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/Photo/image_album.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:videoplayer/Utils/internet_banner.dart';
import 'package:videoplayer/Utils/rating_popup.dart';
import '../../DeviceSpace/device_space.dart';
import '../../LocalMusic/MiniPlayer/mini_player.dart';
import '../../NetWork Stream/stream_video.dart';
import '../../Notification/notification.dart';
import '../../NotifyListeners/AppBar/app_bar_color.dart';
import '../../NotifyListeners/UserData/user_data.dart';
import '../../SplashScreen/splash_screen.dart';
import '../../StatusSaverScreen/whatsapp_download.dart';
import '../../Utils/textSize.dart';
import '../../ads/app_open_ad_manager.dart';
import '../../app_store/app_store.dart';
import '../HomeScreen/home2.dart';
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
  final appOpenManager = AppOpenAdManager();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int currentPage = 0;
  String currentVersion = '';

  /// Guards against stacking exit dialogs on rapid back presses.
  bool _exitDialogOpen = false;

  String? userName;
  String userImage = "";

  // ================= EXIT DIALOG AD =================
  /// Banner ad shown inside the exit confirmation dialog.
  /// Loaded up-front in [initState] so it is ready the moment the
  /// user presses back — loading it lazily would show a blank space.
  BannerAd? _exitBannerAd;
  bool _isExitAdLoaded = false;

  void _loadExitAd() {
    _exitBannerAd = BannerAd(
      // TODO: Google TEST ad unit ID — release se pehle apni real ID lagana!
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      size: AdSize.mediumRectangle, // 300x250 — dialog ke liye best fit
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _isExitAdLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Exit banner failed: $error');
          ad.dispose();
          _exitBannerAd = null;
          _isExitAdLoaded = false;
        },
      ),
    )..load();
  }
  // ==================================================

  // NOTE: the old `_toggleTheme()` here was dead code that only wrote a
  // SharedPreferences flag and called `markNeedsBuild()` — it never told
  // ThemeProvider anything, so nothing on screen changed. The working toggle
  // lives in Home/Me/me.dart and goes through ThemeProvider.toggleTheme().

  @override
  void initState() {
    super.initState();

    checkForVersion();

    _getUsername();
    _loadExitAd(); // 👈 exit dialog ka ad pehle se load
    currentPage = widget.bottomIndex;

    final newVersion = NewVersionPlus(
      iOSId: 'com.vidnexa.videoplayer',
      androidId: 'com.vidnexa.videoplayer',
      androidPlayStoreCountry: "in",
      androidHtmlReleaseNotes: true,
    );

    advancedStatusCheck(newVersion);

    // ⭐ Rating prompt now lives HERE (on the home screen) as a bottom sheet,
    // instead of on the splash screen. A small delay lets the home settle (and
    // any update dialog resolve) before the sheet slides up.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await RatingPopup.onAppOpen(context);
    });
  }

  @override
  void dispose() {
    _exitBannerAd?.dispose();
    super.dispose();
  }

  Future<void> advancedStatusCheck(NewVersionPlus newVersion) async {
    try {
      final status = await newVersion.getVersionStatus();
      if (status == null || !status.canUpdate) return;

      // Use our own State's context — it is guaranteed to be mounted here.
      // (The old code used a navigatorKey that was never attached to any
      //  Navigator, so `currentContext!` threw as soon as an update existed.)
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => CustomUpgradeDialog(
          currentVersion: status.localVersion,
          newVersion: status.storeVersion,
          releaseNotes: [
            if (status.releaseNotes != null &&
                status.releaseNotes!.trim().isNotEmpty)
              status.releaseNotes!.trim()
            else
              'Bug fixes and performance improvements.',
          ],
        ),
      );
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  Future<void> checkForVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => currentVersion = packageInfo.version);
    } catch (e) {
      debugPrint('PackageInfo failed: $e');
    }
  }

  /// Shows the "exit app?" confirmation with a bounce-in animation,
  /// blurred backdrop and a banner ad inside the dialog.
  ///
  /// Called from [PopScope.onPopInvokedWithResult]; `WillPopScope` is never
  /// invoked with `android:enableOnBackInvokedCallback="true"` (Android 13+),
  /// which is why the dialog stopped appearing.
  Future<bool> _confirmExit() async {
    return (await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Exit',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        // Elastic bounce + fade + background blur
        final curvedValue = Curves.easeOutBack.transform(animation.value);
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 5 * animation.value,
            sigmaY: 5 * animation.value,
          ),
          child: Transform.scale(
            scale: curvedValue,
            child: Opacity(
              opacity: animation.value.clamp(0.0, 1.0),
              child: _buildExitDialog(context),
            ),
          ),
        );
      },
    )) ??
        false;
  }

  /// Clean white exit dialog — white background, black text,
  /// subtle border, red Exit button. Sirf ye method replace karo.
  Widget _buildExitDialog(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.sp),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          // Subtle grey border for clean outline
          border: Border.all(
            color: Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: EdgeInsets.all(18.sp),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in soft red circle
            Container(
              padding: EdgeInsets.all(12.sp),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.power_settings_new_rounded,
                color: Colors.redAccent,
                size: 28.sp,
              ),
            ),
            SizedBox(height: 12.sp),

            Text(
              'Exit App',
              style: GoogleFonts.openSans(
                textStyle: TextStyle(
                  color: Colors.black,
                  fontSize: TextSizes.textlarge,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 6.sp),
            Text(
              'Are you sure you want to exit the app?',
              style: GoogleFonts.openSans(
                textStyle: TextStyle(
                  color: Colors.black54,
                  fontSize: TextSizes.textmedium,
                ),
              ),
              textAlign: TextAlign.center,
            ),

            // Thin divider line for clean look
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.sp),
              child: Divider(
                color: Colors.black.withValues(alpha: 0.08),
                thickness: 1,
                height: 1,
              ),
            ),

            // ============ AD SECTION ============
            if (_isExitAdLoaded && _exitBannerAd != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                width: _exitBannerAd!.size.width.toDouble(),
                height: _exitBannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _exitBannerAd!),
              ),
              SizedBox(height: 16.sp),
            ],
            // ====================================

            Row(
              children: [
                // Cancel — outlined, white bg, black border & text
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.black.withValues(alpha: 0.3),
                        width: 1.4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 11.sp),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          color: Colors.black87,
                          fontSize: TextSizes.textmedium,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.sp),
                // Exit — solid RED bg, white text
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 6,
                      shadowColor: Colors.redAccent.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 11.sp),
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(
                      'Exit',
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: TextSizes.textmedium,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
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
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<AppBarColorProvider>(context, listen: false).loadColor();
    });

    return PopScope(
      // Block the automatic pop so we can ask first.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_exitDialogOpen) return; // ignore repeated back presses
        _exitDialogOpen = true;

        final bool shouldExit;
        try {
          shouldExit = await _confirmExit();
        } finally {
          _exitDialogOpen = false;
        }

        if (!shouldExit) return;

        // This screen is the ROOT route (splash used pushReplacement), so
        // `Navigator.pop()` has nothing to pop back to — it either no-ops or
        // leaves a black screen. `SystemNavigator.pop()` is what actually
        // hands control back to Android and closes the app.
        await SystemNavigator.pop();
      },
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

        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(color: Colors.white),
              child: Center(
                child: _getPage(currentPage),
              ),
            ),

            // 🌐 Internet on/off banner — floats at the top, non-blocking.
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: InternetStatusBanner(),
            ),
          ],
        ),

        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            appOpenManager.bannerWidgetBottomScreen(),

            const MiniPlayer(),   // 👈 YAHI ADD KARNA HAI

            /// 🔥 Bottom Navigation
            CustomBottomBar(
              initialSelection: widget.bottomIndex,
              key: bottomNavigationKey,
              onTabChangedListener: (position) {
                setState(() {
                  currentPage = position;
                });
              },
            ),

          ],
        ),

        drawer: Drawer(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            width: MediaQuery.sizeOf(context).width * .7,
            // backgroundColor: ColorSelect.maineColor,
            child: SettingsScreen(
              user: userName ?? 'User Name',
              userImage: userImage, currentVersion: currentVersion,
            )),
      ),
    );
  }

  Widget _getPage(int page) {
    switch (page) {
      case 0:
        return DemoHomeScreen();
    // case 1:
    //   return Container();
      case 1:
        return OfflineMusicTabScreen();
      case 2:
        return YouTubeTopPlaylists();
      case 3:
        return UserProfilePage();
      default:
        return DemoHomeScreen(); // Fallback to HomeScreen
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
          icon: SvgPicture.asset('assets/home.svg',colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),height: 20,width: 20,),
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
              colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              height: 20,width: 20,
            ),

            // Icon(Icons.account_circle, color: Colors.white),
          ),
        ),
        // BottomNavigationBarItem(
        //   icon: SvgPicture.asset('assets/downloader.svg',colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),height: 20,width: 20,),
        //   label: 'Downloader',
        //   activeIcon: Container(
        //     padding: EdgeInsets.all(5.sp),
        //     decoration: BoxDecoration(
        //       color: ColorSelect.maineColor,
        //       // Grey background for selected icon
        //       shape: BoxShape.circle,
        //     ),
        //     child: SvgPicture.asset(
        //       'assets/downloader.svg',
        //       color: Colors.white,
        //       height: 20,width: 20,
        //     ),
        //
        //     // Icon(Icons.account_circle, color: Colors.white),
        //   ),
        // ),

        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/music.svg',colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),height: 20,width: 20,),
          label: 'Music',
          activeIcon: Container(
            padding: EdgeInsets.all(3.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              'assets/music.svg',
              colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              height: 20,width: 20,
            ),
          ),
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/online_video.svg',colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),height: 20,width: 20,),
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
              colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              height: 20,width: 20,
            ),
          ),
        ),
        BottomNavigationBarItem(
          icon: SvgPicture.asset('assets/account.svg',colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),height: 20,width: 20,),
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
              colorFilter:
              const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              height: 20,width: 20,
            ),

            // Icon(Icons.account_circle, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  final String user;
  final String userImage;
  final String currentVersion;

  const SettingsScreen({
    super.key,
    required this.user,
    required this.userImage,
    required this.currentVersion,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isNightMode = false;
  String selectedTheme = "Blue";

  final List<Map<String, dynamic>> themes = [
    {"name": "Blue", "color": const Color(0xff2563EB)},
    {"name": "Purple", "color": const Color(0xff7C3AED)},
    {"name": "Green", "color": const Color(0xff059669)},
    {"name": "Orange", "color": const Color(0xffEA580C)},
  ];

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<UserModel>(context);

    return Scaffold(
      backgroundColor: isNightMode ? const Color(0xff0F172A) : const Color(0xffF6F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                children: [
                  _buildProfileCard(context, userModel),
                  SizedBox(height: 12.h),

                  _buildSectionTitle("Main Features"),
                  SizedBox(height: 6.h),

                  _buildSettingsTile(
                    context,
                    icon: Icons.dashboard_customize_rounded,
                    iconBg: const Color(0xff7C3AED),
                    title: 'Dashboard',
                    subtitle: 'Track Performance',
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    iconWidget: Image.asset(
                      'assets/image-gallery.png',
                      width: 15.w,
                      height: 15.w,
                      color: Colors.white,
                    ),
                    iconBg: const Color(0xffB45309),
                    title: 'All Photos',
                    subtitle: 'Captured Bliss',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AlbumScreen(),
                        ),
                      );
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    iconWidget: Image.asset(
                      'assets/music_img.png',
                      width: 15.w,
                      height: 15.w,
                      color: Colors.white,
                    ),
                    iconBg: const Color(0xff9333EA),
                    title: 'All Musics',
                    subtitle: 'Melodic Echoes',
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

                  _buildSettingsTile(
                    context,
                    iconWidget: Image.asset(
                      'assets/link.img.png',
                      width: 15.w,
                      height: 15.w,
                      color: Colors.white,
                    ),
                    iconBg: const Color(0xff2563EB),
                    title: 'VidStream',
                    subtitle: 'Instant Video, One Click Away',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VideoPlayerStream(),
                        ),
                      );
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    iconWidget: Image.asset(
                      'assets/folder_img.png',
                      width: 15.w,
                      height: 15.w,
                      color: Colors.white,
                    ),
                    iconBg: const Color(0xff0F766E),
                    title: 'File Manager',
                    subtitle: 'All Files, Anywhere, Anytime',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DeviceSpaceScreen(),
                        ),
                      );
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    icon: Icons.download_for_offline_rounded,
                    iconBg: const Color(0xff16A34A),
                    title: 'Status Saver',
                    subtitle: 'Save videos and images easily',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StatusSaverHomePage(),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 12.h),
                  _buildSectionTitle("Preferences"),
                  SizedBox(height: 6.h),

                  _buildSwitchTile(
                    context,
                    icon: Icons.dark_mode_rounded,
                    iconBg: const Color(0xff111827),
                    title: 'Night Mode',
                    subtitle: 'Comfortable viewing at night',
                    value: isNightMode,
                    onChanged: (val) {
                      setState(() {
                        isNightMode = val;
                      });
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    icon: Icons.color_lens_rounded,
                    iconBg: const Color(0xffF59E0B),
                    title: 'Theme',
                    subtitle: 'Choose app appearance',
                    onTap: () {
                      _showThemeBottomSheet(context);
                    },
                  ),

                  SizedBox(height: 12.h),
                  _buildSectionTitle("Support & More"),
                  SizedBox(height: 6.h),

                  _buildSettingsTile(
                    context,
                    icon: Icons.notifications_none_rounded,
                    iconBg: const Color(0xffEC4899),
                    title: 'Notifications',
                    subtitle: 'Stay Updated, Never Miss Out',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationScreen(),
                        ),
                      );
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    iconWidget: SvgPicture.asset(
                      'assets/privacy.svg',
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                      width: 15.w,
                      height: 15.w,
                    ),
                    iconBg: const Color(0xff334155),
                    title: 'Privacy',
                    subtitle: 'Privacy & security',
                    onTap: () async {
                      final Uri url = Uri.parse(
                        'https://www.freeprivacypolicy.com/live/3a47e749-0364-44f5-8cc3-559f2cd90336',
                      );
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        throw 'Could not launch $url';
                      }
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    icon: Icons.star_rate_rounded,
                    iconBg: const Color(0xffF97316),
                    title: 'Rate Us',
                    subtitle: 'Rate app on Play Store',
                    onTap: () async {
                      final Uri url = Uri.parse(
                        'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer',
                      );
                      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                        throw 'Could not launch $url';
                      }
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    icon: Icons.support_agent_rounded,
                    iconBg: const Color(0xff0EA5E9),
                    title: 'Help & Support',
                    subtitle: 'Get help when you need it',
                    onTap: () async {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'vidnexaplayer@gmail.com',
                        query: 'subject=Help & Support',
                      );
                      await launchUrl(emailLaunchUri);
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    icon: Icons.feedback_rounded,
                    iconBg: const Color(0xff8B5CF6),
                    title: 'Feedback',
                    subtitle: 'Share your thoughts with us',
                    onTap: () async {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'vidnexaplayer@gmail.com',
                        query: 'subject=App Feedback',
                      );
                      await launchUrl(emailLaunchUri);
                    },
                  ),

                  _buildSettingsTile(
                    context,
                    icon: Icons.share_rounded,
                    iconBg: const Color(0xff0284C7),
                    title: 'Share App',
                    subtitle: 'Invite your friends',
                    onTap: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text:
                          'Check out this Vidnexa Video Player App: https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer&pcampaignid=web_share',
                          subject: 'Download this App',
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 14.h),
                  _buildVersionCard(),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 8.h),
      child: Row(
        children: [
          SizedBox(
            height: 28.h,
            child: Image.asset('assets/logo_blue_text.png'),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              height: 32.h,
              width: 32.h,
              decoration: BoxDecoration(
                color: isNightMode ? const Color(0xff1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.close_rounded,
                color: isNightMode ? Colors.white : Colors.black87,
                size: 16.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16.r),
        gradient: const LinearGradient(
          colors: [
            Color(0xff2563EB),
            Color(0xff7C3AED),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff7C3AED).withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          user.imagePath != null
              ? CircleAvatar(
            radius: 22.r,
            backgroundImage: FileImage(File(user.imagePath!)),
          )
              : CircleAvatar(
            radius: 22.r,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Icon(
              Icons.person,
              size: 22.sp,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // `user.name` is non-nullable, so the old null check and `!`
                  // were dead code — only the emptiness check matters.
                  user.name.trim().isNotEmpty ? user.name : 'User',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.radioCanada(
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Premium Member',
                  style: GoogleFonts.openSans(
                    textStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w),
      child: Text(
        title,
        style: GoogleFonts.openSans(
          textStyle: TextStyle(
            color: isNightMode ? Colors.white : const Color(0xff0F172A),
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
      BuildContext context, {
        IconData? icon,
        Widget? iconWidget,
        required Color iconBg,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isNightMode ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        minLeadingWidth: 0,
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
        leading: Container(
          height: 34.h,
          width: 34.w,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Center(
            child: iconWidget ??
                Icon(
                  icon,
                  color: Colors.white,
                  size: 17.sp,
                ),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.openSans(
            textStyle: TextStyle(
              color: isNightMode ? Colors.white : const Color(0xff111827),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.openSans(
            textStyle: TextStyle(
              color: isNightMode ? Colors.white70 : Colors.grey.shade600,
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios_rounded,
          size: 12.sp,
          color: isNightMode ? Colors.white54 : Colors.grey.shade500,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSwitchTile(
      BuildContext context, {
        required IconData icon,
        required Color iconBg,
        required String title,
        required String subtitle,
        required bool value,
        required ValueChanged<bool> onChanged,
      }) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: isNightMode ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        minLeadingWidth: 0,
        dense: true,
        visualDensity: const VisualDensity(vertical: -2),
        contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
        leading: Container(
          height: 34.h,
          width: 34.w,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Center(
            child: Icon(
              icon,
              color: Colors.white,
              size: 17.sp,
            ),
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.openSans(
            textStyle: TextStyle(
              color: isNightMode ? Colors.white : const Color(0xff111827),
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.openSans(
            textStyle: TextStyle(
              color: isNightMode ? Colors.white70 : Colors.grey.shade600,
              fontSize: 8.5.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        trailing: Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildVersionCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isNightMode ? const Color(0xff1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 18.h,
            child: Image.asset('assets/logo_blue_text.png'),
          ),
          SizedBox(height: 5.h),
          Text(
            'Version : ${widget.currentVersion}',
            style: GoogleFonts.radioCanada(
              textStyle: TextStyle(
                color: isNightMode ? Colors.white70 : Colors.grey.shade700,
                fontSize: 8.8.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Theme : $selectedTheme',
            style: GoogleFonts.openSans(
              textStyle: TextStyle(
                color: isNightMode ? Colors.white54 : Colors.grey.shade500,
                fontSize: 8.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showThemeBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isNightMode ? const Color(0xff1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Theme",
                style: GoogleFonts.openSans(
                  textStyle: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: isNightMode ? Colors.white : Colors.black,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              ...themes.map((theme) {
                final bool isSelected = selectedTheme == theme["name"];
                return Container(
                  margin: EdgeInsets.only(bottom: 10.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14.r),
                    color: isSelected
                        ? (theme["color"] as Color).withValues(alpha: 0.12)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? theme["color"] as Color
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 10.r,
                      backgroundColor: theme["color"] as Color,
                    ),
                    title: Text(
                      theme["name"],
                      style: GoogleFonts.openSans(
                        textStyle: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: isNightMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: theme["color"] as Color)
                        : null,
                    onTap: () {
                      setState(() {
                        selectedTheme = theme["name"];
                      });
                      Navigator.pop(context);
                    },
                  ),
                );
              }).toList(),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }
}