import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'new_media_digest.dart';
import 'notification_store.dart';

/// Shows a push as a real system notification while the app is in the
/// foreground.
///
/// Android deliberately suppresses the tray banner for a notification-type FCM
/// message when the target app is already in the foreground — only
/// `FirebaseMessaging.onMessage` fires, and nothing appears on screen. That is
/// why a push looked like it "did not arrive" while the app was open and only
/// showed up after it had been closed.
///
/// Posting a local notification from `onMessage` is the standard fix, and it is
/// only needed in that one case: background and terminated deliveries are
/// already drawn by the system.
class LocalNotifications {
  LocalNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Must match a channel the app actually creates, or Android silently drops
  /// the notification on O and above.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'vidnexa_push',
    'General',
    description: 'Updates and announcements',
    importance: Importance.high,
  );

  static bool _ready = false;

  /// The in-flight init, shared. main.dart starts init() from two places at
  /// once (FCM setup and the new-media digest); without this both could get
  /// past `_ready` and route the launching tap twice.
  static Future<void>? _initializing;

  static Future<void> init() {
    if (_ready) return Future.value();
    return _initializing ??= _init().whenComplete(() => _initializing = null);
  }

  static Future<void> _init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          // Monochrome status-bar icon. The launcher mipmap is opaque, and
          // Android draws only a small icon's alpha, so it showed as a blank
          // white square.
          android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
        ),
        // Tapped while the app is running (foreground or in the background).
        onDidReceiveNotificationResponse: _onTap,
      );

      // Tapped while the app was closed: the tap is what launched it.
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        final response = launch!.notificationResponse;
        if (response != null) _onTap(response);
      }

      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      _ready = true;
    } catch (error) {
      debugPrint('LocalNotifications.init failed: $error');
    }
  }

  /// Payload on a push drawn by [show], so its tap can be told apart from the
  /// new-media reminder's.
  static const _pushPayload = 'push';

  /// Routes a tapped local notification: the new-media reminder to Gallery, a
  /// foreground push to the notification list.
  static void _onTap(NotificationResponse response) {
    switch (response.payload) {
      case NewMediaDigest.payload:
        NewMediaDigest.requestOpenGallery();
      case _pushPayload:
        NotificationStore.instance.requestOpenList();
    }
  }

  /// Draws [message] in the tray. No-op for a message with nothing to show.
  static Future<void> show(RemoteMessage message) async {
    if (!_ready) await init();
    if (!_ready) return;

    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? '';
    final body = notification?.body ?? message.data['body'] ?? '';
    if (title.trim().isEmpty && body.trim().isEmpty) return;

    try {
      await _plugin.show(
        // A stable-ish id derived from the message, so the same push does not
        // stack twice if it is ever delivered again.
        id: message.messageId.hashCode,
        title: title,
        body: body,
        payload: _pushPayload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
          ),
        ),
      );
    } catch (error) {
      debugPrint('LocalNotifications.show failed: $error');
    }
  }}
