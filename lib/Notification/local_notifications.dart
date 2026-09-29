import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  static Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

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
