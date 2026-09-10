import 'dart:io';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bounds-checked string/list slicing plus a crash-free replacement for
/// `FileManager.getStorageList()`.
///
/// Crash 5 was `FileManager.getStorageList.<fn> -> RangeError (end): Invalid
/// value`, new in 1.0.27. The `file_manager` package computes a storage root
/// like this:
///
/// ```dart
/// final splitedPath = e.path.split("/");
/// Directory(splitedPath
///     .sublist(0, splitedPath.indexWhere((s) => s == "Android"))
///     .join("/"));
/// ```
///
/// `indexWhere` returns **-1** when there is no "Android" segment, and
/// `sublist(0, -1)` throws. Any path that isn't the usual
/// `/storage/<id>/Android/data/<pkg>/files` shape hits it — OEM skins that
/// return `/mnt/...`, USB-OTG and SD-card mounts, and work-profile paths. It
/// also does `(await getExternalStorageDirectories())!`, which throws again
/// when the platform returns null (no external storage, or permission denied).
///
/// The package's version is reached from three places — `FileManager`'s
/// initState, `FileManagerController.isRootDirectory()` and
/// `goToParentDirectory()` — so callers must use [getStorageList] here and
/// seed the controller's path themselves; see DirectoryFolder.
class SafeStorage {
  SafeStorage._();

  /// [String.substring] with both ends clamped into range.
  ///
  /// Returns `''` rather than throwing for any input, including a negative
  /// [start], an [end] past the string, or a reversed pair.
  static String safeSubstring(String value, int start, [int? end]) {
    if (value.isEmpty) return '';
    final len = value.length;
    var from = start < 0 ? 0 : (start > len ? len : start);
    var to = end == null ? len : (end < 0 ? 0 : (end > len ? len : end));
    if (to < from) return '';
    return value.substring(from, to);
  }

  /// [List.sublist] with both ends clamped into range.
  ///
  /// This is the one that mattered: `end` of -1 (from a failed `indexWhere`)
  /// clamps to 0 and yields an empty list instead of a RangeError.
  static List<T> safeSublist<T>(List<T> value, int start, [int? end]) {
    if (value.isEmpty) return <T>[];
    final len = value.length;
    final from = start < 0 ? 0 : (start > len ? len : start);
    final to = end == null ? len : (end < 0 ? 0 : (end > len ? len : end));
    if (to < from) return <T>[];
    return value.sublist(from, to);
  }

  /// Storage roots the user can actually browse. Never throws; returns an
  /// empty list when there is nothing readable (including when the storage
  /// permission was denied), and the caller shows a permission state for that.
  static Future<List<Directory>> getStorageList() async {
    try {
      if (!Platform.isAndroid) {
        // Desktop/iOS: the documents directory's parent is the closest thing
        // to a browsable root, and there is no permission model to consult.
        final docs = await getApplicationDocumentsDirectory();
        return _keepListable([docs.parent]);
      }

      if (!await hasStoragePermission()) return <Directory>[];

      final candidates = <String>{};

      // App-private dirs are the only reliable way to enumerate *which*
      // volumes exist (internal + every SD card / OTG mount). Their public
      // root is the part of the path before the "Android" segment.
      List<Directory>? external;
      try {
        external = await getExternalStorageDirectories();
      } catch (e, s) {
        // Some OEM ROMs throw here outright rather than returning null.
        await _report(e, s, 'getExternalStorageDirectories failed');
        external = null;
      }

      for (final dir in external ?? const <Directory>[]) {
        final root = _publicRootOf(dir.path);
        if (root != null) candidates.add(root);
      }

      // Fallbacks for the case above where the platform gave us nothing at
      // all. `/storage/emulated/0` is the primary volume on every supported
      // Android version.
      if (candidates.isEmpty) {
        candidates.addAll(const [
          '/storage/emulated/0',
          '/sdcard',
        ]);
      }

      return _keepListable(candidates.map(Directory.new).toList());
    } catch (e, s) {
      // Nothing about browsing folders is worth a crash — an empty list makes
      // the screen show its "no storage" state instead.
      await _report(e, s, 'SafeStorage.getStorageList failed');
      return <Directory>[];
    }
  }

  /// True when [path] is one of the roots returned by [getStorageList].
  ///
  /// Replaces `FileManagerController.isRootDirectory()`, which routes through
  /// the package's crashing implementation.
  static Future<bool> isRoot(String path) async {
    if (path.isEmpty) return true;
    final roots = await getStorageList();
    final normalised = _stripTrailingSlash(path);
    return roots.any((r) => _stripTrailingSlash(r.path) == normalised);
  }

  /// Whether the app may list the shared storage volumes.
  ///
  /// Android 11+ needs MANAGE_EXTERNAL_STORAGE to walk arbitrary folders; the
  /// granular READ_MEDIA_* grants only cover MediaStore queries. Below that,
  /// READ_EXTERNAL_STORAGE is enough. Either way this only *reads* the status
  /// — the request is the screen's job, so a denied permission renders a
  /// prompt rather than silently showing an empty folder.
  static Future<bool> hasStoragePermission() async {
    try {
      if (!Platform.isAndroid) return true;
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await Permission.storage.isGranted) return true;
      return false;
    } catch (e, s) {
      await _report(e, s, 'SafeStorage.hasStoragePermission failed');
      // Fail open: let the directory listing itself decide. A wrong `false`
      // here would show a permission prompt to a user who already granted it.
      return true;
    }
  }

  /// Asks for the permission [hasStoragePermission] checks. Returns the
  /// resulting granted state.
  static Future<bool> requestStoragePermission() async {
    try {
      if (!Platform.isAndroid) return true;
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      return await Permission.storage.request().isGranted;
    } catch (e, s) {
      await _report(e, s, 'SafeStorage.requestStoragePermission failed');
      return false;
    }
  }

  /// `/storage/XXXX-XXXX/Android/data/<pkg>/files` -> `/storage/XXXX-XXXX`.
  ///
  /// This is the exact computation that threw in the package. Every slice is
  /// bounds-checked, and a path with no "Android" segment falls back to the
  /// first three segments (`/storage/emulated/0`) instead of blowing up.
  static String? _publicRootOf(String path) {
    if (path.isEmpty) return null;
    final segments = path.split('/');
    final androidAt = segments.indexWhere((s) => s == 'Android');

    // indexWhere -> -1 (no "Android" segment) is the crash. safeSublist
    // clamps it; the `> 0` test then routes those paths to the fallback.
    final head = androidAt > 0
        ? safeSublist(segments, 0, androidAt)
        : safeSublist(segments, 0, 4); // '', 'storage', 'emulated', '0'

    final root = head.join('/');
    if (root.isEmpty || root == '/') return null;
    return _stripTrailingSlash(root);
  }

  /// Drops roots that don't exist or can't be listed, so the UI never opens a
  /// directory that immediately throws on `list()`.
  static Future<List<Directory>> _keepListable(List<Directory> dirs) async {
    final out = <Directory>[];
    for (final dir in dirs) {
      try {
        if (!await dir.exists()) continue;
        // Pull a single entry: cheap, and it is the only thing that actually
        // proves the directory is readable with the permissions we hold.
        await dir.list(followLinks: false).take(1).toList();
        out.add(dir);
      } catch (_) {
        // Unreadable volume (unmounted SD card, scoped-storage denial).
      }
    }
    return out;
  }

  static String _stripTrailingSlash(String path) =>
      path.length > 1 && path.endsWith('/')
          ? safeSubstring(path, 0, path.length - 1)
          : path;

  static Future<void> _report(Object e, StackTrace s, String reason) async {
    debugPrint('⚠️ $reason: $e');
    try {
      await FirebaseCrashlytics.instance
          .recordError(e, s, reason: reason, fatal: false);
    } catch (_) {
      // Crashlytics unavailable — reporting must never be the failure.
    }
  }
}
