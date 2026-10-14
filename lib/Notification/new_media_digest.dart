import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../NotifyListeners/LanguageProvider/home_strings.dart';

/// Entry point WorkManager calls in a background isolate. Must be top-level
/// and kept from tree-shaking.
@pragma('vm:entry-point')
void newMediaDigestDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await NewMediaDigest.runCheck();
    } catch (e) {
      debugPrint('NewMediaDigest task failed: $e');
    }
    // Always "success": a failed check is retried tomorrow anyway, and a
    // retry storm would only drain battery for a reminder.
    return true;
  });
}

/// "New photos and videos today" — up to four notifications a day.
///
/// At each of [_slotHours] a WorkManager job counts the photos and videos
/// added since midnight and posts a notification with the totals; tapping it
/// opens the Gallery tab. Nothing is shown on a day with nothing new, and a
/// slot is skipped when nothing was added since the previous notification —
/// the same totals twice would only be noise. All slots replace one
/// notification (same id), so the shade never stacks them.
///
/// Built to stay well inside Play policy and battery limits:
/// * WorkManager, not exact alarms — no `SCHEDULE_EXACT_ALARM`, and Android
///   picks the moment, so each may arrive a little after its hour.
/// * Only reads what the user already granted: the permission state is
///   checked without prompting, and without photo access the job does
///   nothing.
/// * Its own notification channel, so it can be turned off in system settings
///   without losing other notifications — and an in-app switch on the Me
///   screen ([enabled]).
class NewMediaDigest {
  NewMediaDigest._();

  static const _uniqueName = 'vidnexa_new_media_digest';
  static const _prefEnabled = 'new_media_digest_enabled';

  /// "<day>:<photos>:<videos>" of the last notification shown, so a slot with
  /// nothing new since then stays quiet.
  static const _prefLastShown = 'new_media_digest_last_counts';

  /// Payload on the notification, so a tap can be told apart from a push.
  static const payload = 'new_media_digest';

  /// Local hours the reminders aim for — four a day, spread across waking
  /// hours. Each is its own daily WorkManager job.
  static const _slotHours = [10, 14, 18, 21];

  static String _slotName(int hour) => '${_uniqueName}_$hour';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'vidnexa_new_media',
    'New photos & videos',
    description: 'Reminders about photos and videos added today',
    importance: Importance.defaultImportance,
  );

  /// The Me-screen switch. On by default.
  static final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);

  /// Fires when the user taps the notification; the bottom bar listens and
  /// switches to the Gallery tab.
  static final ValueNotifier<int> openGalleryRequests = ValueNotifier<int>(0);

  /// A tap that launched the app arrives before the bottom bar exists (the
  /// splash screen is still up), so the request is also held until taken.
  static bool _galleryPending = false;

  static void requestOpenGallery() {
    _galleryPending = true;
    openGalleryRequests.value++;
  }

  /// True once per tap; the bottom bar calls this on start and on each
  /// [openGalleryRequests] change.
  static bool takeGalleryRequest() {
    final pending = _galleryPending;
    _galleryPending = false;
    return pending;
  }

  /// Called once per app start, after the first frame. Registers the daily
  /// jobs (keeping existing ones, so their timing is not reset every launch).
  static Future<void> init() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_prefEnabled) ?? true;

      await Workmanager().initialize(newMediaDigestDispatcher);
      // The single 8 pm job an earlier build registered.
      await Workmanager().cancelByUniqueName(_uniqueName);
      if (enabled.value) {
        await _register(replace: false);
      } else {
        await _cancelAll();
      }
    } catch (e) {
      debugPrint('NewMediaDigest.init failed: $e');
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefEnabled, value);
      if (value) {
        await _register(replace: true);
      } else {
        await _cancelAll();
      }
    } catch (e) {
      debugPrint('NewMediaDigest.setEnabled failed: $e');
    }
  }

  static Future<void> _cancelAll() async {
    for (final hour in _slotHours) {
      await Workmanager().cancelByUniqueName(_slotName(hour));
    }
  }

  /// Debug builds only: runs the real background job once, now, instead of
  /// waiting for the next slot — WorkManager refuses to run a periodic job
  /// early, even when forced through `adb`. Forgets the last notification
  /// shown so it can appear again. A no-op in release builds.
  static Future<void> debugRunNow() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefLastShown);
    await Workmanager().registerOneOffTask(
      '${_uniqueName}_debug',
      _uniqueName,
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// One daily job per slot, each first firing at that hour's next
  /// occurrence.
  static Future<void> _register({required bool replace}) async {
    final now = DateTime.now();
    for (final hour in _slotHours) {
      var next = DateTime(now.year, now.month, now.day, hour);
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));

      await Workmanager().registerPeriodicTask(
        _slotName(hour),
        _uniqueName,
        frequency: const Duration(days: 1),
        initialDelay: next.difference(now),
        existingWorkPolicy: replace
            ? ExistingPeriodicWorkPolicy.update
            : ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.notRequired),
      );
    }
  }

  /// The job itself. Runs in WorkManager's background isolate.
  @visibleForTesting
  static Future<void> runCheck() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_prefEnabled) ?? true)) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = today.toIso8601String().substring(0, 10);

    // Never prompts — a background job must not ask for anything.
    //
    // Not `PhotoManager.getPermissionState`: that reads the state through the
    // current Activity, and a WorkManager isolate has none — it threw a
    // NullPointerException in PermissionsUtils.getAuthValue on-device.
    // permission_handler checks against the application context instead.
    // With access confirmed, photo_manager's own Activity-based check is
    // switched off for this background engine's instance only.
    if (!await _hasMediaAccess()) return;
    await PhotoManager.setIgnorePermissionCheck(true);

    final photos = await _countSince(RequestType.image, today, now);
    final videos = await _countSince(RequestType.video, today, now);
    if (photos == 0 && videos == 0) return;

    // Nothing added since the previous slot's notification: stay quiet
    // rather than repeat the same totals.
    final countsKey = '$todayKey:$photos:$videos';
    if (prefs.getString(_prefLastShown) == countsKey) return;

    final lang = prefs.getString('app_locale') ??
        PlatformDispatcher.instance.locale.languageCode;
    String t(String key) => HomeStrings.t(lang, key);

    final counts = [
      if (photos > 0)
        t('new_media_photos').replaceAll('{count}', '$photos'),
      if (videos > 0)
        t('new_media_videos').replaceAll('{count}', '$videos'),
    ].join(' · ');

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_channel);
    // Respect a user who turned notifications off for the app.
    if (await android?.areNotificationsEnabled() == false) return;

    await plugin.show(
      id: 7001,
      title: t('new_media_title'),
      body: '$counts — ${t('new_media_tap')}',
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
        ),
      ),
    );
    await prefs.setString(_prefLastShown, countsKey);
  }

  /// Photo or video read access, full or "selected photos" — whatever the user
  /// granted. Android 13+ splits it into photos/videos; older versions use
  /// storage.
  static Future<bool> _hasMediaAccess() async {
    for (final permission in [
      Permission.photos,
      Permission.videos,
      Permission.storage,
    ]) {
      final status = await permission.status;
      if (status.isGranted || status.isLimited) return true;
    }
    return false;
  }

  static Future<int> _countSince(
    RequestType type,
    DateTime from,
    DateTime to,
  ) async {
    final filter = FilterOptionGroup(
      createTimeCond: DateTimeCond(min: from, max: to),
    );
    return PhotoManager.getAssetCount(type: type, filterOption: filter);
  }
}
