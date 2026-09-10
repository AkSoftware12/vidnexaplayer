import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../Billing/billing_service.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/misc_strings.dart';
import '../Utils/app_palette.dart';
import '../Utils/color.dart';
import 'app_open_ad_manager.dart';
import 'rewarded_unlock.dart';

/// Asks whether the user wants to watch a rewarded ad to unlock [feature], and
/// returns whether they may now proceed.
///
/// This is the opt-in screen AdMob requires in front of a rewarded ad — and
/// requires explicitly in front of a rewarded *interstitial*. It names the
/// reward, says plainly that it is a video ad, and the decline button is a
/// real one: saying no closes the sheet and nothing else happens.
///
/// Three cases return true without an ad being shown:
///
/// * the window from an earlier ad is still open — one ad, thirty minutes,
///   not one ad per tap;
/// * no ad could be loaded — a user must never lose a feature because our
///   inventory was empty, so the unlock is granted anyway;
/// * the user watched to the end and earned it.
///
/// Returns false only when the user declined, or closed the ad early. Closing
/// early earns nothing — that is how rewarded ads work — so the caller should
/// say so rather than silently doing nothing.
Future<bool> ensureRewardedUnlock(
  BuildContext context, {
  required String feature,
  required String titleKey,
  required String bodyKey,
}) async {
  // Premium owns these outright — no ad, no 30-minute window, no prompt.
  // Checked before the stored unlock so a paying user never writes an
  // expiring window that would start gating them again if it were ever read
  // without this guard.
  if (BillingService.instance.isPremium) return true;

  final unlocks = RewardedUnlock.instance;
  if (await unlocks.isUnlocked(feature)) return true;
  if (!context.mounted) return false;

  final manager = AppOpenAdManager();

  // Nothing to offer. Grant it rather than dangling a prompt that cannot pay
  // out — and rather than gating the feature on our own fill rate.
  if (!manager.hasRewardedAd) {
    await unlocks.unlock(feature);
    return true;
  }

  final lang = context.read<LocaleProvider>().locale.languageCode;
  final messenger = ScaffoldMessenger.of(context);

  final accepted = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => _RewardedSheet(
      lang: lang,
      titleKey: titleKey,
      bodyKey: bodyKey,
      onDecline: () => Navigator.pop(sheetContext, false),
      onAccept: () => Navigator.pop(sheetContext, true),
    ),
  );

  if (accepted != true) return false;

  final earned = await manager.showRewarded();

  if (!earned) {
    // Either they closed it early, or the ad failed on the way up. The first
    // is their choice; the second is ours to absorb, so only a genuine
    // dismissal leaves the feature locked.
    if (manager.hasRewardedAd) {
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(MiscStrings.t(lang, 'rewarded_incomplete')),
        ),
      );
      return false;
    }
    await unlocks.unlock(feature);
    return true;
  }

  await unlocks.unlock(feature);
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(
        MiscStrings.t(lang, 'rewarded_unlocked')
            .replaceAll('{minutes}', '${RewardedUnlock.window.inMinutes}'),
      ),
    ),
  );
  return true;
}

class _RewardedSheet extends StatelessWidget {
  const _RewardedSheet({
    required this.lang,
    required this.titleKey,
    required this.bodyKey,
    required this.onAccept,
    required this.onDecline,
  });

  final String lang;
  final String titleKey;
  final String bodyKey;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    AppPalette.sync(context);
    final accent = ColorSelect.maineColor;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.all(12.sp),
        padding: EdgeInsets.fromLTRB(18.sp, 16.sp, 18.sp, 14.sp),
        decoration: BoxDecoration(
          color: AppPalette.card,
          borderRadius: BorderRadius.circular(18.sp),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40.sp,
                  height: 40.sp,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.sp),
                  ),
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: accent,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.sp),
                Expanded(
                  child: Text(
                    MiscStrings.t(lang, titleKey),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppPalette.textH,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.sp),
            Text(
              MiscStrings.t(lang, bodyKey)
                  .replaceAll('{minutes}', '${RewardedUnlock.window.inMinutes}'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                height: 1.45,
                color: AppPalette.textB,
              ),
            ),
            SizedBox(height: 16.sp),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDecline,
                  child: Text(
                    MiscStrings.t(lang, 'rewarded_not_now'),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: AppPalette.textS,
                    ),
                  ),
                ),
                SizedBox(width: 6.sp),
                ElevatedButton.icon(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.sp,
                      vertical: 10.sp,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.sp),
                    ),
                  ),
                  icon: Icon(Icons.smart_display_outlined, size: 17.sp),
                  label: Text(
                    MiscStrings.t(lang, 'rewarded_watch'),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
