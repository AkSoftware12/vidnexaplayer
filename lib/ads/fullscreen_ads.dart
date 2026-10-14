// App Open + Interstitial, Google ke official Preloader API se
// (google_mobile_ads 9.1+). Pehli Kotlin app bhi yahi Preloader use karti hai.
//
// Preloader buffer mein ad ready rakhta hai, aur jaise hi ek ad nikalte ho
// wo khud agla load karta hai. Ad memory mein hai, isliye process zinda rahe
// to net band hone par bhi dikh jata hai.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_config.dart';

// ============================================================================
// APP OPEN
// ============================================================================
class AppOpenManager {
  AppOpenManager._();
  static final AppOpenManager instance = AppOpenManager._();

  static const String _preloadId = 'app_open_main';
  static const String _tag = 'AppOpen';

  bool _started = false;
  bool _lastPreloadFailed = false;
  bool _splashDone = false;
  DateTime? _lastShown;
  DateTime? _backgroundAt;
  StreamSubscription<AppState>? _sub;

  /// Naam jo aap navigator observer se set karo (excluded screens ke liye).
  String? currentScreen;

  AdConfig get _c => Ads.config;

  Future<void> start() async {
    if (_started || !_c.adsAllowed || !_c.appOpenEnabled) return;
    _started = true;
    _lastPreloadFailed = false;
    Ads.log(_tag, 'Preloader start (buffer=${_c.appOpenBufferSize})');
    try {
      await AppOpenAdPreloader.start(
        preloadId: _preloadId,
        preloadConfiguration: PreloadConfiguration(
          adUnitId: _c.appOpenUnitId,
          request: Ads.request(),
          bufferSize: _c.appOpenBufferSize,
        ),
        callback: PreloadCallback(
          onAdPreloaded: (_, __) {
            _lastPreloadFailed = false;
            Ads.log(_tag, 'Ad ready in buffer');
          },
          onAdsExhausted: (_) => Ads.log(_tag, 'Buffer khali'),
          onAdFailedToPreload: (_, e) {
            _lastPreloadFailed = true;
            Ads.log(_tag, 'Preload failed: ${e.message}');
          },
        ),
      );
    } catch (e) {
      _started = false;
      Ads.log(_tag, 'Preloader start error: $e');
    }
  }

  /// Preload fail hua tha (jaise offline) aur buffer khali hai -> dobara start.
  Future<void> _restartIfNeeded() async {
    if (!_started) return start();
    if (!_lastPreloadFailed) return;
    if (await AppOpenAdPreloader.isAdAvailable(_preloadId)) return;
    Ads.log(_tag, 'Preloader restart');
    try {
      await AppOpenAdPreloader.destroy(_preloadId);
    } catch (_) {}
    _started = false;
    await start();
  }

  /// Background -> foreground par App Open dikhana.
  void listenAppForeground() {
    _sub ??= AppStateEventNotifier.appStateStream.listen((state) {
      if (state == AppState.background) {
        _backgroundAt = DateTime.now();
        return;
      }
      if (state != AppState.foreground) return;
      final backgroundAt = _backgroundAt;
      _backgroundAt = null;
      // Offline mein fail hue preloaders/pools net aane ke baad yahan se phir chalu honge
      unawaited(InterstitialManager.instance.refresh());
      unawaited(RewardedManager.instance.refresh());
      for (final hook in Ads.foregroundHooks) {
        hook();
      }
      if (!_splashDone) return; // splash khud dikhayega
      if (Ads.skipNextResume) {
        Ads.skipNextResume = false;
        return;
      }
      // A quick switch to another app and back isn't a real "return".
      if (backgroundAt == null ||
          DateTime.now().difference(backgroundAt).inSeconds < _c.appOpenMinBackgroundSec) {
        Ads.log(_tag, 'Background too short');
        return;
      }
      show(onDone: () {});
    });
    AppStateEventNotifier.startListening();
  }

  /// Splash se: `fromSplash: true`. onDone hamesha ek hi baar chalta hai.
  Future<void> show({bool fromSplash = false, required VoidCallback onDone}) async {
    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      if (fromSplash) _splashDone = true;
      onDone();
    }

    if (!_c.adsAllowed || !_c.appOpenEnabled || Ads.fullscreenShowing) return finish();

    // audio_service can boot this isolate with no Activity (push with the app
    // closed). The plugin's show() then just logs "activity was not bound" and
    // never calls back, so the splash would wait forever. The foreground event
    // itself arrives on onStart, a moment before Flutter reports `resumed`,
    // hence the short wait rather than an immediate check.
    if (!await _waitForResumed()) {
      Ads.log(_tag, 'No foreground activity (${WidgetsBinding.instance.lifecycleState})');
      return finish();
    }

    if (!fromSplash) {
      final now = DateTime.now();
      if (currentScreen != null && _c.appOpenExcludedScreens.contains(currentScreen)) {
        Ads.log(_tag, 'Excluded screen: $currentScreen');
        return finish();
      }
      if (_lastShown != null &&
          now.difference(_lastShown!).inSeconds < _c.appOpenCooldownSec) {
        Ads.log(_tag, 'Cooldown');
        return finish();
      }
      if (Ads.lastFullscreenAt != null &&
          now.difference(Ads.lastFullscreenAt!).inSeconds < 5) {
        Ads.log(_tag, '5s hard gap');
        return finish();
      }
    }

    AppOpenAd? ad;
    try {
      if (!await AppOpenAdPreloader.isAdAvailable(_preloadId)) {
        // Splash par thoda ruk ke dekho, shayad abhi load ho raha ho
        if (fromSplash && _started && !_lastPreloadFailed) {
          final deadline = DateTime.now().add(Duration(milliseconds: _c.splashWaitMs));
          while (DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
            if (await AppOpenAdPreloader.isAdAvailable(_preloadId)) break;
          }
        }
      }
      ad = await AppOpenAdPreloader.pollAd(_preloadId);
    } catch (e) {
      Ads.log(_tag, 'pollAd error: $e');
    }

    if (ad == null) {
      Ads.log(_tag, 'Koi ad ready nahi');
      unawaited(_restartIfNeeded());
      return finish();
    }

    _attachAndShow(ad, finish);
  }

  void _attachAndShow(AppOpenAd ad, VoidCallback finish) {
    Ads.fullscreenShowing = true;
    // Backstop for a show() that never appears (the Activity went away
    // meanwhile): without it the splash and fullscreenShowing stay stuck.
    final showTimeout = Timer(const Duration(seconds: 5), () {
      Ads.log(_tag, 'Never appeared, giving up');
      Ads.fullscreenShowing = false;
      ad.dispose();
      finish();
    });
    ad.fullScreenContentCallback = FullScreenContentCallback<AppOpenAd>(
      onAdShowedFullScreenContent: (_) {
        showTimeout.cancel();
        _lastShown = DateTime.now();
        Ads.lastFullscreenAt = _lastShown;
        Ads.log(_tag, 'Shown');
      },
      onAdClicked: (_) => Ads.skipNextResume = true,
      onAdDismissedFullScreenContent: (a) {
        showTimeout.cancel();
        Ads.fullscreenShowing = false;
        Ads.lastFullscreenAt = DateTime.now();
        a.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        showTimeout.cancel();
        Ads.fullscreenShowing = false;
        Ads.log(_tag, 'Show failed: ${e.message}');
        a.dispose();
        finish();
      },
    );
    ad.show();
  }

  static Future<bool> _waitForResumed() async {
    bool resumed() => WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    for (var i = 0; i < 15 && !resumed(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return resumed();
  }

  /// Splash nahi hai to ise call karo, taaki foreground wala ad chalu ho jaye.
  void markSplashDone() => _splashDone = true;
}

// ============================================================================
// INTERSTITIAL
// ============================================================================
class InterstitialManager {
  InterstitialManager._();
  static final InterstitialManager instance = InterstitialManager._();

  static const String _preloadId = 'interstitial_main';
  static const String _tag = 'Interstitial';

  bool _started = false;
  bool _lastPreloadFailed = false;
  int _actionCount = 0;
  int _shownThisSession = 0;
  DateTime? _lastShown;

  AdConfig get _c => Ads.config;

  Future<void> start() async {
    if (_started || !_c.adsAllowed || !_c.interstitialEnabled) return;
    _started = true;
    _lastPreloadFailed = false;
    Ads.log(_tag, 'Preloader start (buffer=${_c.interstitialBufferSize})');
    try {
      await InterstitialAdPreloader.start(
        preloadId: _preloadId,
        preloadConfiguration: PreloadConfiguration(
          adUnitId: _c.interstitialUnitId,
          request: Ads.request(),
          bufferSize: _c.interstitialBufferSize,
        ),
        callback: PreloadCallback(
          onAdPreloaded: (_, __) => _lastPreloadFailed = false,
          onAdFailedToPreload: (_, e) {
            _lastPreloadFailed = true;
            Ads.log(_tag, 'Preload failed: ${e.message}');
          },
        ),
      );
    } catch (e) {
      _started = false;
      Ads.log(_tag, 'Preloader start error: $e');
    }
  }

  Future<void> _restartIfNeeded() async {
    if (!_started) return start();
    if (!_lastPreloadFailed) return;
    if (await InterstitialAdPreloader.isAdAvailable(_preloadId)) return;
    try {
      await InterstitialAdPreloader.destroy(_preloadId);
    } catch (_) {}
    _started = false;
    await start();
  }

  /// Kisi action par call karo (screen kholna, video band karna, etc.).
  /// Rules pass hue aur ad ready hai to dikhayega; warna turant onDone.
  /// [force] = rules ignore (sirf premium/enabled check).
  Future<void> showIfEligible({required VoidCallback onDone, bool force = false}) async {
    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      onDone();
    }

    if (!_c.adsAllowed || !_c.interstitialEnabled || Ads.fullscreenShowing) return finish();

    if (!force) {
      _actionCount++;
      final now = DateTime.now();
      if (_actionCount < _c.interstitialScreenIntervalCount) {
        Ads.log(_tag, 'Action $_actionCount/${_c.interstitialScreenIntervalCount}');
        return finish();
      }
      if (_lastShown != null &&
          now.difference(_lastShown!).inSeconds < _c.interstitialIntervalSec) {
        Ads.log(_tag, 'Interval');
        return finish();
      }
      if (Ads.lastFullscreenAt != null &&
          now.difference(Ads.lastFullscreenAt!).inSeconds < _c.fullscreenHardCooldownSec) {
        Ads.log(_tag, 'Hard cooldown');
        return finish();
      }
      if (_c.interstitialSessionCap > 0 && _shownThisSession >= _c.interstitialSessionCap) {
        Ads.log(_tag, 'Session cap');
        return finish();
      }
    }

    InterstitialAd? ad;
    try {
      ad = await InterstitialAdPreloader.pollAd(_preloadId);
    } catch (e) {
      Ads.log(_tag, 'pollAd error: $e');
    }
    if (ad == null) {
      unawaited(_restartIfNeeded());
      return finish();
    }

    Ads.fullscreenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        _lastShown = DateTime.now();
        Ads.lastFullscreenAt = _lastShown;
        _actionCount = 0;
        _shownThisSession++;
      },
      onAdClicked: (_) => Ads.skipNextResume = true,
      onAdDismissedFullScreenContent: (a) {
        Ads.fullscreenShowing = false;
        Ads.lastFullscreenAt = DateTime.now();
        a.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        Ads.fullscreenShowing = false;
        a.dispose();
        finish();
      },
    );
    ad.show();
  }

  /// Net wapas aane par / app foreground par call kar sakte ho.
  Future<void> refresh() => _restartIfNeeded();
}

// ============================================================================
// REWARDED (feature unlock: Enhance, Filters, ...)
// ============================================================================
class RewardedManager {
  RewardedManager._();
  static final RewardedManager instance = RewardedManager._();

  static const String _preloadId = 'rewarded_main';
  static const String _tag = 'Rewarded';

  bool _started = false;
  bool _lastPreloadFailed = false;

  AdConfig get _c => Ads.config;

  Future<void> start() async {
    if (_started || !_c.adsAllowed || !_c.rewardedEnabled) return;
    _started = true;
    _lastPreloadFailed = false;
    Ads.log(_tag, 'Preloader start');
    try {
      await RewardedAdPreloader.start(
        preloadId: _preloadId,
        preloadConfiguration: PreloadConfiguration(
          adUnitId: _c.rewardedUnitId,
          request: Ads.request(),
          bufferSize: 1,
        ),
        callback: PreloadCallback(
          onAdPreloaded: (_, __) => _lastPreloadFailed = false,
          onAdFailedToPreload: (_, e) {
            _lastPreloadFailed = true;
            Ads.log(_tag, 'Preload failed: ${e.message}');
          },
        ),
      );
    } catch (e) {
      _started = false;
      Ads.log(_tag, 'Preloader start error: $e');
    }
  }

  Future<void> refresh() async {
    if (!_started) return start();
    if (!_lastPreloadFailed) return;
    if (await RewardedAdPreloader.isAdAvailable(_preloadId)) return;
    try {
      await RewardedAdPreloader.destroy(_preloadId);
    } catch (_) {}
    _started = false;
    await start();
  }

  /// "Watch ad" button enable karne ke liye.
  Future<bool> isReady() async {
    if (!_c.adsAllowed) return true;
    try {
      return await RewardedAdPreloader.isAdAvailable(_preloadId);
    } catch (_) {
      return false;
    }
  }

  /// Ad dikhata hai. true = user ne poora dekha, feature unlock karo.
  /// Premium user ke liye seedha true (bina ad ke unlock).
  /// false = ad ready nahi tha / beech mein band kiya -> "Ad abhi available nahi" dikhao.
  Future<bool> show() async {
    if (!_c.adsAllowed) return true;
    if (!_c.rewardedEnabled || Ads.fullscreenShowing) return false;

    RewardedAd? ad;
    try {
      ad = await RewardedAdPreloader.pollAd(_preloadId);
    } catch (e) {
      Ads.log(_tag, 'pollAd error: $e');
    }
    if (ad == null) {
      unawaited(refresh());
      return false;
    }

    final result = Completer<bool>();
    var earned = false;
    Ads.fullscreenShowing = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (_) => Ads.lastFullscreenAt = DateTime.now(),
      onAdClicked: (_) => Ads.skipNextResume = true,
      onAdDismissedFullScreenContent: (a) {
        Ads.fullscreenShowing = false;
        Ads.lastFullscreenAt = DateTime.now();
        a.dispose();
        if (!result.isCompleted) result.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, e) {
        Ads.fullscreenShowing = false;
        Ads.log(_tag, 'Show failed: ${e.message}');
        a.dispose();
        if (!result.isCompleted) result.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => earned = true);
    return result.future;
  }
}

/// Ek line mein foreground par saare fullscreen preloaders ko jagane ke liye.
Future<void> refreshFullscreenPreloaders() async {
  await AppOpenManager.instance._restartIfNeeded();
  await InterstitialManager.instance.refresh();
  await RewardedManager.instance.refresh();
}
