import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter/services.dart' show MethodCall, MethodChannel;
import 'package:photo_manager/photo_manager.dart';

import '../../domain/entities/gallery_permission.dart';
import '../../domain/entities/photo_album.dart';
import '../../domain/entities/photo_entity.dart';

/// Every read the gallery module makes against `photo_manager` goes through
/// here.
///
/// `photo_manager`'s platform channels only work on the root isolate — the
/// same constraint `features/voice_search`'s `PhotoManagerScanner` documents —
/// so this always runs on the main isolate. It stays cheap by never decoding a
/// full-size image: paging returns metadata only, and tiles ask for
/// thumbnails that are served from a bounded LRU.
///
/// Writes live in [MediaWriteDatasource] instead, so there is exactly one
/// place in the module that can delete a user's photo.
class GalleryAssetDatasource {
  /// Resolved album paths, keyed by album id, refreshed whenever the library
  /// changes underneath us.
  final Map<String, AssetPathEntity> _paths = {};

  /// The synthetic "all photos" container, cached separately because the
  /// Photos tab pages through it on every scroll.
  AssetPathEntity? _allPath;

  /// id -> asset, populated as pages are read. Thumbnail and file lookups key
  /// off this rather than round-tripping to MediaStore once per tile.
  final Map<String, AssetEntity> _assets = {};

  final _ThumbnailCache _thumbnails = _ThumbnailCache();

  final Set<void Function()> _listeners = {};
  ValueChanged<MethodCall>? _changeCallback;

  /// Newest first, with nothing excluded that this module has just written.
  ///
  /// Ordering is not the default: `photo_manager` returns whatever order the
  /// platform hands back, which on this device came out oldest-first — the
  /// gallery opened on photos from years ago. Ordering has to be requested
  /// explicitly, and it has to be requested on *every* `getAssetPathList`
  /// call, because it is a property of the query rather than of the album.
  ///
  /// A **getter, not a `static final`**. `FilterOptionGroup`'s default
  /// `createTimeCond` is `DateTimeCond.def()`, whose `max` is `DateTime.now()`
  /// evaluated at construction and turned on Android into
  /// `AND date_added <= <that instant>`. Held in a static, that instant was
  /// the gallery's first query of the run, so every photo written afterwards —
  /// every collage, filter, enhance and caption this app saves — landed above
  /// the ceiling and was filtered out of every later query. The save had
  /// really happened and the grid really did reload; the reload just asked
  /// MediaStore for "photos older than app start". Relaunching rebuilt the
  /// ceiling, which is the only reason the images turned up on the next
  /// launch. Ignored outright here: this module never wants an upper bound.
  ///
  /// [SizeConstraint.ignoreSize] drops the companion clause
  /// `AND width > 0 AND height > 0`. `gal` inserts the MediaStore row first and
  /// streams the bytes into it after, so width and height stay unset until
  /// MediaProvider scans the finished file — during the moment right after a
  /// save, which is exactly when the grid reloads, the new row would fail that
  /// test and be skipped. Nothing else here depends on the clause: the junk
  /// cleaner's "tiny" rule already guards on `longEdge > 0`.
  FilterOptionGroup get _newestFirst => FilterOptionGroup(
        imageOption: const FilterOption(
          sizeConstraint: SizeConstraint(ignoreSize: true),
        ),
        createTimeCond: DateTimeCond.def().copyWith(ignore: true),
        orders: const [
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      );

  /// The app's own MediaStore bridge — see [allFileSizes]. Must stay in step
  /// with `MediaSizePlugin.CHANNEL` on the Android side.
  static const MethodChannel _mediaSizeChannel =
      MethodChannel('com.vidnexa.videoplayer/media_size');

  Future<GalleryPermission> ensurePermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    return switch (state) {
      PermissionState.authorized => GalleryPermission.granted,
      PermissionState.limited => GalleryPermission.limited,
      _ => GalleryPermission.denied,
    };
  }

  Future<List<PhotoAlbum>> loadAlbums() async {
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: _newestFirst,
    );
    _paths
      ..clear()
      ..addEntries(paths.map((path) => MapEntry(path.id, path)));

    final albums = <PhotoAlbum>[];
    for (final path in paths) {
      if (path.isAll) continue;
      albums.add(
        PhotoAlbum(
          id: path.id,
          name: path.name,
          assetCount: await path.assetCountAsync,
          isAll: false,
        ),
      );
    }
    albums.sort((a, b) => b.assetCount.compareTo(a.assetCount));
    return albums;
  }

  Future<int> photoCount({String? albumId}) async {
    final path = await _resolvePath(albumId);
    if (path == null) return 0;
    return path.assetCountAsync;
  }

  Future<List<PhotoEntity>> loadPhotos({
    String? albumId,
    required int offset,
    required int limit,
  }) async {
    final path = await _resolvePath(albumId);
    if (path == null) return const [];

    final assets = await path.getAssetListRange(
      start: offset,
      end: offset + limit,
    );

    final photos = <PhotoEntity>[];
    for (final asset in assets) {
      _assets[asset.id] = asset;
      photos.add(_toEntity(asset));
    }
    return photos;
  }

  Future<Uint8List?> thumbnail(String photoId, int pixelSize) async {
    final key = '$photoId@$pixelSize';
    final cached = _thumbnails.get(key);
    if (cached != null) return cached;

    final asset = await _resolveAsset(photoId);
    if (asset == null) return null;

    final bytes = await asset.thumbnailDataWithSize(
      ThumbnailSize.square(pixelSize),
      quality: 82,
    );
    if (bytes != null) _thumbnails.put(key, bytes);
    return bytes;
  }

  Future<File?> originalFile(String photoId) async {
    final asset = await _resolveAsset(photoId);
    return asset?.file;
  }

  /// Resolves one photo's metadata by id, for tools that start from the
  /// signature table (which stores ids, not photos) rather than from a page.
  Future<PhotoEntity?> photoById(String photoId) async {
    final asset = await _resolveAsset(photoId);
    return asset == null ? null : _toEntity(asset);
  }

  /// Byte size of every image on the device, keyed by photo id.
  ///
  /// One MediaStore query for the whole library, through the app's own
  /// [`MediaSizePlugin`] channel. This exists because `photo_manager` 3.8.3
  /// exposes no size API, and the only way to get one through the plugin was
  /// [originalFile] — which on Android 10+ scoped storage **copies the photo
  /// into the app's cache directory** before it can be stat'ed. The signature
  /// pass needed a size per photo, so a 5000-photo library copied the entire
  /// library to cache to read numbers MediaStore already had in a column:
  /// minutes of I/O, and gigabytes of cache.
  ///
  /// Callers should fetch this once and look sizes up from the map, not ask
  /// per photo. Empty on platforms without the channel (iOS/macOS) and on any
  /// failure — a missing size degrades a size filter, it must never abort a
  /// scan.
  Future<Map<String, int>> allFileSizes() async {
    if (!Platform.isAndroid) return const {};
    try {
      final sizes = await _mediaSizeChannel
          .invokeMapMethod<String, Object?>('imageSizes');
      if (sizes == null) return const {};
      return <String, int>{
        for (final entry in sizes.entries)
          if (entry.value is int) entry.key: entry.value as int,
      };
    } catch (_) {
      return const {};
    }
  }

  /// Absolute path, for work that reads bytes on a worker isolate.
  ///
  /// Resolving the path needs `photo_manager` and therefore the root isolate;
  /// reading and hashing the file afterwards does not, since `dart:io` works
  /// anywhere. That split is what lets the duplicate finder hash off the main
  /// isolate.
  Future<String?> filePathOf(String photoId) async {
    final file = await originalFile(photoId);
    return file?.path;
  }

  /// Larger thumbnail for the signature pass, deliberately **not** cached.
  ///
  /// Two reasons. It is a size no tile ever requests, so caching it would only
  /// take space; and a background scan over thousands of photos would
  /// otherwise evict every thumbnail the user is currently looking at, turning
  /// a scan into visible grid flicker.
  ///
  /// 256px is a compromise: big enough for the Laplacian to see real detail,
  /// small enough that decoding a whole library stays affordable. See
  /// `PhotoSignature.blurScore` for what that costs in accuracy.
  Future<Uint8List?> signatureBytes(String photoId) async {
    final asset = await _resolveAsset(photoId);
    if (asset == null) return null;
    return asset.thumbnailDataWithSize(
      const ThumbnailSize.square(256),
      quality: 90,
    );
  }

  /// Forgets everything cached about [ids] and invalidates the album paths,
  /// whose asset counts `photo_manager` caches per instance. Called by the
  /// repository after a delete actually goes through.
  void invalidate(Iterable<String> ids) {
    for (final id in ids) {
      _assets.remove(id);
      _thumbnails.evictPrefix('$id@');
    }
    _paths.clear();
    _allPath = null;
  }

  /// Calls [onChanged] whenever the device's photo library changes.
  ///
  /// Covers both this app's own writes and everything outside it — a photo
  /// taken in the camera, an image received in WhatsApp, a file deleted from
  /// another gallery. Invalidating our caches on a save is not enough on its
  /// own: the controller still holds the list it loaded earlier, and only a
  /// signal like this tells it to go and read again.
  /// Several listeners at once, because more than one surface is alive at a
  /// time: the Photos tab's controller and an open album's controller both
  /// want to know. A single-listener design meant whichever screen closed
  /// first tore the watch down for the other.
  void addLibraryListener(void Function() onChanged) {
    final first = _listeners.isEmpty;
    if (!_listeners.add(onChanged)) return;
    if (!first) return;

    _changeCallback = (_) {
      // The event says something changed, not what. Drop the cached handles so
      // whatever reloads next reads the real library.
      invalidateAlbums();
      for (final listener in _listeners.toList()) {
        listener();
      }
    };
    PhotoManager.addChangeCallback(_changeCallback!);
    PhotoManager.startChangeNotify();
  }

  /// Tells every listener the library changed, without waiting for the
  /// platform to notice.
  ///
  /// [addLibraryListener]'s callback only fires for changes MediaStore reports
  /// through its own observer, and that is not dependable for this app's own
  /// writes: `Gal` saves through a different path, the observer can be
  /// throttled or coalesced, and on some devices it simply does not fire for
  /// the writing app. A save that showed "Saved" and left the grid unchanged
  /// looked exactly like a save that had failed — so writes announce
  /// themselves here instead of hoping.
  void notifyLibraryChanged() {
    invalidateAlbums();
    for (final listener in _listeners.toList()) {
      listener();
    }
  }

  void removeLibraryListener(void Function() onChanged) {
    if (!_listeners.remove(onChanged)) return;
    if (_listeners.isNotEmpty) return;

    final callback = _changeCallback;
    if (callback != null) PhotoManager.removeChangeCallback(callback);
    _changeCallback = null;
    PhotoManager.stopChangeNotify();
  }

  /// Forgets the cached album handles so the next read re-queries MediaStore.
  ///
  /// Needed after the module *writes* a photo, not just after it deletes one.
  /// `photo_manager` caches the asset count on an `AssetPathEntity`, so paging
  /// a handle resolved before the write keeps returning the old library and a
  /// freshly saved enhance, collage, caption or filter never appears — which
  /// looks exactly like the save having failed.
  ///
  /// Thumbnails are deliberately kept: none of them went stale, and dropping
  /// them would blank the grid for no reason.
  void invalidateAlbums() {
    _paths.clear();
    _allPath = null;
  }

  void releaseMemory() => _thumbnails.clear();

  Future<AssetPathEntity?> _resolvePath(String? albumId) async {
    if (albumId == null) {
      final cachedAll = _allPath;
      if (cachedAll != null) return cachedAll;
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        onlyAll: true,
        filterOption: _newestFirst,
      );
      if (paths.isEmpty) return null;
      return _allPath = paths.first;
    }

    final cached = _paths[albumId];
    if (cached != null) return cached;

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      filterOption: _newestFirst,
    );
    _paths
      ..clear()
      ..addEntries(paths.map((path) => MapEntry(path.id, path)));
    return _paths[albumId];
  }

  Future<AssetEntity?> _resolveAsset(String id) async {
    final cached = _assets[id];
    if (cached != null) return cached;
    final asset = await AssetEntity.fromId(id);
    if (asset != null) _assets[id] = asset;
    return asset;
  }

  PhotoEntity _toEntity(AssetEntity asset) => PhotoEntity(
        id: asset.id,
        fileName: asset.title ?? '',
        relativePath: asset.relativePath,
        width: asset.width,
        height: asset.height,
        createdAt: asset.createDateTime,
        modifiedAt: asset.modifiedDateTime,
        mimeType: asset.mimeType,
      );
}

/// Bounded LRU over thumbnail bytes, capped on both entry count and total
/// bytes — a 2-column grid's 512px thumbnails are several times the size of a
/// 5-column grid's, so a count-only cap would let the dense case hold far more
/// memory than the sparse one.
///
/// This replaces the pattern in `Utils/video_thumb.dart`, which clears the
/// entire map on overflow: scrolling past the limit there throws away every
/// thumbnail including the ones still on screen, so scrolling back up decodes
/// them all again.
class _ThumbnailCache {
  static const int maxBytes = 24 * 1024 * 1024;
  static const int maxEntries = 400;

  /// Insertion-ordered, so the first key is always the least recently used.
  /// Reads remove and re-insert to move an entry to the back.
  final LinkedHashMap<String, Uint8List> _entries = LinkedHashMap();

  int _bytes = 0;

  Uint8List? get(String key) {
    final value = _entries.remove(key);
    if (value == null) return null;
    _entries[key] = value;
    return value;
  }

  void put(String key, Uint8List value) {
    final existing = _entries.remove(key);
    if (existing != null) _bytes -= existing.lengthInBytes;

    _entries[key] = value;
    _bytes += value.lengthInBytes;

    while (_entries.isNotEmpty &&
        (_bytes > maxBytes || _entries.length > maxEntries)) {
      final oldest = _entries.keys.first;
      _bytes -= _entries.remove(oldest)!.lengthInBytes;
    }
  }

  /// Drops every size variant of one photo — used when an asset is deleted.
  void evictPrefix(String prefix) {
    final stale = _entries.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in stale) {
      _bytes -= _entries.remove(key)!.lengthInBytes;
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}
