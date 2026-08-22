import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoplayer/Utils/color.dart';
import 'package:videoplayer/Utils/string.dart';
import '../HexColorCode/HexColor.dart';
import '../Home/HomeBottomnavigation/home_bottomNavigation.dart';
import '../LocalMusic/AUDIOCONTROLLER/global_audio_controller.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/profile_strings.dart';
import '../OnboardScreen/onboarding_screen.dart';
import '../VideoPLayer/4kPlayer/4k_player.dart';
import '../ads/app_open_ad_manager.dart';
import '../video_intent_service.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Singleton — owned and initialised by main.dart, never disposed here.
  final AppOpenAdManager _adManager = AppOpenAdManager();

  Timer? _startTimer;

  @override
  void initState() {
    super.initState();

    _startTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _adManager.showAdIfAvailable(() async {
        // Rating prompt moved to the home screen (shown there as a bottom
        // sheet). Splash now just continues into the app.
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        await checkLoginStatus();
      });
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    super.dispose();
  }

  Future<void> checkLoginStatus() async {
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    // Historical key name — it actually means "onboarding already completed".
    // Kept as-is so existing installs don't get shown onboarding again.
    final onboardingDone = prefs.getBool('isLoggedIn') ?? false;

    if (!mounted) return;

    final navigator = Navigator.of(context);

    // Not awaited: pushReplacement's Future only completes once the pushed
    // route (Home) is later POPPED, not once it finishes pushing — Home is
    // the app's root route and is essentially never popped, so awaiting it
    // here silently stalled everything below forever, including the pending
    // video push.
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => onboardingDone
            ? const HomeBottomNavigation()
            : const OnboardingScreen(),
      ),
    );

    // From this point on, a proactively-pushed video (native "Open with"
    // arriving while the app is already alive) is safe to push directly —
    // see VideoIntentService._bootComplete for why that matters.
    VideoIntentService.markBootComplete();

    // If the app was launched via "Open with", open the media on top of Home so
    // pressing back returns to the app instead of an empty splash route.
    final pending = VideoIntentService.consumePendingVideo();
    if (pending == null) return;
    // The native side also proactively pushes "newVideoIntent" now — in a
    // narrow boot-timing race both this poll-based path and that push could
    // otherwise deliver the same uri and open the player twice.
    if (!VideoIntentService.claimForOpening(pending.uri)) return;

    debugPrint('OPEN WITH URI => ${pending.uri} (${pending.mimeType})');

    if (pending.isAudio) {
      // Home was just pushed above — play in the mini player there instead
      // of opening the full-screen video player.
      unawaited(
        GlobalAudioController().playExternalUri(pending.uri, title: pending.name),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => FullScreenVideoPlayerFixed(
          videos: const [],
          initialIndex: 0,
          // media_kit opens content:// and file:// uris directly.
          initialUrl: pending.uri,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorSelect.maineColor2,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo image
            Container(
              height: 130.sp,
              width: 130.sp,
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(20))
              ),
              child: Padding(
                padding:  EdgeInsets.all(20.sp),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20.sp),

                  child: Image.asset(
                    'assets/appblue.png',
                    width: 100.sp,
                    height: 100.sp,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.sp), // Spacing between logo and app name
            // App name
            Text(
            AppConstants.appName, // Replace with your app name
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text for contrast
              ),
            ),

            SizedBox(height: 20.sp), // Spacing before loader
            const CupertinoActivityIndicator(
              radius: 10,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}


class CustomUpgradeDialog extends StatelessWidget {
  final String androidAppUrl = 'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer&pcampaignid=web_share';
  final String iosAppUrl = 'https://apps.apple.com/app/idYOUR_IOS_APP_ID'; // Replace with your iOS app URL
  final String currentVersion; // Old version
  final String newVersion; // New version
  final List<String> releaseNotes; // Release notes

  const CustomUpgradeDialog({
    Key? key,
    required this.currentVersion,
    required this.newVersion,
    required this.releaseNotes,
  }) : super(key: key);

  /// Opens the correct store listing.
  ///
  /// Uses [defaultTargetPlatform] instead of `Theme.of(context).platform` so it
  /// never depends on a context that may already be gone.
  Future<void> _launchStore(BuildContext context) async {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    final Uri uri = Uri.parse(isIOS ? iosAppUrl : androidAppUrl);

    bool opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      final lang = context.read<LocaleProvider>().locale.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ProfileStrings.t(lang, 'splash_could_not_open_store'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    String t(String key) => ProfileStrings.t(lang, key);
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 20.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.sp)),
      elevation: 12,
      child: Container(
        constraints: BoxConstraints(maxWidth: 420),
        padding: EdgeInsets.all(25.sp),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ColorSelect.maineColor2,ColorSelect.maineColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(25.sp),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      HexColor('#FFFFFF'),
                      ColorSelect.maineColor2.withValues(alpha:0.9),
                    ],
                    radius: 0.55,
                    center: Alignment.center,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white60,
                      blurRadius: 30,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                padding: EdgeInsets.all(10.sp),
                child: Icon(
                  Icons.rocket_launch_outlined,
                  size: 52.sp,
                  color: ColorSelect.maineColor2,
                ),
              ),
              SizedBox(height: 10.sp),
              Text(
                t('splash_new_update_available'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha:0.4),
                      offset: Offset(1, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10.sp),
              Center(
                child: Text(
                  t('splash_update_body')
                      .replaceAll('{new}', newVersion)
                      .replaceAll('{current}', currentVersion),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 5.sp),

              Center(
                child: Text(
                  t('splash_update_prompt'),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              SizedBox(height: 5.sp),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10.sp),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(15.sp),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('splash_whats_new').replaceAll('{version}', newVersion),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 10.sp),
                    ...releaseNotes.asMap().entries.map((entry) => Padding(
                      padding: EdgeInsets.only(bottom: 8.sp),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "• ",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha:0.9),
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
              SizedBox(height: 15.sp),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor:ColorSelect.maineColor,
                  foregroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 28.sp, vertical: 12.sp),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.sp),
                    side: BorderSide(color: Colors.white, width: 1.sp),
                  ),
                ),
                icon: Icon(Icons.rocket_launch, size: 20.sp,color: Colors.white,),
                label: Text(
                  t('splash_update_now').toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white
                  ),
                ),
                onPressed: () async {
                  await _launchStore(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}