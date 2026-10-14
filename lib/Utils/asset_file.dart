import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

extension AssetEntityFileOrNull on AssetEntity {
  /// [file], but null instead of throwing when the asset is gone.
  ///
  /// Lists of assets are snapshots. When the file behind one is deleted
  /// afterwards (by another app, a file manager, a cloud sync), `asset.file`
  /// does not return null — photo_manager throws
  /// `PlatformException(Failed to find asset …)`. Uncaught, that reaches
  /// Crashlytics as a fatal. Every caller already handles null as "file not
  /// available", so the error is folded into that.
  Future<File?> get fileOrNull async {
    try {
      return await file;
    } catch (e) {
      debugPrint('Failed to resolve file for asset $id: $e');
      return null;
    }
  }
}
