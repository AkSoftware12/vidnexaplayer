// main.dart
// ✅ Safe FCM init (no crash), ✅ background handler top-level, ✅ proper order

import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/video_intent_service.dart';

import 'DarkMode/dark_mode.dart';
import 'Home/HomeScreen/home2.dart';
import 'SplashScreen/splash_screen.dart';
import 'LocalMusic/AudioServiceInit/audio_service_init.dart';
import 'NotifyListeners/AppBar/app_bar_color.dart';
import 'NotifyListeners/LanguageProvider/language_provider.dart';
import 'NotifyListeners/UserData/user_data.dart';
import 'ads/app_open_ad_manager.dart';
import 'app_globals.dart';

/// The single app-wide ad manager. Screens use `AppOpenAdManager()` which
/// returns this same instance; only main.dart is allowed to `init()` it.
final AppOpenAdManager appOpenManager = AppOpenAdManager();

// adb uninstall com.vidnexa.videoplayer
/// ✅ MUST be top-level + entry-point for background isolate
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Required in background isolate
  await Firebase.initializeApp();

  if (kDebugMode) {
    debugPrint('🔔 Background Message: ${message.messageId}');
    debugPrint('🔔 Title: ${message.notification?.title}');
    debugPrint('🔔 Data: ${message.data}');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Providers are created up-front so their persisted values can be restored
  // before the first frame (avoids a light→dark / en→hi flash).
  final themeProvider = ThemeProvider();
  final localeProvider = LocaleProvider();

  await _initCritical(themeProvider, localeProvider);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => AppBarColorProvider()),
        ChangeNotifierProvider.value(value: localeProvider),
        ChangeNotifierProvider(create: (_) => UserModel()),
        ChangeNotifierProvider(create: (_) => VideoProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Everything the first frame does NOT depend on runs after runApp, so the UI
  // appears immediately instead of after the whole stack has booted.
  unawaited(_initDeferred());
}

/// The minimum that must be ready before the first frame is painted.
///
/// Everything here is either needed to choose what to draw (theme/locale) or is
/// required by any screen that could appear first. The previous version awaited
/// Firebase, AdMob, Hive and FCM permissions here too — all sequentially — which
/// is what produced the `Davey! duration=1893ms` first frame and the
/// "Skipped 189 frames" burst at start-up.
Future<void> _initCritical(
  ThemeProvider themeProvider,
  LocaleProvider localeProvider,
) async {
  // Cheap, and picking the wrong theme/locale for one frame is a visible flash.
  await _guard('preferences', () async {
    await themeProvider.load();
    await localeProvider.load();
  });

  // Synchronous and required before any Player is constructed.
  _guardSync('media_kit', MediaKit.ensureInitialized);

  // These are independent of each other, so run them concurrently instead of
  // one after another.
  await Future.wait([
    // Music screens call AudioServiceInit.handler, so it must be up first.
    _guard('audio_service', AudioServiceInit.init),
    _guard('hive', () async {
      await Hive.initFlutter();
      if (!Hive.isBoxOpen('yt_cache')) {
        await Hive.openBox('yt_cache');
      }
    }),
    _guard('orientation', () async {
      await SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp],
      );
    }),
  ]);
}

/// Runs after the first frame. Nothing here blocks the UI.
Future<void> _initDeferred() async {
  await _guard('firebase', () async {
    // Options come from android/app/google-services.json (processed by the
    // com.google.gms.google-services Gradle plugin) instead of being hardcoded
    // in source.
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  });

  await Future.wait([
    _guard('ads', () async {
      await MobileAds.instance.initialize();

      // Device ids that should always receive test ads.
      //
      // Find a device's id in logcat — the SDK prints:
      //   I/Ads: Use RequestConfiguration.Builder().setTestDeviceIds(
      //            Arrays.asList("XXXXXXXX")) to get test ads on this device.
      //
      // Debug builds don't depend on this list (they use AdUnits' test unit
      // ids), but it still matters for release/profile testing on a handset.
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: const [
            'D55A05AC5F182B8B7343029E881273E8', // Samsung SM-A505F
            '05B5C242534D4508DE3D9FF83044AED8', // (older dev device)
          ],
        ),
      );

      appOpenManager.init();
    }),

    // FCM permission prompt + token fetch; nothing on screen waits for it.
    _guard('notifications', NotificationService().initNotifications),
  ]);
}

Future<void> _guard(String label, Future<void> Function() body) async {
  try {
    await body();
  } catch (e, st) {
    debugPrint('⚠️ init "$label" failed: $e');
    if (kDebugMode) debugPrint('$st');
  }
}

void _guardSync(String label, void Function() body) {
  try {
    body();
  } catch (e) {
    debugPrint('⚠️ init "$label" failed: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Only *fetch* the launch uri here. The splash screen opens it once Home is
    // on the stack — pushing the player straight onto the splash route meant
    // backing out of the video left the user staring at a dead splash screen,
    // and the splash's own pushReplacement then destroyed the player route.
    if (Platform.isAndroid) {
      VideoIntentService.fetchLaunchUri();
      VideoIntentService.startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Portal(
      child: Provider<RouteObserver<PageRoute<dynamic>>>.value(
        value: routeObserver,
        child: ScreenUtilInit(
          designSize: const Size(360, 690),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, __) {
            return Consumer2<ThemeProvider, LocaleProvider>(
              builder: (context, theme, localeProvider, _) {
                return MaterialApp(
                  debugShowCheckedModeBanner: false,
                  navigatorKey: navigatorKey,
                  navigatorObservers: [routeObserver],
                  title: 'Vidnexa Video Player',

                  theme: theme.lightTheme,
                  darkTheme: theme.darkTheme,
                  themeMode: theme.themeMode,

                  locale: localeProvider.locale,
                  supportedLocales: LocaleProvider.supported,
                  localizationsDelegates: const [
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],

                  // SplashScreen already builds its own Scaffold — wrapping it
                  // in another one nested two Scaffolds.
                  home: const SplashScreen(),
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
        debugPrint('✅ Permission status: ${settings.authorizationStatus}');
      }

      // ✅ Get token safely (SERVICE_NOT_AVAILABLE won't crash)
      final token = await _retryGetToken();
      if (kDebugMode) {
        debugPrint('✅ FCM Token: $token');
      }

      // ✅ Token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) debugPrint('🔁 FCM Token refreshed: $newToken');
        // TODO: send to backend or save prefs
      });

      // ✅ Foreground message
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('📩 Foreground message: ${message.messageId}');
          debugPrint('📩 Title: ${message.notification?.title}');
          debugPrint('📩 Data: ${message.data}');
        }
      });

      // ✅ When user taps notification & opens app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('👉 Notification opened: ${message.messageId}');
          debugPrint('👉 Data: ${message.data}');
        }
      });

      // ✅ If app was terminated and opened by notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null && kDebugMode) {
        debugPrint('🚀 Opened from terminated: ${initialMessage.messageId}');
      }
    } catch (e) {
      debugPrint('❌ FCM init failed: $e');
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
        if (kDebugMode) debugPrint('⚠️ getToken failed, retry in ${s}s: $e');
        await Future.delayed(Duration(seconds: s));
      }
    }
    return null;
  }
}
