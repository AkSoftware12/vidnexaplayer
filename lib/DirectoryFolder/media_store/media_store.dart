import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../file_browser/file_kind.dart';
import '../file_browser/file_ops.dart';

/// One file as MediaStore knows it.
@immutable
class MediaFile {
  const MediaFile({
    required this.id,
    required this.name,
    required this.size,
    required this.modified,
    required this.mime,
    required this.path,
    required this.uri,
  });

  final int id;
  final String name;
  final int size;
  final DateTime modified;
  final String mime;

  /// Folder this file sits in, relative to the storage root, always with a
  /// trailing slash — `DCIM/Camera/`. Empty for a file at the root.
  final String path;

  /// `content://media/external/file/1234`, which is what every consumer needs:
  /// the system viewer, share sheets and the in-app players all take a
  /// content uri, and MediaStore never exposes a real filesystem path.
  final String uri;

  FileKind get kind => FileKind.of(name);

  /// Last path segment — `Camera` for `DCIM/Camera/`.
  String get folderName {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    if (trimmed.isEmpty) return '';
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  static MediaFile fromMap(Map<Object?, Object?> map) => MediaFile(
        id: (map['id'] as num?)?.toInt() ?? 0,
        name: map['name'] as String? ?? '',
        size: (map['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch(
          (map['modified'] as num?)?.toInt() ?? 0,
        ),
        mime: map['mime'] as String? ?? '',
        path: map['path'] as String? ?? '',
        uri: map['uri'] as String? ?? '',
      );
}

/// A folder, summarised from the files inside it.
@immutable
class MediaFolder {
  const MediaFolder({
    required this.path,
    required this.count,
    required this.bytes,
    required this.modified,
  });

  final String path;
  final int count;
  final int bytes;
  final DateTime modified;

  String get name {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    if (trimmed.isEmpty) return '/';
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  static MediaFolder fromMap(Map<Object?, Object?> map) => MediaFolder(
        path: map['path'] as String? ?? '',
        count: (map['count'] as num?)?.toInt() ?? 0,
        bytes: (map['bytes'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch(
          (map['modified'] as num?)?.toInt() ?? 0,
        ),
      );
}

/// The buckets the file manager offers.
enum MediaKind {
  all('all'),
  video('video'),
  image('image'),
  audio('audio'),
  document('document'),
  archive('archive'),
  apk('apk'),
  download('download');

  const MediaKind(this.wire);

  /// The string the platform side switches on.
  final String wire;
}

/// Reads the device file index.
///
/// Replaces the Storage Access Framework browser that came before it. SAF
/// needed the user to pick a folder before anything could be listed, and every
/// directory cost a binder round trip, so a full picture of a tree took seconds
/// and had to be capped at a few thousand entries. MediaStore answers the same
/// questions over the whole device in one cursor, with no picker.
///
/// Results are cached per kind for [_ttl]. Re-entering a screen is then
/// instant, while a real change on disk still shows up shortly after — which is
/// the behaviour wanted from a list the user is walking in and out of.
class MediaStoreRepo {
  MediaStoreRepo._();
  static final MediaStoreRepo instance = MediaStoreRepo._();

  static const MethodChannel _channel =
      MethodChannel('com.vidnexa.videoplayer/media_store');

  static const Duration _ttl = Duration(seconds: 30);

  final Map<MediaKind, List<MediaFile>> _files = {};
  final Map<MediaKind, DateTime> _filesAt = {};

  List<MediaFolder>? _folders;
  DateTime? _foldersAt;

  bool _fresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < _ttl;

  /// Cached rows for [kind], or null when nothing usable is cached. Lets a
  /// screen paint real content on its very first frame instead of a spinner.
  List<MediaFile>? cached(MediaKind kind) =>
      _fresh(_filesAt[kind]) ? _files[kind] : null;

  List<MediaFolder>? get cachedFolders =>
      _fresh(_foldersAt) ? _folders : null;

  Future<List<MediaFile>> files(
    MediaKind kind, {
    int limit = 0,
    bool refresh = false,
  }) async {
    if (!refresh) {
      final hit = cached(kind);
      if (hit != null) return hit;
    }

    try {
      final raw = await _channel.invokeListMethod<Object?>('query', {
        'kind': kind.wire,
        'limit': limit,
      });

      final rows = (raw ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(MediaFile.fromMap)
          .where((f) => f.name.isNotEmpty)
          .toList(growable: false);

      _files[kind] = rows;
      _filesAt[kind] = DateTime.now();
      return rows;
    } on PlatformException catch (e) {
      debugPrint('MediaStoreRepo.files($kind) failed: $e');
      // Stale beats empty: a screen that briefly shows the previous list is
      // more useful than one that blanks because a single query failed.
      return _files[kind] ?? const [];
    }
  }

  Future<List<MediaFolder>> folders({bool refresh = false}) async {
    if (!refresh) {
      final hit = cachedFolders;
      if (hit != null) return hit;
    }

    try {
      final raw = await _channel.invokeListMethod<Object?>('folders');
      final rows = (raw ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map(MediaFolder.fromMap)
          .where((f) => f.path.isNotEmpty)
          .toList(growable: false);

      _folders = rows;
      _foldersAt = DateTime.now();
      return rows;
    } on PlatformException catch (e) {
      debugPrint('MediaStoreRepo.folders failed: $e');
      return _folders ?? const [];
    }
  }

  /// Files inside exactly [path] (not its sub-folders).
  ///
  /// Filtered from the single "all" query rather than asking the platform per
  /// folder: that query is already cached, so stepping into a folder costs
  /// nothing once the first screen has loaded.
  Future<List<MediaFile>> inFolder(String path) async {
    final all = await files(MediaKind.all);
    return all.where((f) => f.path == path).toList(growable: false);
  }

  /// Opens [file] in whichever installed app handles its type.
  ///
  /// Goes through the platform rather than a url_launcher-style plugin because
  /// a MediaStore `content://` uri needs the read grant attached to the intent;
  /// without it the receiving app gets a SecurityException instead of the file.
  Future<bool> openExternally(MediaFile file) async {
    try {
      return await _channel.invokeMethod<bool>('open', {
            'uri': file.uri,
            'mime': file.mime,
          }) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('MediaStoreRepo.openExternally failed: $e');
      return false;
    }
  }

  /// Drops every cache, so the next read hits MediaStore.
  void invalidate() {
    _files.clear();
    _filesAt.clear();
    _folders = null;
    _foldersAt = null;
  }
}

/// Sorts [files] in place.
///
/// Shares [FileSort] with the SAF browser so the sort menus stay consistent,
/// but works on [MediaFile]; the two have no common supertype and inventing one
/// would be more ceremony than the two sort functions it saves.
void sortMediaFiles(List<MediaFile> files, FileSort sort) {
  int byName(MediaFile a, MediaFile b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());

  files.sort((a, b) {
    switch (sort) {
      case FileSort.nameAsc:
        return byName(a, b);
      case FileSort.nameDesc:
        return byName(b, a);
      case FileSort.sizeDesc:
        return b.size.compareTo(a.size);
      case FileSort.sizeAsc:
        return a.size.compareTo(b.size);
      case FileSort.dateDesc:
        return b.modified.compareTo(a.modified);
      case FileSort.dateAsc:
        return a.modified.compareTo(b.modified);
      case FileSort.typeAsc:
        final c = a.kind.name.compareTo(b.kind.name);
        return c != 0 ? c : byName(a, b);
    }
  });
}
