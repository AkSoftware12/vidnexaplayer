// Ek jagah se saare ads shuru karna: consent (UMP) -> SDK init -> preloaders + pools.
//
// Use:
//   Splash screen ke initState mein:
//     await AdsManager.init();          // consent + SDK + preload
//     AppOpenManager.instance.show(fromSplash: true, onDone: goHome);

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';
import 'fullscreen_ads.dart';
import 'view_ad_pools.dart';

// So screens can pick a native size without importing the SDK themselves.
export 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;

export 'ad_config.dart';
export 'ad_widgets.dart';
export 'fullscreen_ads.dart';
export 'view_ad_pools.dart';

class AdsManager {
  AdsManager._();

  static bool _initialized = false;
  static Completer<void>? _initCompleter;
  static bool _foregroundHooked = false;

  /// Kai baar call karna safe hai.
  /// [remoteConfig] = Firebase Remote Config se aaya JSON (optional).
  static Future<void> init({Map<String, dynamic>? remoteConfig}) {
    if (_initCompleter != null) return _initCompleter!.future;
    final completer = Completer<void>();
    _initCompleter = completer;
    _doInit(remoteConfig).whenComplete(completer.complete);
    return completer.future;
  }

  static Future<void> _doInit(Map<String, dynamic>? remoteConfig) async {
    if (remoteConfig != null) Ads.config.updateFromJson(remoteConfig);
    if (!Ads.config.adsAllowed) {
      Ads.log('Manager', 'Premium user: ads off');
      return;
    }

    // 1) Consent (EU/UK users ke liye zaroori). Fail ho to bhi aage badho.
    await _gatherConsent();
    if (!await ConsentInformation.instance.canRequestAds()) {
      Ads.log('Manager', 'Consent nahi mila: ads off');
      return;
    }

    // 2) SDK init
    if (Ads.config.testDeviceIds.isNotEmpty) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(testDeviceIds: Ads.config.testDeviceIds),
      );
    }
    await MobileAds.instance.initialize();
    _initialized = true;
    Ads.sdkReady = true;
    Ads.log('Manager', 'SDK initialized');

    // 3) Sab kuch pehle se load karo
    await AppOpenManager.instance.start();
    await InterstitialManager.instance.start();
    await RewardedManager.instance.start();
    // Every native slot in this app uses the small template.
    ViewAdPools.fillAll(nativeTypes: const [TemplateType.small]);

    // 4) Background -> foreground: App Open + pools refresh
    _hookForegroundRefresh();
    AppOpenManager.instance.listenAppForeground();
  }

  static Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
          if (error != null) Ads.log('Consent', 'Form error: ${error.message}');
          if (!done.isCompleted) done.complete();
        });
        if (!done.isCompleted) done.complete();
      },
      (FormError error) {
        Ads.log('Consent', 'Update error: ${error.message}');
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () {});
  }

  static void _hookForegroundRefresh() {
    if (_foregroundHooked) return;
    _foregroundHooked = true;
    Ads.foregroundHooks.add(ViewAdPools.refreshAll);
  }

  static bool get isInitialized => _initialized;

  /// User ne premium khareeda: turant sab ads band.
  static void setPremium(bool premium) {
    if (Ads.config.isPremium == premium) return;
    Ads.config.isPremium = premium;
    if (premium) {
      for (final p in NativeAdPool.all) {
        p.disposeAll();
      }
      BannerAdPool.instance.disposeAll();
      return;
    }
    // Premium lapsed. If the stack never started (user was premium at launch),
    // start it now — consent first, exactly like a normal launch.
    _restartInitIfNeeded();
  }

  /// init() bailed out early (premium / no consent) -> allow a fresh run.
  static void _restartInitIfNeeded() {
    if (_initialized) return;
    final pending = _initCompleter;
    // null = the splash hasn't configured and started ads yet; it will.
    if (pending == null || !pending.isCompleted) return;
    _initCompleter = null;
    unawaited(init());
  }

  /// Whether settings must show the "Privacy options" entry (EEA/UK/CH users).
  static Future<bool> privacyOptionsRequired() async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Re-opens the UMP form so the user can change their consent choice.
  static Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) Ads.log('Consent', 'Privacy options error: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    await done.future;
    // A user who now allows ads gets them without restarting the app.
    if (await ConsentInformation.instance.canRequestAds()) _restartInitIfNeeded();
  }

  /// Gallery, camera, billing, share sheet kholne se pehle call karo,
  /// warna wapas aate hi App Open aa jayega.
  static void skipNextAppOpen() => Ads.skipNextResume = true;
}

/// Keeps [AppOpenManager.currentScreen] on the name of the top page route, so
/// `Ads.config.appOpenExcludedScreens` (e.g. the video player) can veto App
/// Open on foreground. Dialogs and sheets aren't page routes and are ignored.
class AdRouteObserver extends NavigatorObserver {
  void _set(Route<dynamic>? route) {
    if (route is PageRoute) AppOpenManager.instance.currentScreen = route.settings.name;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _set(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _set(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _set(newRoute);
}
