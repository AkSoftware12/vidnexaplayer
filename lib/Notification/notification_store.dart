import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_model.dart';

/// Stores delivered push notifications so the in-app list can show them.
///
/// Backed by `SharedPreferences` rather than a database for one specific
/// reason: Firebase's background handler runs in its **own isolate**, and this
/// has to be writable from there. `SharedPreferences` is; an in-memory list or
/// anything holding a Flutter binding is not.
///
/// That isolate split also means the main isolate's cached copy can be stale
/// after a background push, which is why every read calls [SharedPreferences
/// .reload] first.
class NotificationStore {
  NotificationStore._();

  static final NotificationStore instance = NotificationStore._();

  static const _key = 'app_notifications';

  /// Hard cap so a chatty backend cannot grow this without limit.
  static const _maxStored = 100;

  /// Bumped whenever the stored list changes, so the bell badge can rebuild
  /// without every screen having to poll.
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// Fires when the user taps a push; the home shell listens and opens the
  /// notification list.
  final ValueNotifier<int> openListRequests = ValueNotifier<int>(0);

  /// A tap that launched the app arrives before the home shell exists (the
  /// splash screen is still up), so the request is also held until taken.
  bool _openListPending = false;

  /// One tap is reported more than once — by `onMessageOpenedApp`, and by the
  /// `getInitialMessage` re-check on resume, where the Android plugin hands
  /// the same message out twice (from its own copy first, then again from the
  /// activity's intent, and only the second marks it consumed). That second
  /// copy can come after a newer tap, so every handled id is remembered, not
  /// just the last; otherwise an old push would reopen the list on a later
  /// resume. Taps per session are few, so the set stays tiny.
  final Set<String> _openedIds = <String>{};

  void requestOpenList([String? messageId]) {
    if (messageId != null && !_openedIds.add(messageId)) return;
    _openListPending = true;
    openListRequests.value++;
  }

  /// True once per tap; the home shell calls this on start and on each
  /// [openListRequests] change.
  bool takeOpenListRequest() {
    final pending = _openListPending;
    _openListPending = false;
    return pending;
  }

  /// Saves a delivered message. Safe to call from either isolate.
  ///
  /// Ignores duplicates by id: one push can arrive at the background handler
  /// *and* at `getInitialMessage` when the user opens the app by tapping it.
  Future<void> add(RemoteMessage message) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notification = message.notification;

      // A data-only push with nothing to display is not worth a list entry.
      final title = notification?.title ?? message.data['title'] ?? '';
      final body = notification?.body ?? message.data['body'] ?? '';
      if (title.trim().isEmpty && body.trim().isEmpty) return;

      final entry = AppNotification(
        id: message.messageId ?? '$now',
        title: title,
        body: body,
        imageUrl:
            notification?.android?.imageUrl ??
            notification?.apple?.imageUrl ??
            message.data['image'],
        receivedAt: now,
        data: message.data.map((key, value) => MapEntry(key, '$value')),
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getStringList(_key) ?? <String>[];

      final existing = _decodeAll(raw);
      if (existing.any((item) => item.id == entry.id)) {
        // Still publish: the usual duplicate is a background push the other
        // isolate stored, and this isolate's badge has not counted it yet.
        _publishUnread(existing);
        return;
      }

      final updated = [entry, ...existing];
      if (updated.length > _maxStored) {
        updated.removeRange(_maxStored, updated.length);
      }

      await prefs.setStringList(
        _key,
        updated.map((item) => item.encode()).toList(),
      );
      _publishUnread(updated);
    } catch (error) {
      debugPrint('NotificationStore.add failed: $error');
    }
  }

  /// Everything worth showing, newest first.
  ///
  /// Prunes on the way out: anything read more than
  /// [AppNotification.keepAfterRead] ago is dropped and the pruned list is
  /// written back, so expiry happens without a timer or a background job.
  Future<List<AppNotification>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final stored = _decodeAll(prefs.getStringList(_key) ?? <String>[]);

      final now = DateTime.now();
      final kept = stored.where((item) => !item.isExpired(now)).toList();

      if (kept.length != stored.length) {
        await prefs.setStringList(
          _key,
          kept.map((item) => item.encode()).toList(),
        );
      }

      kept.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
      _publishUnread(kept);
      return kept;
    } catch (error) {
      debugPrint('NotificationStore.load failed: $error');
      return const [];
    }
  }

  /// Stamps every unread entry as read *now*, starting its 24-hour clock.
  ///
  /// Called after the list has been rendered, not before: marking them read on
  /// the way in would clear the NEW badges in the same frame the user opened
  /// the screen to look at them.
  Future<void> markAllRead() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final stored = _decodeAll(prefs.getStringList(_key) ?? <String>[]);
      if (!stored.any((item) => item.isUnread)) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final updated =
          stored
              .map((item) => item.isUnread ? item.copyWith(readAt: now) : item)
              .toList();

      await prefs.setStringList(
        _key,
        updated.map((item) => item.encode()).toList(),
      );
      _publishUnread(updated);
    } catch (error) {
      debugPrint('NotificationStore.markAllRead failed: $error');
    }
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final kept =
        _decodeAll(
          prefs.getStringList(_key) ?? <String>[],
        ).where((item) => item.id != id).toList();
    await prefs.setStringList(_key, kept.map((item) => item.encode()).toList());
    _publishUnread(kept);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, const []);
    unreadCount.value = 0;
  }

  /// Refreshes [unreadCount] from storage, for the bell badge at startup.
  Future<void> refreshUnreadCount() async => load();

  List<AppNotification> _decodeAll(List<String> raw) {
    final out = <AppNotification>[];
    for (final row in raw) {
      final decoded = AppNotification.decode(row);
      if (decoded != null) out.add(decoded);
    }
    return out;
  }

  void _publishUnread(List<AppNotification> items) {
    unreadCount.value = items.where((item) => item.isUnread).length;
  }
}
