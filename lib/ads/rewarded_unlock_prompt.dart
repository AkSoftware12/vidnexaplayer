import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../Billing/billing_service.dart';
import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/misc_strings.dart';
import '../Utils/app_palette.dart';
import '../Utils/color.dart';
import 'ads_manager.dart';
import 'rewarded_unlock.dart';

/// Asks whether the user wants to watch a rewarded ad to unlock [feature], and
/// returns whether they may now proceed.
///
/// This is the opt-in screen AdMob requires in front of a rewarded ad. It
/// names the reward, says plainly that it is a video ad, and the decline
/// button is a real one: saying no closes the sheet and nothing else happens.
///
/// Returns true when the user is premium, the window from an earlier ad is
/// still open (one ad, one window: thirty minutes, two for HDR), or the user
/// watched to the end. The "Watch ad" button is only enabled while
/// [RewardedManager.isReady]; with no ad, or an ad closed early, the user is
/// told so and this returns false.
Future<bool> ensureRewardedUnlock(
  BuildContext context, {
  required String feature,
  required String titleKey,
  required String bodyKey,
  Widget? preview,
}) async {
  // Premium owns these outright — no ad, no 30-minute window, no prompt.
  // Checked before the stored unlock so a paying user never writes an
  // expiring window that would start gating them again if it were ever read
  // without this guard.
  if (BillingService.instance.isPremium) return true;

  final unlocks = RewardedUnlock.instance;
  if (await unlocks.isUnlocked(feature)) return true;
  if (!context.mounted) return false;

  final manager = RewardedManager.instance;
  final ready = await manager.isReady();
  if (!context.mounted) return false;

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
      preview: preview,
      minutes: RewardedUnlock.windowFor(feature).inMinutes,
      adReady: ready,
      onDecline: () => Navigator.pop(sheetContext, false),
      onAccept: () => Navigator.pop(sheetContext, true),
    ),
  );

  if (accepted != true) return false;

  final adShown = await manager.isReady();
  final earned = await manager.show();

  if (!earned) {
    // No ad to show, or the user closed it before the reward.
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(MiscStrings.t(
          lang,
          adShown ? 'rewarded_incomplete' : 'rewarded_unavailable',
        )),
      ),
    );
    return false;
  }

  await unlocks.unlock(feature);
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 2),
      content: Text(
        MiscStrings.t(lang, 'rewarded_unlocked')
            .replaceAll('{minutes}', '${RewardedUnlock.windowFor(feature).inMinutes}'),
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
    this.preview,
    required this.minutes,
    required this.adReady,
  });

  final String lang;
  final String titleKey;
  final String bodyKey;

  /// Optional picture of what the reward does, shown under the title — the
  /// HDR before/after, for one.
  final Widget? preview;

  /// Length of the unlock window this ad buys, for the body text.
  final int minutes;

  /// Whether a rewarded ad is loaded. The "Watch ad" button is disabled
  /// without one, rather than promising an ad we can't show.
  final bool adReady;
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
        // Scrolls rather than overflows: with a preview, the sheet can be
        // taller than a landscape video player's screen.
        child: SingleChildScrollView(
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
            if (preview != null) ...[
              SizedBox(height: 12.sp),
              preview!,
            ],
            SizedBox(height: 10.sp),
            Text(
              MiscStrings.t(lang, bodyKey)
                  .replaceAll('{minutes}', '$minutes'),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5.sp,
                height: 1.45,
                color: AppPalette.textB,
              ),
            ),
            if (!adReady) ...[
              SizedBox(height: 8.sp),
              Text(
                MiscStrings.t(lang, 'rewarded_unavailable'),
                style: TextStyle(fontFamily: 'Poppins', fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.textS,
                ),
              ),
            ],
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
                  onPressed: adReady ? onAccept : null,
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
      ),
    );
  }
}
