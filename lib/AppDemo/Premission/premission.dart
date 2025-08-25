import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static Future<Map<Permission, bool>> requestAppPermissionsSequential() async {
    Map<Permission, bool> results = {};

    final permissions = <Permission>[
      if (Platform.isAndroid)
        (int.parse(Platform.version.split(".").first) >= 13)
            ? Permission.videos
            : Permission.storage,
      Permission.photos,
      Permission.audio,
      Permission.notification,
    ];

    for (var permission in permissions) {
      // agar already granted hai → skip
      if (await permission.isGranted) {
        results[permission] = true;
        continue;
      }

      // ek-ek karke dialogs khulenge
      final status = await permission.request();
      results[permission] = status.isGranted;
    }

    return results;
  }
}
