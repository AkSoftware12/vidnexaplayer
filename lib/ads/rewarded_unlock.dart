import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Features that a rewarded ad can unlock, and for how long the unlock lasts.
///
/// A rewarded ad buys a *window*, not a single use. Charging one ad per photo
/// would mean four ads to enhance four photos, which is the kind of pacing
/// that gets an app uninstalled rather than monetised.
class RewardedUnlock {
  RewardedUnlock._();

  static final RewardedUnlock instance = RewardedUnlock._();

  /// The Enhance-to-4K tool. The heaviest thing the gallery does — a full
  /// resample and sharpen pass per photo — so it is the one place where asking
  /// for something in return is honest.
  static const String enhance4k = 'enhance_4k';

  /// Saving a filtered photo. A separate key from [enhance4k] on purpose:
  /// each tool's window is its own, so an ad watched to save a filter does
  /// not quietly hand over 4K enhance as well, and vice versa. They are
  /// stored under different preference keys and expire independently.
  static const String filters = 'filters';

  /// Saving a WhatsApp status to the gallery.
  ///
  /// Its own key, like the tools above: an ad watched to save a status opens a
  /// window for saving statuses only, and expires on its own schedule.
  static const String statusSaver = 'status_saver';

  static const Duration window = Duration(minutes: 30);

  static String _key(String feature) => 'rewarded_unlock_$feature';

  /// Whether [feature] is currently unlocked.
  ///
  /// Returns false on any storage failure — never throws. The caller then
  /// offers the ad, which is the recoverable direction to fail in.
  Future<bool> isUnlocked(String feature) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_key(feature));
      if (until == null) return false;
      return DateTime.now().millisecondsSinceEpoch < until;
    } catch (error) {
      debugPrint('RewardedUnlock.isUnlocked failed: $error');
      return false;
    }
  }

  /// Opens the unlock window for [feature]. Called only after a reward was
  /// actually earned, or when no ad could be served at all.
  Future<void> unlock(String feature, {Duration duration = window}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _key(feature),
        DateTime.now().add(duration).millisecondsSinceEpoch,
      );
    } catch (error) {
      debugPrint('RewardedUnlock.unlock failed: $error');
    }
  }
}
