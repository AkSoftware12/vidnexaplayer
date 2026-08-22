import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Home/HomeBottomnavigation/home_bottomNavigation.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/profile_strings.dart';

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
  bool _requesting = false;

  /// Permissions this app genuinely needs, chosen per Android version.
  ///
  /// Deliberately excludes `Permission.camera` (a video player has no camera
  /// feature) and `Permission.manageExternalStorage` (All-Files Access needs a
  /// Play Console declaration and is not required to read media).
  Future<List<Permission>> _requiredPermissions() async {
    if (!Platform.isAndroid) {
      return [Permission.photos, Permission.videos, Permission.notification];
    }

    final info = await DeviceInfoPlugin().androidInfo;
    final sdk = info.version.sdkInt;

    if (sdk >= 33) {
      // Android 13+: granular media permissions.
      return [
        Permission.videos,
        Permission.audio,
        Permission.photos,
        Permission.notification,
      ];
    }

    // Android 12 and below: the single legacy storage permission.
    return [Permission.storage, Permission.notification];
  }

  Future<void> requestPermissions() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    try {
      final permissions = await _requiredPermissions();
      final Map<Permission, PermissionStatus> statuses =
          await permissions.request();

      // `statuses[p]` can legitimately be absent on some platforms — the old
      // code used `statuses[p]!` and crashed there.
      final denied = permissions
          .where((p) => !(statuses[p]?.isGranted ?? false))
          // A missing notification permission should not block the app.
          .where((p) => p != Permission.notification)
          .toList();

      final permanentlyDenied = denied
          .any((p) => statuses[p]?.isPermanentlyDenied ?? false);

      if (!mounted) return;

      if (denied.isEmpty) {
        // ✅ Everything granted — this is the success path. The old code did
        // nothing here, so users who granted permissions were stuck on this
        // screen forever while users who denied them got sent to the home page.
        await _continueToApp();
        return;
      }

      if (permanentlyDenied) {
        await _showOpenSettingsDialog();
        return;
      }

      if (!mounted) return;
      final lang = context.read<LocaleProvider>().locale.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ProfileStrings.t(lang, 'perm_media_access_snackbar'),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Permission request failed: $e');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  /// Marks onboarding complete and replaces this route with the home screen.
  Future<void> _continueToApp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Historical key name; means "onboarding finished".
      await prefs.setBool('isLoggedIn', true);
    } catch (_) {
      // Non-fatal — worst case onboarding shows once more.
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const HomeBottomNavigation(bottomIndex: 0),
      ),
    );
  }

  /// Actually opens app settings — the old `openAppSettingsDialog()` just
  /// navigated to the home screen despite its name.
  Future<void> _showOpenSettingsDialog() async {
    final lang = context.read<LocaleProvider>().locale.languageCode;
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ProfileStrings.t(lang, 'perm_permission_needed_title')),
        content: Text(
          ProfileStrings.t(lang, 'perm_permission_needed_body'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ProfileStrings.t(lang, 'perm_not_now')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ProfileStrings.t(lang, 'perm_open_settings')),
          ),
        ],
      ),
    );

    if (open == true) {
      await openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
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
                          width: MediaQuery.of(context).size.width * 0.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha:0.2),
                                blurRadius: 20.sp,
                                offset: Offset(0, 1.sp),
                              ),
                            ],
                          ),

                          child:Lottie.asset('assets/permisssion.json'),

                        ),
                      ),

                    ),

                    // Logo with subtle shadow
                    // SizedBox(height: 40.sp),

                    // Title
                    Text(
                      t('perm_grant_permissions_title'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2.sp),

                    // Subtitle
                    Text(
                      t('perm_grant_permissions_sub'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.openSans(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 20.sp),

                    // Features section with cards
                    _buildFeatureCard(
                      iconPath: 'assets/video_camera.png',
                      title: t('perm_all_video_formats_title'),
                      subtitle: t('perm_all_video_formats_sub'),
                    ),
                    SizedBox(height: 10.sp),
                    _buildFeatureCard(
                      iconPath: 'assets/subtitle.png',
                      title: t('perm_subtitle_files_title'),
                      subtitle: t('perm_subtitle_files_sub'),
                    ),
                    SizedBox(height: 50.sp),

                    // Grant Permissions Button

                    FadeInUp(
                      duration: const Duration(milliseconds: 1500),
                      child:  Padding(
                        padding:  EdgeInsets.all(10.sp),
                        child: SizedBox(
                          width: double.infinity,
                          height: 45.sp,

                          child: TextButton(
                            onPressed: _requesting ? null : requestPermissions,
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
                                if (_requesting)
                                  SizedBox(
                                    height: 17.sp,
                                    width: 17.sp,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                else
                                  Icon(Icons.security, size: 17.sp),
                                SizedBox(width: 8.sp),
                                Text(
                                  t('perm_grant_all_button'),
                                  style: GoogleFonts.openSans(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),



                    SizedBox(height: 15.sp),

                    // Not Now Option
                    GestureDetector(
                      // Also marks onboarding as done — the old version skipped
                      // straight to home without setting the flag, so onboarding
                      // reappeared on every launch.
                      onTap: _continueToApp,
                      child: Text(
                        t('perm_skip_for_now'),
                        style: GoogleFonts.openSans(
                          fontSize: 13.sp,
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
        color: HexColor('#0A1A3F').withValues(alpha:0.8),
        borderRadius: BorderRadius.circular(16.sp),
        border: Border.all(color: Colors.white.withValues(alpha:0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.2),
            blurRadius: 10.sp,
            offset: Offset(0, 4.sp),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(7.sp),
            decoration: BoxDecoration(
              color: ColorSelect.maineColor.withValues(alpha:0.2),
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
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.openSans(
                    fontSize: 10.sp,
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