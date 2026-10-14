// Saari ad settings ek jagah. Values pehli (Kotlin) app ke ad_config.json jaisi hain.
// Firebase Remote Config se JSON laakar AdConfig.fromJson() se badal sakte ho.

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Ad nahi mila to agla kaunsa try kare.
enum AdKind { native, banner, house }

class HouseAd {
  final String title;
  final String body;
  final String callToAction;
  final String targetUrl; // Play Store link
  final String? iconAsset; // assets/... (offline bhi chalega)

  const HouseAd({
    required this.title,
    required this.body,
    required this.targetUrl,
    this.callToAction = 'Install',
    this.iconAsset,
  });

  factory HouseAd.fromJson(Map<String, dynamic> j) => HouseAd(
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        callToAction: j['callToAction'] as String? ?? 'Install',
        targetUrl: j['targetUrl'] as String? ?? '',
        iconAsset: j['iconAsset'] as String?,
      );
}

class AdConfig {
  // ---------- Unit IDs (abhi Google ke TEST IDs hain; release se pehle apne daalo) ----------
  String appOpenUnitId = 'ca-app-pub-3940256099942544/9257395921';
  String interstitialUnitId = 'ca-app-pub-3940256099942544/1033173712';
  String bannerUnitId = 'ca-app-pub-3940256099942544/9214589741';
  String nativeUnitId = 'ca-app-pub-3940256099942544/2247696110';
  String nativeNoVideoUnitId = ''; // khali ho to nativeUnitId use hoga
  String rewardedUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // ---------- On / off ----------
  bool isPremium = false; // true = koi ad nahi
  bool appOpenEnabled = true;
  bool interstitialEnabled = true;
  bool bannerEnabled = true;
  bool nativeEnabled = true;
  bool rewardedEnabled = true;
  bool houseAdsEnabled = true; // offline / no-fill par apni apps ka promo

  // ---------- App Open ----------
  int appOpenBufferSize = 1;
  int appOpenCooldownSec = 240; // 4 min between App Opens
  int appOpenMinBackgroundSec = 30; // quick app switches don't earn one
  int splashWaitMs = 1500;
  Set<String> appOpenExcludedScreens = {};

  // ---------- Interstitial ----------
  int interstitialBufferSize = 1;
  int interstitialIntervalSec = 90; // do interstitial ke beech kam se kam
  int interstitialScreenIntervalCount = 3; // har 3rd action par
  int fullscreenHardCooldownSec = 20; // kisi bhi fullscreen ad ke baad gap
  int interstitialSessionCap = 6; // ek session mein max (0 = koi limit nahi)

  // ---------- Native pool ----------
  int nativeBufferTarget = 2;
  int nativeMaxBuffer = 3;
  int nativePrefetchThreshold = 1; // itne ya kam bache to refill
  int nativeWaitMs = 4000; // itni der native na mile to agla AdKind
  int feedStartPosition = 2; // list mein pehla ad kis index par
  int feedInterval = 6; // phir har kitne items baad

  // ---------- Banner ----------
  int bannerBufferSize = 2; // next screen's bottom bar finds one ready
  int bannerMaxRetry = 3;

  // ---------- Fallback order (pehli app jaisa) ----------
  List<AdKind> nativeSequence = [AdKind.native, AdKind.banner, AdKind.house];
  // No native fallback in the bottom bar: a 120px native is too tall there.
  List<AdKind> bannerSequence = [AdKind.banner, AdKind.house];

  // TODO: apni dusri apps yahan daalo. Khali list = house ad nahi, slot placeholder ke baad band.
  // Example:
  // HouseAd(title: 'File Manager', body: '...', iconAsset: 'assets/house/fm.png',
  //   targetUrl: 'https://play.google.com/store/apps/details?id=your.package'),
  List<HouseAd> houseAds = const [];

  bool enableLogs = kDebugMode;

  /// Devices that always get test ads (release/profile testing on a handset).
  List<String> testDeviceIds = const [];

  // ---------- helpers ----------
  bool get adsAllowed => !isPremium;
  String get nativeSmallUnitId =>
      nativeNoVideoUnitId.isNotEmpty ? nativeNoVideoUnitId : nativeUnitId;

  /// Remote Config / JSON se values update. Jo key nahi hai wo purani value rahegi.
  void updateFromJson(Map<String, dynamic> j) {
    T v<T>(String k, T old) => j[k] is T ? j[k] as T : old;
    appOpenUnitId = v('appOpenUnitId', appOpenUnitId);
    interstitialUnitId = v('interstitialUnitId', interstitialUnitId);
    bannerUnitId = v('bannerUnitId', bannerUnitId);
    nativeUnitId = v('nativeUnitId', nativeUnitId);
    nativeNoVideoUnitId = v('nativeNoVideoUnitId', nativeNoVideoUnitId);
    rewardedUnitId = v('rewardedUnitId', rewardedUnitId);
    isPremium = v('isPremium', isPremium);
    appOpenEnabled = v('isAppOpenEnabled', appOpenEnabled);
    interstitialEnabled = v('isInterstitialEnabled', interstitialEnabled);
    bannerEnabled = v('isBannerEnabled', bannerEnabled);
    nativeEnabled = v('nativeEnabled', nativeEnabled);
    rewardedEnabled = v('isRewardedEnabled', rewardedEnabled);
    houseAdsEnabled = v('isCpEnabled', houseAdsEnabled);
    appOpenCooldownSec = v('appOpenCooldownSec', appOpenCooldownSec);
    appOpenMinBackgroundSec = v('appOpenMinBackgroundSec', appOpenMinBackgroundSec);
    interstitialIntervalSec = v('interstitialIntervalSec', interstitialIntervalSec);
    interstitialScreenIntervalCount =
        v('interstitialScreenIntervalCount', interstitialScreenIntervalCount);
    fullscreenHardCooldownSec = v('interstitialHardCooldownSec', fullscreenHardCooldownSec);
    interstitialSessionCap = v('interstitialSessionCap', interstitialSessionCap);
    nativeBufferTarget = v('nativeBufferTarget', nativeBufferTarget);
    nativeMaxBuffer = v('nativeMaxBuffer', nativeMaxBuffer);
    nativePrefetchThreshold = v('nativePrefetchThreshold', nativePrefetchThreshold);
    feedStartPosition = v('nativeStartPosition', feedStartPosition);
    feedInterval = v('nativeInterval', feedInterval);
    enableLogs = v('enableLogs', enableLogs);
    final excluded = j['appOpenExcludedScreens'];
    if (excluded is List) appOpenExcludedScreens = excluded.whereType<String>().toSet();
    final cp = j['cpAds'];
    if (cp is List) {
      houseAds = cp.whereType<Map<String, dynamic>>().map(HouseAd.fromJson).toList();
    }
  }
}

/// Global config + chhote helpers jo sab managers use karte hain.
class Ads {
  Ads._();
  static final AdConfig config = AdConfig();

  /// Koi bhi fullscreen ad (App Open / Interstitial) abhi dikh raha hai?
  static bool fullscreenShowing = false;
  static DateTime? lastFullscreenAt;

  /// Ad click karke browser gaye, wapas aaye -> App Open mat dikhao.
  static bool skipNextResume = false;

  /// Consent mil gaya aur SDK init ho gaya. Iske bina koi view-ad request nahi
  /// jaati (UMP consent se pehle ad request = policy violation).
  static bool sdkReady = false;

  /// App background se wapas aaye tab chalne wale kaam (pools refresh etc.).
  /// AppStateEventNotifier ko sirf EK jagah suna jata hai (AppOpenManager),
  /// isliye baaki kaam yahan register karo.
  static final List<void Function()> foregroundHooks = [];

  static int _houseIndex = 0;
  static HouseAd? nextHouseAd() {
    if (!config.houseAdsEnabled || config.houseAds.isEmpty) return null;
    final ad = config.houseAds[_houseIndex % config.houseAds.length];
    _houseIndex++;
    return ad;
  }

  static void log(String tag, String msg) {
    if (config.enableLogs) debugPrint('[Ads/$tag] $msg');
  }

  static AdRequest request() => const AdRequest();
}
