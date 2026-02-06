import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppOpenAdManager with WidgetsBindingObserver {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;

  static const String _adUnitId =
      'ca-app-pub-6478840988045325/9137962029'; // ✅ TEST ID

  static const int _dailyLimit = 2;
  static const int _cooldownMinutes = 10;

  void init() {
    WidgetsBinding.instance.addObserver(this);
    loadAd();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appOpenAd?.dispose();
  }

  /// 🔁 App resume listener
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      showAdIfAvailable(() {});
    }
  }

  void loadAd() {
    AppOpenAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ App Open Ad Loaded');
          debugPrint('✅ _adUnitId:$_adUnitId');
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
}
