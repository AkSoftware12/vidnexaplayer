import 'package:in_app_review/in_app_review.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/misc_strings.dart';
import 'package:videoplayer/ads/ads_manager.dart';

/// Asks for a Play rating through Google's In-App Review API.
///
/// This replaced a custom star sheet that sent only 4–5 star ratings to the
/// Play Store and diverted 1–3 stars into a private box. That is review
/// gating, which Google's rating guidelines forbid. The system sheet shown
/// here asks nothing first and treats every rating the same.
///
/// Timing state is persisted in SharedPreferences. Play also applies its own
/// quota and may silently decide not to show the sheet, so a call here is a
/// request, not a guarantee — there is deliberately no UI of our own around it.
class RatingPopup {
  RatingPopup._();

  // ---- Config ----
  static const int minLaunches = 5;
  static const int coolDownDays = 30;
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer';

  // ---- Persisted keys ----
  static const String _kLaunchCount = 'rating_launch_count';
  static const String _kLastShownMs = 'rating_last_shown_ms';

  static bool _requestedThisSession = false;

  /// Call once per app open.
  static Future<void> onAppOpen(BuildContext context) async {
    if (_requestedThisSession) return;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final launchCount = (prefs.getInt(_kLaunchCount) ?? 0) + 1;
    await prefs.setInt(_kLaunchCount, launchCount);

    final lastShownMs = prefs.getInt(_kLastShownMs) ?? 0;
    final cooldownOver = lastShownMs == 0 ||
        nowMs - lastShownMs >= const Duration(days: coolDownDays).inMilliseconds;
    if (launchCount < minLaunches || !cooldownOver) return;

    try {
      final review = InAppReview.instance;
      if (!await review.isAvailable()) return;
      _requestedThisSession = true;
      await prefs.setInt(_kLastShownMs, nowMs);
      await prefs.setInt(_kLaunchCount, 0);
      AdsManager.skipNextAppOpen();
      await review.requestReview();
    } catch (e) {
      debugPrint('In-app review request failed: $e');
    }
  }

  /// Opens the Play listing, for an explicit "Rate us" tap in settings.
  static Future<void> openStore(BuildContext context) async {
    bool opened = false;
    try {
      AdsManager.skipNextAppOpen();
      opened = await launchUrl(
        Uri.parse(playStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      final lang = context.read<LocaleProvider>().locale.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MiscStrings.t(lang, 'rating_playstore_open_failed')),
        ),
      );
    }
  }
}
