import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;

  static const String _adUnitId =
      'ca-app-pub-6478840988045325/9137962029'; // ✅ APP OPEN ID (aapka)

  static const int _dailyLimit = 2;
  static const int _cooldownMinutes = 10;

  // =========================
  // ✅ BANNER
  // =========================
  static const String _bannerUnitId =
      'ca-app-pub-6478840988045325/7764390357'; // ✅ Banner ID (aapka)

  BannerAd? banner;
  final ValueNotifier<BannerAd?> bannerNotifier = ValueNotifier<BannerAd?>(null);

  // =========================
  // ✅ INTERSTITIAL (ADDED)
  // =========================
  static const String _interstitialUnitId =
      'ca-app-pub-6478840988045325/2955697053'; // ✅ Interstitial ID (yaha apna lagao)

  InterstitialAd? _interstitialAd;
  bool _isInterstitialLoading = false;

  // ✅ Frequency control (har click pe nahi)
  int interstitialShowAfterActions = 3; // every 3 actions
  int _actionCount = 0;

  // ✅ Cooldown control
  Duration interstitialCooldown = const Duration(seconds: 35);
  DateTime _lastInterstitialShown = DateTime.fromMillisecondsSinceEpoch(0);

  // =========================
  // INIT / DISPOSE
  // =========================
  void init() {
    WidgetsBinding.instance.addObserver(this);

    // ✅ AppOpen
    loadAd();

    // ✅ Banner
    _loadBanner();

    // ✅ Interstitial (preload)
    _loadInterstitial();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _appOpenAd?.dispose();
    banner?.dispose();
    bannerNotifier.dispose();

    _interstitialAd?.dispose();
    _interstitialAd = null;
  }

  /// 🔁 App resume listener
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      showAdIfAvailable(() {});
    }
  }

  // =========================
  // ✅ APP OPEN
  // =========================
  void loadAd() {
    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ App Open Ad Loaded');
          _appOpenAd = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ App Open Ad failed: $error');
          _appOpenAd = null;
        },
      ),
    );
  }

  Future<bool> _canShowAd() async {
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

    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMinutes = (now - lastShown) / 60000;

    if (count >= _dailyLimit) return false;
    if (diffMinutes < _cooldownMinutes) return false;

    return true;
  }

  Future<void> _markShown() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('aoa_last_time', DateTime.now().millisecondsSinceEpoch);
    prefs.setInt('aoa_count', (prefs.getInt('aoa_count') ?? 0) + 1);
  }

  void showAdIfAvailable(VoidCallback onDone) async {
    if (_appOpenAd == null || _isShowingAd) {
      onDone();
      return;
    }

    if (!await _canShowAd()) {
      onDone();
      return;
    }

    _isShowingAd = true;

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _isShowingAd = false;
        await _markShown();
        loadAd();
        onDone();
      },
      onAdFailedToShowFullScreenContent: (ad, error) async {
        ad.dispose();
        _isShowingAd = false;
        loadAd();
        onDone();
      },
    );

    _appOpenAd!.show();
  }

  // =========================
  // ✅ INTERSTITIAL (ADDED)
  // =========================
  void _loadInterstitial() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Interstitial Loaded');
          _isInterstitialLoading = false;
          _interstitialAd = ad;

          _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial(); // reload for next time
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Interstitial failed to load: $error');
          _isInterstitialLoading = false;
          _interstitialAd = null;

          // light retry
          Future.delayed(const Duration(seconds: 25), () {
            _loadInterstitial();
          });
        },
      ),
    );
  }

  bool _canShowInterstitialNow() {
    final now = DateTime.now();
    final gapOk = now.difference(_lastInterstitialShown) >= interstitialCooldown;
    final countOk = (_actionCount % interstitialShowAfterActions == 0);
    return gapOk && countOk && _interstitialAd != null && !_isShowingAd;
  }

  /// ✅ Use this on Play / Open detail
  /// Example: appOpenManager.showInterstitialIfAllowed(onContinue: (){...});
  void showInterstitialIfAllowed({required VoidCallback onContinue}) {
    _actionCount++;

    if (_interstitialAd == null) {
      _loadInterstitial();
      onContinue();
      return;
    }

    if (!_canShowInterstitialNow()) {
      onContinue();
      return;
    }

    final ad = _interstitialAd!;
    _interstitialAd = null;
    _lastInterstitialShown = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        onContinue();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _loadInterstitial();
        onContinue();
      },
    );

    ad.show();
  }

  // =========================
  // ✅ BANNER
  // =========================
  void _loadBanner() {
    banner?.dispose();
    banner = BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ Banner loaded');
          bannerNotifier.value = banner;
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Banner failed: $error');
          ad.dispose();
          banner = null;
          bannerNotifier.value = null;
        },
      ),
    )..load();
  }

  Widget bannerWidgetBottomScreen() {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: bannerNotifier,
      builder: (context, ad, _) {
        if (ad == null) return const SizedBox.shrink();
        return SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        );
      },
    );
  }

  Widget bannerWidget({EdgeInsets? margin}) {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: bannerNotifier,
      builder: (context, ad, _) {
        if (ad == null) return const SizedBox.shrink();

        return Container(
          margin: margin ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
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
                  padding: const EdgeInsets.only(bottom: 4, right: 4),
                  child: Text(
                    "Sponsored",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
