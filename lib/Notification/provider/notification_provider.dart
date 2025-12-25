import 'package:flutter/cupertino.dart';
import '../model/notification_model.dart';

class NotificationStore {
  static final ValueNotifier<List<AppNotification>> notifications =
  ValueNotifier<List<AppNotification>>([]);

  static void addNotification(AppNotification notification) {
    notifications.value = [
      notification,
      ...notifications.value,
    ];
  }
}

