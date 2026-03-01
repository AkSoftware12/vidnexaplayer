// main.dart (FULL)
// ✅ Safe FCM init (no crash), ✅ background handler top-level, ✅ proper order

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';

import 'DarkMode/dark_mode.dart';
import 'Home/HomeScreen/home2.dart';
import 'SplashScreen/splash_screen.dart';
import 'LocalMusic/AudioServiceInit/audio_service_init.dart';
import 'NotifyListeners/AppBar/app_bar_color.dart';
import 'NotifyListeners/LanguageProvider/language_provider.dart';
import 'NotifyListeners/UserData/user_data.dart';

// If you have these globals in some other file, keep using yours
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


// adb uninstall com.vidnexa.videoplayer
/// ✅ MUST be top-level + entry-point for background isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required in background isolate
  await Firebase.initializeApp();

  if (kDebugMode) {
    print('🔔 Background Message: ${message.messageId}');
    print('🔔 Title: ${message.notification?.title}');
    print('🔔 Data: ${message.data}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Any other init you do before Firebase is fine
  await AudioServiceInit.init();
  MediaKit.ensureInitialized();

  // ✅ Firebase init FIRST (before messaging setup)
  if (Platform.isAndroid) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBXH-9NE0Q0VeQVRYkF0xMYeu12IMQ4EW0',
        appId: '1:1054442908505:android:b664773d6e1220246a3a48',
        messagingSenderId: '1054442908505',
        projectId: 'vidnexa-video-player-a69f8',
        storageBucket: "vidnexa-video-player-a69f8.firebasestorage.app",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // ✅ Background handler register BEFORE runApp
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ✅ Ads init
  await MobileAds.instance.initialize();
  MobileAds.instance.updateRequestConfiguration(
    RequestConfiguration(
      testDeviceIds: const ['05B5C242534D4508DE3D9FF83044AED8'],
    ),
  );

  // ✅ Hive init
  await Hive.initFlutter();
  await Hive.openBox('yt_cache');

  // ✅ Lock portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ✅ Init notifications (safe, won't crash)
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
  final RouteObserver<PageRoute> _routeObserver = RouteObserver<PageRoute>();

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
                    Locale('hi', ''), // Hindi
                  ],
                  home: const Scaffold(
                    body: SplashScreen(),
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

  Future<void> initNotifications() async {
    try {
      // ✅ Request permission (Android 13+ and iOS)
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (kDebugMode) {
        print('✅ Permission status: ${settings.authorizationStatus}');
      }

      // ✅ Get token safely (SERVICE_NOT_AVAILABLE won't crash)
      final token = await _retryGetToken();
      if (kDebugMode) {
        print('✅ FCM Token: $token');
      }

      // ✅ Token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) print("🔁 FCM Token refreshed: $newToken");
        // TODO: send to backend or save prefs
      });

      // ✅ Foreground message
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('📩 Foreground message: ${message.messageId}');
          print('📩 Title: ${message.notification?.title}');
          print('📩 Body: ${message.notification?.body}');
          print('📩 Data: ${message.data}');
        }
        // TODO: show local notification/snackbar if you want
      });

      // ✅ When user taps notification & opens app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('👉 Notification opened: ${message.messageId}');
          print('👉 Title: ${message.notification?.title}');
          print('👉 Data: ${message.data}');
        }
        // TODO: navigate based on message.data
      });

      // ✅ If app was terminated and opened by notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null && kDebugMode) {
        print('🚀 Opened from terminated: ${initialMessage.messageId}');
        print('🚀 Data: ${initialMessage.data}');
      }
    } catch (e, st) {
      if (kDebugMode) {
        print("❌ FCM init failed: $e");
        print(st);
      }
      // Don't crash app
    }
  }

  Future<String?> _retryGetToken() async {
    const delays = [1, 2, 4]; // seconds
    for (final s in delays) {
      try {
        final t = await _firebaseMessaging.getToken();
        if (t != null && t.isNotEmpty) return t;
      } catch (e) {
        if (kDebugMode) print("⚠️ getToken failed, retry in ${s}s: $e");
        await Future.delayed(Duration(seconds: s));
      }
    }
    return null;
  }
}
