import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'screen_analytics.dart';

/// Onboarding ka drop-off funnel: kaunsi slide par log app chhod dete hain.
///
/// Har slide ek `screen_view` bhi bhejti hai (`OnboardingScreen_1` … `_4`)
/// taaki har slide par bitaaya waqt bhi mile — funnel events uske upar hain,
/// unse pata chalta hai ki user aage badha, skip kiya, ya nikal gaya:
///
/// ```
/// tutorial_begin
///   → onboarding_step (step: 1)
///   → onboarding_step (step: 2) …
///   → onboarding_skip (from_step: N)   [agar Skip dabaya]
///   → tutorial_complete                [agar "Get Started" dabaya]
///   → PermissionScreen ka screen_view
/// ```
///
/// GA4 me Explore → Funnel exploration banate waqt yahi events steps ban
/// jaate hain. `tutorial_begin` / `tutorial_complete` GA4 ke recommended
/// event names hain, isliye woh apne aap theek se render hote hain.
class OnboardingAnalytics {
  OnboardingAnalytics._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Slide index (0-based) ka screen name. Slides ke liye wahi
  /// `<Parent>_<Part>` convention jo gallery/music tabs me hai.
  static String screenName(int index) => 'OnboardingScreen_${index + 1}';

  /// Onboarding pehli baar khuli. Har visit par ek hi baar.
  static void begin() {
    unawaited(safeLogAnalytics(() => _analytics.logTutorialBegin()));
    if (kDebugMode) debugPrint('📊 tutorial_begin');
  }

  /// Slide dikhi — funnel ka ek step, aur us slide ka screen bhi.
  ///
  /// [index] 0-based hai, [total] slides ki ginti (`contents.length`), taaki
  /// slide jodne par funnel apne aap chauda ho jaaye.
  static void stepViewed(int index, int total) {
    if (index < 0 || index >= total) return;

    ScreenAnalytics.instance.setScreen(screenName(index));

    unawaited(safeLogAnalytics(() => _analytics.logEvent(
          name: 'onboarding_step',
          parameters: <String, Object>{
            // 1-based, kyunki funnel report me "step 0" padhne me ajeeb hai.
            'step': index + 1,
            'total_steps': total,
            'screen_name': screenName(index),
          },
        )));
    if (kDebugMode) debugPrint('📊 onboarding_step → ${index + 1}/$total');
  }

  /// Skip dabaya. Jis slide se skip hua wahi asli drop-off point hai —
  /// jump ke baad aakhri slide dikhti hai, isliye usse pata nahi chalta.
  static void skipped(int fromIndex) {
    unawaited(safeLogAnalytics(() => _analytics.logEvent(
          name: 'onboarding_skip',
          parameters: <String, Object>{
            'from_step': fromIndex + 1,
            'screen_name': screenName(fromIndex),
          },
        )));
    if (kDebugMode) debugPrint('📊 onboarding_skip → from ${fromIndex + 1}');
  }

  /// "Get Started" dabaya — onboarding poora hua.
  static void completed({required bool skipped}) {
    unawaited(safeLogAnalytics(() => _analytics.logTutorialComplete()));
    unawaited(safeLogAnalytics(() => _analytics.logEvent(
          name: 'onboarding_complete',
          parameters: <String, Object>{'skipped': skipped ? 1 : 0},
        )));
    if (kDebugMode) debugPrint('📊 tutorial_complete (skipped: $skipped)');
  }
}
