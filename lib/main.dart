import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'Home/HomeScreen/home2.dart';
import 'LocalMusic/AudioServiceInit/audio_service_init.dart';
import 'NotifyListeners/LanguageProvider/language_provider.dart';
import 'DarkMode/dark_mode.dart';
import 'NotifyListeners/AppBar/app_bar_color.dart';
import 'NotifyListeners/UserData/user_data.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'SplashScreen/splash_screen.dart';
import 'ads/app_open_ad_manager.dart';



// adb uninstall com.vidnexa.videoplayer


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioServiceInit.init();
  MediaKit.ensureInitialized();
  await MobileAds.instance.initialize();
  // ✅ MARK DEVICE AS TEST (PRODUCTION IDS SAFE)
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      testDeviceIds: [
        '05B5C242534D4508DE3D9FF83044AED8',
      ],
    ),
  );
  await Hive.initFlutter();
  await Hive.openBox('yt_cache'); // ✅ box open once
  // 🔒 Lock entire app in Portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
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
        ChangeNotifierProvider(create: (_) => VideoProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  final RouteObserver<PageRoute> _routeObserver = RouteObserver();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
                  home: const Scaffold(
                    body:  SplashScreen(),
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






