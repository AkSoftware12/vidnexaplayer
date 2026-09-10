// main.dart
// ✅ Safe FCM init (no crash), ✅ background handler top-level, ✅ proper order

import 'dart:async';
import 'dart:io';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_portal/flutter_portal.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:videoplayer/Analytics/screen_analytics.dart';
import 'package:videoplayer/Notification/local_notifications.dart';
import 'package:videoplayer/Notification/notification_store.dart';
import 'package:videoplayer/Utils/app_palette.dart';
import 'package:videoplayer/video_intent_service.dart';

import 'DarkMode/dark_mode.dart';
import 'Home/HomeScreen/home2.dart';
import 'SplashScreen/splash_screen.dart';
import 'LocalMusic/AudioServiceInit/audio_service_init.dart';
import 'NotifyListeners/AppBar/app_bar_color.dart';
import 'NotifyListeners/LanguageProvider/language_provider.dart';
import 'NotifyListeners/UserData/user_data.dart';
import 'Billing/billing_service.dart';
import 'ads/app_open_ad_manager.dart';
import 'app_globals.dart';
import 'features/equalizer/audio_effects_service.dart';

/// The single app-wide ad manager. Screens use `AppOpenAdManager()` which
/// returns this same instance; only main.dart is allowed to `init()` it.
final AppOpenAdManager appOpenManager = AppOpenAdManager();

/// App-wide Analytics handle. Screens import this from main.dart to log their
/// own events, e.g. `analytics.logEvent(name: 'video_played', ...)`.
final FirebaseAnalytics analytics = FirebaseAnalytics.instance;

/// Wired into MaterialApp.navigatorObservers below. This is what produces the
/// "Screens" report in the Firebase console — it fires screen_view on every
/// push/pop, using RouteSettings.name as the screen name, AND a `screen_time`
/// event carrying how long the user stayed on it. Routes pushed without a
/// `settings:` name report as null and are useless in the report, so every
/// Navigator.push in the app should pass one.
///
/// This replaces FirebaseAnalyticsObserver: it logs the same screen_view plus
/// the duration, so keeping both would double-count every screen.
final ScreenAnalyticsObserver analyticsObserver = ScreenAnalyticsObserver();

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

  // Runs in its own isolate, so this writes straight to SharedPreferences —
  // there is no app state here to hand it to.
  await NotificationStore.instance.add(message);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Belt and braces for the font crashes. Every call site now uses a bundled
  // family (see pubspec `fonts:`), but if one is ever missed — or a package
  // reaches for google_fonts itself — this makes it fall back to the default
  // face instead of doing an HTTP fetch inside build(). Those fetches threw
  // `Exception: Failed to load font` and `SocketException` on slow or offline
  // devices, where nothing downstream can catch them.
  GoogleFonts.config.allowRuntimeFetching = false;

  // OutOfMemoryError guard. The default image cache is 100 MB / 1000 entries;
  // scrolling a large video or photo library fills it with full-size decoded
  // bitmaps and the process is killed before Dart ever sees pressure. 50 MB /
  // 100 entries is plenty for a grid and leaves headroom for media_kit's own
  // native buffers. Pairs with android:largeHeap in AndroidManifest.xml.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MB
  PaintingBinding.instance.imageCache.maximumSize = 100;

  // Firebase MUST come before the Crashlytics handlers below: they call
  // FirebaseCrashlytics.instance, which throws if no FirebaseApp exists yet.
  // This used to run inside _initDeferred() (i.e. after runApp), which left a
  // 1-2s window at start-up where crashes were silently dropped — exactly the
  // window where the crashes worth catching happen.
  //
  // Options come from android/app/google-services.json, processed by the
  // com.google.gms.google-services Gradle plugin.
  await _guard('firebase', Firebase.initializeApp);

  // Lifecycle hook ke liye: app background jaaye to chalu screen ka time
  // wahin flush ho jaaye, warna screen_time me background ka waqt bhi gin
  // jaata.
  ScreenAnalytics.instance.start();

  // Framework errors are recorded as NON-fatal, deliberately.
  //
  // Every error reaching `FlutterError.onError` is one the framework already
  // caught and handled — the process does not die. A plugin that throws inside
  // its own async zone lands here too, and the app carries on. Reporting those
  // as fatal made Crashlytics' crash-free-users metric understate stability
  // and buried real crashes among entries the user never noticed.
  //
  // Nothing stops being reported; these appear under "Non-fatals".
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;

  // Left as fatal on purpose. Unlike the handler above, this catches errors
  // that escaped every zone — a much smaller and genuinely more serious set.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

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
        // One shared audio-effects engine for the video player AND the music
        // player. A singleton, not a per-subtree instance: the video player is
        // pushed on the root navigator and the music handler lives outside the
        // widget tree entirely, so both have to reach the same object.
        ChangeNotifierProvider<AudioEffectsService>.value(
          value: AudioEffectsService.instance,
        ),
        // Registered by `.value` for the same reason as AudioEffectsService:
        // the ad manager and main() itself read the entitlement from outside
        // the widget tree, so the singleton is the source of truth and this
        // only exposes it to `context.watch` for the paywall and the Me tab.
        ChangeNotifierProvider<BillingService>.value(
          value: BillingService.instance,
        ),
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

  // The cached premium entitlement, read before anything can ask for it.
  //
  // Deliberately in _initCritical rather than _initDeferred: the ad SDK's own
  // init below is skipped entirely for premium users, and that decision has to
  // be made with the flag already in hand. It is a single SharedPreferences
  // read, so it costs the same as the theme load above it.
  await _guard('billing_cache', BillingService.instance.loadCachedEntitlement);
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
  // Firebase itself is already up (see main()); only the FCM background
  // handler registration is deferred, since nothing on the first frame needs it.
  _guardSync('fcm_background', () {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  });

  await Future.wait([
    // Play Billing: connects, loads the two products, and re-verifies the
    // entitlement against Play (both SUBS and INAPP). Deferred because the
    // cached flag read in _initCritical is what the first frame and the ad
    // gate below depend on — this is the slower correction pass, which also
    // picks up a purchase that settled while the app was closed.
    _guard('billing', BillingService.instance.init),

    _guard('ads', () async {
      // Premium users never reach the ad SDK at all.
      //
      // Checked here, before initialize(), rather than at each show site: the
      // SDK starts fetching creatives and collecting an advertising id the
      // moment it is initialised, so a paying user would still pay the
      // battery, bandwidth and privacy cost of an ad stack they never see.
      //
      // The value read here is the *cached* one — the `billing` guard beside
      // this is still re-verifying against Play. Both directions of a stale
      // cache are safe: a mid-session purchase is covered by AppOpenAdManager
      // re-checking on every load/show path, and a lapsed subscription simply
      // goes one more session without ads. Erring toward fewer ads is the only
      // acceptable direction to be wrong in.
      if (BillingService.instance.isPremium) {
        debugPrint('🛡️ Premium user — ad SDK not initialised.');
        return;
      }

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
            '25240AE534A134DAFD363D1E9144746F', // AI Nova 2 Pro
            'D55A05AC5F182B8B7343029E881273E8', // Samsung SM-A505F
            '05B5C242534D4508DE3D9FF83044AED8', // (older dev device)
          ],
        ),
      );

      appOpenManager.init();
    }),

    // FCM permission prompt + token fetch; nothing on screen waits for it.
    _guard('notifications', NotificationService().initNotifications),

    // Restores the saved EQ and attaches it to the music player's audio
    // session. Deferred: nothing on the first frame depends on it, and the
    // session id only becomes real once a track is loaded anyway.
    _guard('equalizer', () async {
      final effects = AudioEffectsService.instance;
      await effects.init();
      if (AudioServiceInit.isReady) {
        await effects.bindMusicPlayer(AudioServiceInit.handler.player);
      }
    }),
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
                  navigatorObservers: [routeObserver, analyticsObserver],
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


                  // Hooked here rather than in ThemeProvider because this is
                  // where the theme is actually resolved: under
                  // ThemeMode.system the real brightness comes from the
                  // platform, not from the stored preference.
                  builder: (context, child) {
                    AppPalette.setBrightness(
                      Theme.of(context).brightness == Brightness.dark,
                    );
                    return child ?? const SizedBox.shrink();
                  },
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
      // Foreground pushes get no tray banner from Android, so the app has to
      // draw one itself. Without this a push that arrives while the app is
      // open is completely invisible.
      await LocalNotifications.init();

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('📩 Foreground message: ${message.messageId}');
          debugPrint('📩 Title: ${message.notification?.title}');
          debugPrint('📩 Data: ${message.data}');
        }
        // Foreground pushes never reach the background handler, so this is
        // the only place they get stored.
        NotificationStore.instance.add(message);
        LocalNotifications.show(message);
      });

      // ✅ When user taps notification & opens app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          debugPrint('👉 Notification opened: ${message.messageId}');
          debugPrint('👉 Data: ${message.data}');
        }
        NotificationStore.instance.add(message);
      });

      // ✅ If app was terminated and opened by notification
      final initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        if (kDebugMode) {
          debugPrint('🚀 Opened from terminated: ${initialMessage.messageId}');
        }
        // Duplicate-safe: the background handler may already have stored this
        // one. NotificationStore.add ignores an id it has seen.
        await NotificationStore.instance.add(initialMessage);
      }

      // Seed the bell badge from whatever arrived while the app was closed.
      await NotificationStore.instance.refreshUnreadCount();
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
