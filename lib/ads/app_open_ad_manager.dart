import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Billing/billing_service.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/misc_strings.dart';
import '../Utils/color.dart';

/// Ad unit ids in one place instead of scattered string literals.
///
/// In debug builds these resolve to Google's **official sample unit ids**,
/// which always fill. Relying on `testDeviceIds` instead is fragile: the id
/// hardcoded in main.dart belonged to a different handset, so this device was
/// never registered, every request went out as live traffic, and the banner
/// unit answered "No fill" (error code 3) while App Open / Interstitial — which
/// happen to have inventory — kept working. That is exactly the symptom of
/// "banner ads don't show but the others do".
class AdUnits {
  AdUnits._();

  // ---- Live units (release builds) ----
  static const String _liveAppOpen = 'ca-app-pub-6478840988045325/9137962029';
  static const String _liveBanner = 'ca-app-pub-6478840988045325/7764390357';
  static const String _liveInterstitial = 'ca-app-pub-6478840988045325/2955697053';
  static const String _liveNative = 'ca-app-pub-6478840988045325/9759998301';
  static const String _liveRewarded = 'ca-app-pub-6478840988045325/2605437798';
  static const String _liveRewardedInterstitial =
      'ca-app-pub-6478840988045325/5231601134';

  // ---- Google's public test units (debug builds) ----
  // https://developers.google.com/admob/android/test-ads
  static const String _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testNative = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedInterstitial =
      'ca-app-pub-3940256099942544/5354046379';

  static const String appOpen = kDebugMode ? _testAppOpen : _liveAppOpen;
  static const String banner = kDebugMode ? _testBanner : _liveBanner;
  static const String interstitial =
      kDebugMode ? _testInterstitial : _liveInterstitial;
  static const String native = kDebugMode ? _testNative : _liveNative;
  static const String rewarded = kDebugMode ? _testRewarded : _liveRewarded;
  static const String rewardedInterstitial =
      kDebugMode ? _testRewardedInterstitial : _liveRewardedInterstitial;
}

/// App-wide ad manager.
///
/// This is a **singleton** — `AppOpenAdManager()` always returns the same
/// instance. Previously every screen constructed its own copy and called
/// `init()`, which registered ~10 lifecycle observers, so a single app resume
/// fired ~10 App Open ad attempts. That is an AdMob invalid-traffic violation
/// as well as a memory/bandwidth leak.
///
/// Lifecycle is owned by `main.dart` only: call [init] once at startup.
/// Screens must NOT call `init()` or dispose this object.
class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAdManager._internal();

  static final AppOpenAdManager _instance = AppOpenAdManager._internal();

  factory AppOpenAdManager() => _instance;

  // =========================================================
  // APP OPEN
  // =========================================================
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _isAppOpenLoading = false;

  static const int _dailyLimit = 2;
  static const int _cooldownMinutes = 10;

  /// True while our own fullscreen ad owns the screen. Resuming *from* an ad
  /// must never trigger another ad.
  bool get isShowingFullScreenAd => _isShowingAd;

  // =========================================================
  // INTERSTITIAL
  // =========================================================
  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  /// Show an interstitial only every Nth qualifying action.
  int interstitialShowAfterActions = 4;

  /// Hard ceiling per calendar day, mirroring the App Open cap.
  static const int _interstitialDailyLimit = 5;

  Duration interstitialCooldown = const Duration(seconds: 60);

  // ---- Persisted frequency state ----
  //
  // All of this used to live in plain in-memory fields, so `_actionCount` reset
  // to 0 on every app restart and there was no daily cap at all: a user opening
  // 30 videos could be shown ~10 interstitials in one sitting, and relaunching
  // the app handed them a fresh counter. Now it survives restarts and is capped.
  static const String _kIntDate = 'int_date';
  static const String _kIntDayCount = 'int_day_count';
  static const String _kIntLastTime = 'int_last_time';
  static const String _kIntActionCount = 'int_action_count';

  int _actionCount = 0;
  int _interstitialDayCount = 0;
  String _interstitialDate = '';
  DateTime _lastInterstitialShown = DateTime.fromMillisecondsSinceEpoch(0);

  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  /// Loads the persisted counters once, at start-up.
  ///
  /// Kept in memory afterwards so [showInterstitialIfAllowed] can decide
  /// synchronously — awaiting SharedPreferences on every video tap would add a
  /// visible hitch before playback starts.
  Future<void> _loadInterstitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _interstitialDate = prefs.getString(_kIntDate) ?? '';
      _interstitialDayCount = prefs.getInt(_kIntDayCount) ?? 0;
      _actionCount = prefs.getInt(_kIntActionCount) ?? 0;
      _lastInterstitialShown = DateTime.fromMillisecondsSinceEpoch(
        prefs.getInt(_kIntLastTime) ?? 0,
      );

      _rollDayIfNeeded();
    } catch (_) {
      // Fall back to the in-memory defaults; capping is best-effort.
    }
  }

  /// Resets the per-day counters when the date changes.
  void _rollDayIfNeeded() {
    final today = _today;
    if (_interstitialDate == today) return;

    _interstitialDate = today;
    _interstitialDayCount = 0;
    _actionCount = 0;
  }

  Future<void> _persistInterstitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kIntDate, _interstitialDate);
      await prefs.setInt(_kIntDayCount, _interstitialDayCount);
      await prefs.setInt(_kIntActionCount, _actionCount);
      await prefs.setInt(
        _kIntLastTime,
        _lastInterstitialShown.millisecondsSinceEpoch,
      );
    } catch (_) {
      // Non-fatal: the in-memory state is still correct for this session.
    }
  }

  // =========================================================
  // REWARDED
  // =========================================================
  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;

  bool _isRewardedLoading = false;
  bool _isRewardedInterstitialLoading = false;

  /// True when a rewarded ad of either kind is in hand.
  ///
  /// The caller uses this to decide whether to offer the opt-in prompt at all.
  /// Offering "watch an ad to unlock" and then failing to produce one is worse
  /// than never offering it.
  bool get hasRewardedAd =>
      _rewardedAd != null || _rewardedInterstitialAd != null;

  // =========================================================
  // PREMIUM GATE
  // =========================================================
  /// Whether this user has paid to remove ads.
  ///
  /// Read live rather than captured once, because the flag flips the instant a
  /// purchase completes on the paywall — a user who has just paid must not sit
  /// through an interstitial that was already queued up. main.dart skips
  /// `MobileAds.initialize()` entirely for a user who was already premium at
  /// launch, so in practice this guard covers the mid-session case.
  ///
  /// Deliberately the same top-level getter the banner and native widgets use,
  /// so there is exactly one definition of "ads are off for this user".
  bool get _isPremiumUser => _isPremium;

  // =========================================================
  // INIT
  // =========================================================
  bool _initialized = false;

  /// Safe to call more than once — extra calls are ignored.
  void init() {
    if (_initialized) return;
    if (_isPremiumUser) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Restore the persisted frequency caps before anything can be shown.
    unawaited(_loadInterstitialState());

    loadAd();
    _loadInterstitial();
    _loadRewarded();
    _loadRewardedInterstitial();
  }

  /// Only for full app teardown. Screens must not call this.
  void shutdown() {
    if (!_initialized) return;
    _initialized = false;

    WidgetsBinding.instance.removeObserver(this);

    _appOpenAd?.dispose();
    _appOpenAd = null;

    _interstitialAd?.dispose();
    _interstitialAd = null;

    _rewardedAd?.dispose();
    _rewardedAd = null;

    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
  }

  /// Resume listener.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Coming back from our own fullscreen ad is not a real app resume.
    if (_isShowingAd) return;

    showAdIfAvailable(() {});
  }

  // =========================================================
  // APP OPEN
  // =========================================================
  void loadAd() {
    if (_isPremiumUser) return;
    if (_isAppOpenLoading || _appOpenAd != null) return;
    _isAppOpenLoading = true;

    AppOpenAd.load(
      adUnitId: AdUnits.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ App Open Ad loaded');
          _isAppOpenLoading = false;
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ App Open Ad failed: $error');
          _isAppOpenLoading = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  Future<bool> _canShowAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = prefs.getString('aoa_date') ?? '';
      int count = prefs.getInt('aoa_count') ?? 0;
      final lastShown = prefs.getInt('aoa_last_time') ?? 0;

      if (savedDate != today) {
        await prefs.setString('aoa_date', today);
        await prefs.setInt('aoa_count', 0);
        count = 0;
      }

      if (count >= _dailyLimit) return false;

      final now = DateTime.now().millisecondsSinceEpoch;
      final diffMinutes = (now - lastShown) / 60000;
      if (diffMinutes < _cooldownMinutes) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('aoa_last_time', DateTime.now().millisecondsSinceEpoch);
      await prefs.setInt('aoa_count', (prefs.getInt('aoa_count') ?? 0) + 1);
    } catch (_) {
      // Frequency capping is best-effort; never block the UI on it.
    }
  }

  /// Shows the App Open ad if one is loaded and the frequency cap allows it.
  /// [onDone] always runs exactly once.
  Future<void> showAdIfAvailable(VoidCallback onDone) async {
    var called = false;
    void finish() {
      if (called) return;
      called = true;
      onDone();
    }

    // Premium check comes before the ad lookup so a purchase made mid-session
    // suppresses an App Open ad that was already loaded and waiting.
    final ad = _appOpenAd;
    if (_isPremiumUser || ad == null || _isShowingAd) {
      finish();
      return;
    }

    // Claim the ad synchronously, before the `await` below — otherwise a
    // second overlapping call (e.g. app-resume firing while the splash
    // screen's own call is still awaiting _canShowAd()'s SharedPreferences
    // round-trip) would also read a non-null `_appOpenAd`/`_isShowingAd ==
    // false`, and both calls would go on to show() the same single-use ad.
    _appOpenAd = null;
    _isShowingAd = true;

    if (!await _canShowAd()) {
      // Not actually showing after all — release the claim.
      _appOpenAd = ad;
      _isShowingAd = false;
      finish();
      return;
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _isShowingAd = false;
        await _markShown();
        loadAd();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ App Open show failed: $error');
        ad.dispose();
        _isShowingAd = false;
        loadAd();
        finish();
      },
    );

    ad.show();
  }

  // =========================================================
  // INTERSTITIAL
  // =========================================================
  void _loadInterstitial() {
    if (_isPremiumUser) return;
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: AdUnits.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Interstitial loaded');
          _isInterstitialLoading = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial failed to load: $error');
          _isInterstitialLoading = false;
          _interstitialAd = null;

          // Light retry, but only while the manager is alive.
          Future.delayed(const Duration(seconds: 25), () {
            if (_initialized) _loadInterstitial();
          });
        },
      ),
    );
  }

  bool _canShowInterstitialNow() {
    // Every gate must pass: enough actions since the last ad, enough elapsed
    // time, still under today's ceiling, an ad in hand, and no other fullscreen
    // ad already on screen.
    final countOk = _actionCount % interstitialShowAfterActions == 0;
    final gapOk =
        DateTime.now().difference(_lastInterstitialShown) >= interstitialCooldown;
    final dailyOk = _interstitialDayCount < _interstitialDailyLimit;

    return countOk &&
        gapOk &&
        dailyOk &&
        _interstitialAd != null &&
        !_isShowingAd;
  }

  /// Use on Play / Open-detail actions.
  /// [onContinue] always runs exactly once, whether or not an ad is shown.
  void showInterstitialIfAllowed({required VoidCallback onContinue}) {
    var called = false;
    void proceed() {
      if (called) return;
      called = true;
      onContinue();
    }

    // Premium users go straight through. Returning before the counter bump
    // matters: the action count is persisted, so incrementing it here would
    // have a paying user silently building up credit toward an interstitial
    // that fires the day their subscription lapses.
    if (_isPremiumUser) {
      proceed();
      return;
    }

    _rollDayIfNeeded();
    _actionCount++;

    if (!_canShowInterstitialNow()) {
      // Persist the bumped action count so relaunching the app can't rewind it.
      unawaited(_persistInterstitialState());
      _loadInterstitial();
      proceed();
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _lastInterstitialShown = DateTime.now();
    _interstitialDayCount++;
    _isShowingAd = true;

    unawaited(_persistInterstitialState());
    debugPrint(
      '📺 Interstitial $_interstitialDayCount/$_interstitialDailyLimit today',
    );

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _isShowingAd = false;
        _loadInterstitial();
        proceed();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        debugPrint('❌ Interstitial show failed: $err');
        ad.dispose();
        _isShowingAd = false;
        _loadInterstitial();
        proceed();
      },
    );

    ad.show();
  }

  // =========================================================
  // REWARDED
  // =========================================================
  //
  // Two units back one placement. The rewarded unit is preferred; the rewarded
  // interstitial is the fallback when it has no fill. Both carry the same
  // AdMob requirement — an opt-in screen naming the reward, with a way to
  // decline — and the caller satisfies it once for both (see
  // `RewardedUnlockPrompt`). Nothing here shows an ad on its own.

  void _loadRewarded() {
    if (_isPremiumUser) return;
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: AdUnits.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Rewarded loaded');
          _isRewardedLoading = false;
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded failed to load: $error');
          _isRewardedLoading = false;
          _rewardedAd = null;
          Future.delayed(const Duration(seconds: 30), () {
            if (_initialized) _loadRewarded();
          });
        },
      ),
    );
  }

  void _loadRewardedInterstitial() {
    if (_isPremiumUser) return;
    if (_isRewardedInterstitialLoading || _rewardedInterstitialAd != null) {
      return;
    }
    _isRewardedInterstitialLoading = true;

    RewardedInterstitialAd.load(
      adUnitId: AdUnits.rewardedInterstitial,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Rewarded interstitial loaded');
          _isRewardedInterstitialLoading = false;
          _rewardedInterstitialAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded interstitial failed to load: $error');
          _isRewardedInterstitialLoading = false;
          _rewardedInterstitialAd = null;
          Future.delayed(const Duration(seconds: 30), () {
            if (_initialized) _loadRewardedInterstitial();
          });
        },
      ),
    );
  }

  /// Shows a rewarded ad and resolves to whether the reward was earned.
  ///
  /// Call this **only** after the user has opted in through a prompt that
  /// named the reward — AdMob requires that, and it is also the only version
  /// of this that is fair to the user.
  ///
  /// Returns false when no ad could be shown. The caller decides what that
  /// means; the convention in this app is to grant the reward anyway rather
  /// than punish someone for our empty inventory.
  Future<bool> showRewarded() async {
    if (_isShowingAd) return false;

    final rewarded = _rewardedAd;
    if (rewarded != null) {
      _rewardedAd = null;
      return _showFullScreenRewarded<RewardedAd>(
        ad: rewarded,
        show: (onEarned) => rewarded.show(onUserEarnedReward: onEarned),
        setCallback: (callback) => rewarded.fullScreenContentCallback = callback,
        reload: _loadRewarded,
      );
    }

    final fallback = _rewardedInterstitialAd;
    if (fallback != null) {
      _rewardedInterstitialAd = null;
      return _showFullScreenRewarded<RewardedInterstitialAd>(
        ad: fallback,
        show: (onEarned) => fallback.show(onUserEarnedReward: onEarned),
        setCallback: (callback) =>
            fallback.fullScreenContentCallback = callback,
        reload: _loadRewardedInterstitial,
      );
    }

    // Nothing in hand — start filling for next time.
    _loadRewarded();
    _loadRewardedInterstitial();
    return false;
  }

  /// Shared show/dispose/reload dance for the two rewarded kinds.
  ///
  /// The reward is recorded when it is earned but only returned once the ad is
  /// dismissed, so the caller never unlocks something behind an ad that is
  /// still covering the screen.
  Future<bool> _showFullScreenRewarded<T extends AdWithoutView>({
    required T ad,
    required void Function(OnUserEarnedRewardCallback) show,
    required void Function(FullScreenContentCallback<T>) setCallback,
    required VoidCallback reload,
  }) {
    final completer = Completer<bool>();
    var earned = false;

    void finish(bool result) {
      if (completer.isCompleted) return;
      completer.complete(result);
    }

    _isShowingAd = true;

    setCallback(
      FullScreenContentCallback<T>(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _isShowingAd = false;
          reload();
          finish(earned);
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          debugPrint('❌ Rewarded show failed: $err');
          ad.dispose();
          _isShowingAd = false;
          reload();
          finish(false);
        },
      ),
    );

    show((_, __) => earned = true);

    return completer.future;
  }

  // =========================================================
  // BANNER
  // =========================================================
  /// A banner sized for a bottom bar.
  ///
  /// Each call returns a widget that owns its **own** [BannerAd]. Sharing one
  /// `BannerAd` between screens throws
  /// "This AdWidget is already in the Widget tree".
  Widget bannerWidgetBottomScreen() => const AdaptiveBannerAd(bare: true);

  /// A banner in a card with a "Sponsored" label.
  Widget bannerWidget({EdgeInsets? margin}) =>
      AdaptiveBannerAd(margin: margin, bare: false);

  // =========================================================
  // NATIVE
  // =========================================================
  /// An in-content native ad, styled to sit inside a page rather than pinned
  /// to its edge.
  ///
  /// Uses the plugin's built-in template, so there is no `NativeAdFactory` to
  /// register on the Android side and nothing to keep in step with a layout
  /// XML. Each call owns its own [NativeAd], for the same reason each banner
  /// does.
  /// Defaults to the small template. The medium one needs a ~600px slot to
  /// render a square-media creative without clipping (see [NativeAdCard]),
  /// which is more of a screen than any of these surfaces can spare.
  Widget nativeWidget({
    EdgeInsets? margin,
    TemplateType template = TemplateType.small,
  }) =>
      NativeAdCard(margin: margin, template: template);

  /// The short native template, for slots inside a scrolling feed.
  ///
  /// Exists so screens can pick a size without importing the ads SDK to name
  /// a [TemplateType] — the gallery has no other reason to know that package
  /// exists.
  Widget nativeCompactWidget({EdgeInsets? margin}) =>
      NativeAdCard(margin: margin, template: TemplateType.small);
}

/// Whether the user has paid ads away.
///
/// Read off the singleton rather than through the widget tree because the ad
/// widgets need it in `initState`, where `context.watch` is illegal. Their
/// `build` methods still watch the provider so the UI reacts to a purchase.
bool get _isPremium => BillingService.instance.isPremium;

/// Self-contained banner: loads its own ad, disposes it, and renders nothing
/// until (and unless) the ad actually loads.
class AdaptiveBannerAd extends StatefulWidget {
  const AdaptiveBannerAd({
    super.key,
    this.margin,
    this.bare = false,
    this.adUnitId = AdUnits.banner,
  });

  final EdgeInsets? margin;

  /// `true` renders just the ad; `false` wraps it in the "Sponsored" card.
  final bool bare;

  final String adUnitId;

  @override
  State<AdaptiveBannerAd> createState() => _AdaptiveBannerAdState();
}

class _AdaptiveBannerAdState extends State<AdaptiveBannerAd> {
  BannerAd? _ad;
  bool _loaded = false;

  /// A single "no fill" is normal for a low-traffic unit; retry a few times
  /// with backoff before giving up and collapsing the slot.
  static const int _maxAttempts = 3;
  int _attempt = 0;
  Timer? _retryTimer;

  /// `true` once every attempt has failed — the slot collapses for good.
  bool _givenUp = false;

  @override
  void initState() {
    super.initState();

    // The listener is attached ALWAYS, premium or not.
    //
    // It used to be skipped for a premium user, together with the load. That
    // made the gate one-way: a banner mounted while premium never learned the
    // subscription had lapsed, so after expiry every other format came back
    // (their loaders are called repeatedly from elsewhere) while banners —
    // which only load here, once, in initState — stayed dead for good.
    BillingService.instance.addListener(_onPremiumChanged);

    // A premium user must not even generate an ad *request*. main.dart skips
    // `MobileAds.initialize()` and the manager's own load paths are gated, but
    // this widget loads its own BannerAd, so without this a subscriber would
    // still see banners.
    if (_isPremium) return;

    _load();
  }

  /// Tears the banner down the moment a purchase completes, without waiting for
  /// the screen to be rebuilt by something else.
  /// Reacts to the entitlement flipping in EITHER direction.
  ///
  /// Premium on  -> tear the ad down now, don't wait for a rebuild.
  /// Premium off -> start loading again. This half was missing, which is what
  ///                left banners blank for the rest of the install once a
  ///                subscription lapsed.
  void _onPremiumChanged() {
    if (!mounted) return;

    if (_isPremium) {
      _retryTimer?.cancel();
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      setState(() {});
      return;
    }

    // Back to free. Nothing to do if an ad is already in hand or in flight.
    if (_ad != null || _loaded) return;

    // Fresh budget: the attempts burned before (or while) the user was premium
    // must not count against them now.
    _retryTimer?.cancel();
    _attempt = 0;
    _givenUp = false;
    _load();
    setState(() {});
  }

  void _load() {
    // Last line of defence. The retry Timer below fires up to three times over
    // ~30s, and a purchase can complete in that window: [_onPremiumChanged]
    // cancels the timer, but a callback already queued on the event loop still
    // runs. Without this a subscriber could still emit one request.
    if (_isPremium) return;

    _attempt++;

    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('✅ Banner loaded (${widget.adUnitId})');
          if (!mounted) {
            // Widget disappeared while the ad was in flight.
            _ad?.dispose();
            _ad = null;
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          // code 0=internal, 1=invalid request, 2=network, 3=no fill.
          debugPrint(
            '❌ Banner failed (attempt $_attempt/$_maxAttempts) '
            'code=${error.code} domain=${error.domain} msg=${error.message}',
          );
          ad.dispose();
          if (!mounted) return;

          if (_attempt >= _maxAttempts) {
            setState(() {
              _ad = null;
              _loaded = false;
              _givenUp = true;
            });
            return;
          }

          setState(() {
            _ad = null;
            _loaded = false;
          });

          _retryTimer?.cancel();
          // 30s, 60s — not 5s.
          //
          // A 5-second retry lands inside AdMob's own rate limiter, which
          // answers "Too many recently failed requests for ad unit ID" (code
          // 1) instead of making a real request. Attempts 2 and 3 were being
          // spent on that error, so a unit that was merely short on fill got
          // one genuine try before the slot gave up for good.
          _retryTimer = Timer(Duration(seconds: 30 * _attempt), () {
            if (mounted) _load();
          });
        },
      ),
    );

    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    BillingService.instance.removeListener(_onPremiumChanged);
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Collapse to nothing — NOT to the 50px placeholder below. Reserving the
    // banner's height for a user who will never see a banner is exactly the
    // blank gap that showed up after subscribing.
    if (context.watch<BillingService>().isPremium) {
      return const SizedBox.shrink();
    }

    final ad = _ad;
    if (!_loaded || ad == null) {
      // Hold the banner's height while attempts are still in flight so a late
      // ad doesn't shove the layout around; collapse once we've given up.
      if (_givenUp) return const SizedBox.shrink();
      return const SizedBox(height: 50);
    }

    final adView = SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );

    if (widget.bare) return adView;

    final lang = context.watch<LocaleProvider>().locale.languageCode;
    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                MiscStrings.t(lang, 'ads_sponsored'),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: adView,
          ),
        ],
      ),
    );
  }
}

/// Self-contained native ad: loads its own [NativeAd], disposes it, and
/// renders nothing until (and unless) it fills.
///
/// Rendered with the plugin's native template rather than a custom factory —
/// the template already carries the "Ad" attribution badge AdMob requires, so
/// there is nothing here that can accidentally present an ad as app content.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({
    super.key,
    this.margin,
    this.template = TemplateType.medium,
    this.adUnitId = AdUnits.native,
  });

  final EdgeInsets? margin;
  final TemplateType template;
  final String adUnitId;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  /// Matches the banner's policy: a single "no fill" is normal on a
  /// low-traffic unit, so retry a few times before collapsing the slot.
  static const int _maxAttempts = 3;
  int _attempt = 0;
  Timer? _retryTimer;
  bool _givenUp = false;

  /// The height the slot is always given.
  ///
  /// [AdWidget] has no intrinsic size — it fills whatever it is handed — so
  /// the template's Android layout, whose own heights are `wrap_content`, is
  /// measured against exactly this number. Give it less than the creative
  /// needs and the asset views end up outside the ad view: the SDK's
  /// validator reports "not all asset views lie inside the native ad view"
  /// and the ad draws clipped or blank.
  ///
  /// A *range* is not a fix — under loose constraints the widget settles at
  /// the minimum, which is the same clipping with extra steps — and neither
  /// is the documented 400 maximum for [TemplateType.medium]: that template
  /// carries a full-width media view, so a creative with a square image wants
  /// roughly the screen's width plus another 180 for the header, body and
  /// call to action. 400 fits a 16:9 image and clips a square one, which is
  /// why it failed on some ads and not others.
  ///
  /// [TemplateType.small] has an icon rather than a media view, so its height
  /// barely varies with the creative. That is why it is what this app uses.
  ///
  /// Its 200 was picked as "comfortably more than enough" and was — measured
  /// on device, the template draws about 96 logical pixels, so a little over
  /// half the slot was transparent and the page background showed through as
  /// a band of empty space under every native ad. 150 still leaves ~50% over
  /// the tallest the layout gets (icon row + a two-line body + the call to
  /// action), which is the headroom this comment is about; it is deliberately
  /// not trimmed to the measured 96.
  double get _height => widget.template == TemplateType.small ? 150 : 600;

  @override
  void initState() {
    super.initState();

    // Attached unconditionally, so this card also recovers when a
    // subscription lapses — see [_AdaptiveBannerAdState.initState].
    BillingService.instance.addListener(_onPremiumChanged);

    // No ad request at all for a subscriber.
    if (_isPremium) return;

    // Deferred to the first frame: the template is styled from the active
    // theme, which is not resolvable during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Re-checked: a purchase can complete between initState and this frame.
      if (mounted && !_isPremium) _load();
    });
  }

  /// Reacts to the entitlement flipping in EITHER direction.
  ///
  /// Premium on  -> tear the ad down now, don't wait for a rebuild.
  /// Premium off -> start loading again. This half was missing, which is what
  ///                left banners blank for the rest of the install once a
  ///                subscription lapsed.
  void _onPremiumChanged() {
    if (!mounted) return;

    if (_isPremium) {
      _retryTimer?.cancel();
      _ad?.dispose();
      _ad = null;
      _loaded = false;
      setState(() {});
      return;
    }

    // Back to free. Nothing to do if an ad is already in hand or in flight.
    if (_ad != null || _loaded) return;

    // Fresh budget: the attempts burned before (or while) the user was premium
    // must not count against them now.
    _retryTimer?.cancel();
    _attempt = 0;
    _givenUp = false;
    // The native template needs a themed context, which is only safe after a
    // frame — same reason initState defers its first load.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isPremium) _load();
    });
    setState(() {});
  }

  @override
  void dispose() {
    BillingService.instance.removeListener(_onPremiumChanged);
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  void _load() {
    // See [_AdaptiveBannerAdState._load].
    if (_isPremium) return;

    _attempt++;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = dark ? Colors.white : const Color(0xFF111827);

    final ad = NativeAd(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.template,
        mainBackgroundColor: dark ? const Color(0xFF1E293B) : Colors.white,
        cornerRadius: 12,
        primaryTextStyle: NativeTemplateTextStyle(textColor: onSurface),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: dark ? Colors.white70 : const Color(0xFF4B5563),
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: dark ? Colors.white38 : const Color(0xFF9CA3AF),
        ),
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: ColorSelect.maineColor,
        ),
      ),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          debugPrint('✅ Native loaded (${widget.adUnitId})');
          if (!mounted) {
            _ad?.dispose();
            _ad = null;
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
            '❌ Native failed (attempt $_attempt/$_maxAttempts) '
            'code=${error.code} msg=${error.message}',
          );
          ad.dispose();
          if (!mounted) return;

          if (_attempt >= _maxAttempts) {
            setState(() {
              _ad = null;
              _loaded = false;
              _givenUp = true;
            });
            return;
          }

          setState(() {
            _ad = null;
            _loaded = false;
          });

          _retryTimer?.cancel();
          // 30s, 60s — not 5s.
          //
          // A 5-second retry lands inside AdMob's own rate limiter, which
          // answers "Too many recently failed requests for ad unit ID" (code
          // 1) instead of making a real request. Attempts 2 and 3 were being
          // spent on that error, so a unit that was merely short on fill got
          // one genuine try before the slot gave up for good.
          _retryTimer = Timer(Duration(seconds: 30 * _attempt), () {
            if (mounted) _load();
          });
        },
      ),
    );

    _ad = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    // See [_AdaptiveBannerAdState.build]: collapse fully rather than holding
    // `_height` (200–600px) open for an ad that will never arrive.
    if (context.watch<BillingService>().isPremium) {
      return const SizedBox.shrink();
    }

    final ad = _ad;
    if (!_loaded || ad == null) {
      if (_givenUp) return const SizedBox.shrink();
      return SizedBox(height: _height);
    }

    final lang = context.watch<LocaleProvider>().locale.languageCode;

    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 4),
              child: Text(
                MiscStrings.t(lang, 'ads_sponsored'),
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ),
          SizedBox(height: _height, child: AdWidget(ad: ad)),
        ],
      ),
    );
  }
}
