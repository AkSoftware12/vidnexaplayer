import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoplayer/HexColorCode/HexColor.dart';
import 'package:videoplayer/Utils/color.dart';
import 'NotifyListeners/LanguageProvider/language_provider.dart';
import 'DarkMode/dark_mode.dart';
import 'Home/HomeBottomnavigation/home_bottomNavigation.dart';
import 'NotifyListeners/AppBar/app_bar_color.dart';
import 'NotifyListeners/UserData/user_data.dart';
import 'OnboardScreen/onboarding_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:new_version_plus/new_version_plus.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Platform.isAndroid
      ? await Firebase.initializeApp(
    options:
    kIsWeb || Platform.isAndroid
        ? const FirebaseOptions(
      apiKey: 'AIzaSyBXH-9NE0Q0VeQVRYkF0xMYeu12IMQ4EW0',
      appId: '1:1054442908505:android:b664773d6e1220246a3a48',
      messagingSenderId: '1054442908505',
      projectId: 'vidnexa-video-player-a69f8',
      storageBucket:
      "vidnexa-video-player-a69f8.firebasestorage.app",
    )
        : null,
  )
      : await Firebase.initializeApp();

  // FOR TESTING ONLY - Clear settings every time app starts
  // await Upgrader.clearSavedSettings(); // REMOVE this for release builds

  await NotificationService().initNotifications();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => AppBarColorProvider()),
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider(create: (context) => UserModel()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final RouteObserver<PageRoute> _routeObserver = RouteObserver();

  MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // final upgrader = Upgrader(
    //   debugDisplayAlways: false,
    //   countryCode: 'IN',
    // );


    return Portal(
      child: Provider.value(
        value: _routeObserver,
        child: ScreenUtilInit(
          designSize: const Size(360, 690),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, child) {
            return Consumer<LocaleProvider>(
              builder: (context, localeProvider, child) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  navigatorKey: navigatorKey,
                  navigatorObservers: [_routeObserver],
                  title: '',
                  theme: Provider.of<ThemeProvider>(context).themeDataStyle,
                  locale: localeProvider.locale,
                  supportedLocales: const [
                    Locale('en', ''), // English
                    Locale('hi', ' '), // Hindi
                  ],
                  home: Scaffold(
                    body:  AuthenticationWrapper(),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}



class AuthenticationWrapper extends StatefulWidget {
  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool loggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (loggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeBottomNavigation()));
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // इनिशियलाइज़ नोटिफिकेशन्स
  Future<void> initNotifications() async {
    // Android और iOS के लिए नोटिफिकेशन परमिशन रिक्वेस्ट करें
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (kDebugMode) {
      print('Permission granted: ${settings.authorizationStatus}');
    }

    // FCM टोकन प्राप्त करें
    String? token = await _firebaseMessaging.getToken();
    if (kDebugMode) {
      print('FCM Token: $token');
    }

    // फोरग्राउंड में नोटिफिकेशन्स हैंडल करें
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Foreground Message: ${message.notification?.title}');
        print('Message Data: ${message.data}');
      }
      // यहाँ आप नोटिफिकेशन UI दिखा सकते हैं (जैसे Flutter का SnackBar)
    });

    // बैकग्राउंड में नोटिफिकेशन हैंडल करें
    FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

    // ऐप बंद होने पर नोटिफिकेशन टैप करने पर हैंडल करें
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Message opened: ${message.notification?.title}');
      }
      // यहाँ नेविगेशन या अन्य एक्शन जोड़ सकते हैं
    });
  }

  // बैकग्राउंड हैंडलर (टॉप-लेवल फंक्शन)
  static Future<void> _backgroundHandler(RemoteMessage message) async {
    if (kDebugMode) {
      print('Background Message: ${message.notification?.title}');
    }
  }
}

/// 🎨 Custom Upgrade Dialog
/// 🎨 Custom Upgrade Dialog with improved UI

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

  Future<void> _launchStore() async {
    final Uri androidUri = Uri.parse(androidAppUrl);
    final Uri iosUri = Uri.parse(iosAppUrl);

    if (Theme.of(navigatorKey.currentContext!).platform == TargetPlatform.iOS) {
      if (await canLaunchUrl(iosUri)) {
        await launchUrl(iosUri, mode: LaunchMode.externalApplication);
      }
    } else {
      if (await canLaunchUrl(androidUri)) {
        await launchUrl(androidUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 20.sp),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25.sp)),
      elevation: 12,
      child: Container(
        constraints: BoxConstraints(maxWidth: 420),
        padding: EdgeInsets.all(25.sp),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [HexColor('#4A00E0'), HexColor('#8E2DE2')],
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
                      HexColor('#4A00E0').withOpacity(0.9),
                    ],
                    radius: 0.85,
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
                padding: EdgeInsets.all(20.sp),
                child: Icon(
                  Icons.rocket_launch_outlined,
                  size: 72.sp,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 10.sp),
              Text(
                "🚀 New Update Available!",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.4),
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
                  "A new version of Upgrader is available! Version $newVersion is now available - you have $currentVersion",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 10.sp),

              Center(
                child: Text(
                  " Would you like to update it now?",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // SizedBox(height: 15.sp),
              // Text(
              //   "A fresh version of this app is ready for you.\nUpdate now to enjoy the latest features and improvements!",
              //   style: GoogleFonts.poppins(
              //     color: Colors.white.withOpacity(0.9),
              //     fontSize: 13.sp,
              //     height: 1.5,
              //     fontWeight: FontWeight.w500,
              //   ),
              //   textAlign: TextAlign.center,
              // ),
              SizedBox(height: 10.sp),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(15.sp),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15.sp),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "What's New in Version $newVersion",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16.sp,
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
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13.sp,
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
              SizedBox(height: 25.sp),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: HexColor('#00008B'),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 28.sp, vertical: 14.sp),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20.sp),
                    side: BorderSide(color: Colors.white60, width: 1.sp),
                  ),
                ),
                icon: Icon(Icons.rocket_launch, size: 24.sp),
                label: Text(
                  "Update Now",
                  style: GoogleFonts.poppins(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () async {
                  await _launchStore();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// You need to define a global navigator key to access context outside widgets
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


