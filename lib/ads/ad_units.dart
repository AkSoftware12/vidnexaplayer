import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:material_ui/material_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Utils/app_palette.dart';
import '../Utils/color.dart';
import 'ads_manager.dart';

/// Ad unit ids in one place instead of scattered string literals.
///
/// In debug builds these resolve to Google's **official sample unit ids**,
/// which always fill. Relying on `testDeviceIds` instead is fragile: an id
/// registered for a different handset means every request goes out as live
/// traffic, and a unit without inventory answers "No fill" (error code 3).
class AdUnits {
  AdUnits._();

  // ---- Live units (release builds) ----
  static const String _liveAppOpen = 'ca-app-pub-6478840988045325/9137962029';
  static const String _liveBanner = 'ca-app-pub-6478840988045325/7764390357';
  static const String _liveInterstitial = 'ca-app-pub-6478840988045325/2955697053';
  static const String _liveNative = 'ca-app-pub-6478840988045325/9759998301';
  static const String _liveRewarded = 'ca-app-pub-6478840988045325/2605437798';

  // ---- Google's public test units (debug builds) ----
  // https://developers.google.com/admob/android/test-ads
  static const String _testAppOpen = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testBanner = 'ca-app-pub-3940256099942544/9214589741'; // adaptive
  static const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testNative = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  static const String appOpen = kDebugMode ? _testAppOpen : _liveAppOpen;
  static const String banner = kDebugMode ? _testBanner : _liveBanner;
  static const String interstitial =
      kDebugMode ? _testInterstitial : _liveInterstitial;
  static const String native = kDebugMode ? _testNative : _liveNative;
  static const String rewarded = kDebugMode ? _testRewarded : _liveRewarded;
}

/// Points [Ads.config] at this app's units, premium state and player screens.
/// Call once, before [AdsManager.init].
void configureAds({required bool isPremium}) {
  Ads.config
    ..isPremium = isPremium
    ..appOpenUnitId = AdUnits.appOpen
    ..interstitialUnitId = AdUnits.interstitial
    ..bannerUnitId = AdUnits.banner
    ..nativeUnitId = AdUnits.native
    ..rewardedUnitId = AdUnits.rewarded
    // No App Open on top of a playing video.
    ..appOpenExcludedScreens = {'VideoPlayerScreen', 'VaultVideoPlayer'}
    // Find a device's id in logcat: "Use RequestConfiguration.Builder()
    // .setTestDeviceIds(Arrays.asList("XXXXXXXX")) to get test ads".
    ..testDeviceIds = const [
      '25240AE534A134DAFD363D1E9144746F', // AI Nova 2 Pro
      'D55A05AC5F182B8B7343029E881273E8', // Samsung SM-A505F
      '05B5C242534D4508DE3D9FF83044AED8', // (older dev device)
    ];

  unawaited(_clearLegacyAdPrefs());

  // Native ads are styled when they load, from the theme active at that time.
  NativeAdPool.styleBuilder = (type) {
    final dark = AppPalette.isDark;
    return NativeTemplateStyle(
      templateType: type,
      mainBackgroundColor: dark ? const Color(0xFF1E293B) : Colors.white,
      cornerRadius: 12,
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: dark ? Colors.white : const Color(0xFF111827),
      ),
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
    );
  };
}

/// The old ad manager's daily caps and cooldown stamps. Nothing reads them any
/// more; removed so they don't linger in every install.
Future<void> _clearLegacyAdPrefs() async {
  const keys = [
    'aoa_date', 'aoa_count', 'aoa_last_time', //
    'int_date', 'int_day_count', 'int_last_time', 'int_action_count',
  ];
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final k in keys) {
      if (prefs.containsKey(k)) await prefs.remove(k);
    }
  } catch (_) {}
}
