import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // ---- Google's public test units (debug builds) ----
  // https://developers.google.com/admob/android/test-ads
  static const String _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  static const String appOpen = kDebugMode ? _testAppOpen : _liveAppOpen;
  static const String banner = kDebugMode ? _testBanner : _liveBanner;
  static const String interstitial =
      kDebugMode ? _testInterstitial : _liveInterstitial;
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
  // INIT
  // =========================================================
  bool _initialized = false;

  /// Safe to call more than once — extra calls are ignored.
  void init() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);

    // Restore the persisted frequency caps before anything can be shown.
    unawaited(_loadInterstitialState());

    loadAd();
    _loadInterstitial();
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

    final ad = _appOpenAd;
    if (ad == null || _isShowingAd) {
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
}

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
    _load();
  }

  void _load() {
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
          _retryTimer = Timer(Duration(seconds: 5 * _attempt), () {
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
    _retryTimer?.cancel();
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                'Sponsored',
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
