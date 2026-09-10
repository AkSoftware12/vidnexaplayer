import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../domain/entities/collage_template.dart';
import '../../domain/entities/duplicate_group.dart';
import '../../domain/entities/gallery_permission.dart';
import '../../domain/entities/gallery_query.dart';
import '../../domain/entities/junk_bucket.dart';
import '../../domain/entities/photo_album.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/entities/photo_filter.dart';
import '../../domain/entities/upscale_failure.dart';
import '../../domain/repositories/gallery_repository.dart';
import '../datasources/duplicate_worker.dart';
import '../datasources/gallery_asset_datasource.dart';
import '../datasources/image_pipeline_worker.dart';
import '../datasources/media_write_datasource.dart';
import '../datasources/photo_signature_database.dart';
import '../models/photo_signature.dart';

/// Coordinates the gallery's datasources. Holds no state of its own — the
/// caches live in [GalleryAssetDatasource] so that a delete can invalidate
/// them in the same step that performs it.
class GalleryRepositoryImpl implements GalleryRepository {
  GalleryRepositoryImpl({
    GalleryAssetDatasource? assets,
    MediaWriteDatasource? writer,
    PhotoSignatureDatabase? signatures,
  })  : _assets = assets ?? GalleryAssetDatasource(),
        _writer = writer ?? MediaWriteDatasource(),
        _signatures = signatures ?? PhotoSignatureDatabase.instance;

  /// Photos read from MediaStore per page while enumerating the library.
  /// Page size used when walking the whole library (`allPhotos`, and the
  /// searches built on it). Each page is a channel round-trip, so a bigger
  /// page is straight-line faster here — this is metadata only, no decode, so
  /// there is no memory reason to keep it small.
  static const _scanPageSize = 500;

  /// Blur scores below this are candidates for the blurry bucket.
  ///
  /// **Untuned.** The score is a Laplacian variance over a 256px thumbnail,
  /// and no threshold here is defensible until it has been measured against
  /// real photos on a real device. It is deliberately conservative: in a
  /// library of sharp photos the bucket should come back empty rather than
  /// inventing "junk" to justify the feature.
  static const _blurFloor = 60.0;

  /// A photo also has to sit in the worst quarter of the library to be
  /// flagged. Combined with [_blurFloor] this means a uniformly sharp library
  /// yields nothing, and a uniformly soft one does not flag everything.
  static const _blurPercentile = 0.25;

  static const _tinyBytes = 50 * 1024;
  static const _tinyEdge = 200;
  static const _screenshotAge = Duration(days: 60);

  /// Folder markers for images that arrived from somewhere else rather than
  /// being taken on this device.
  static const _receivedMarkers = [
    'whatsapp',
    'telegram',
    'download',
    'bluetooth',
    'messenger',
  ];

  /// Mean luminance boundaries for "dark" and "bright".
  static const _darkLuma = 70;
  static const _brightLuma = 185;

  /// How long a full library listing stays usable.
  ///
  /// Every tool starts by enumerating the whole library, and search re-filters
  /// on each debounced keystroke — without this, a single typed word pages
  /// through MediaStore from scratch. Short enough that a photo taken while
  /// the app is open shows up on the next search rather than being missed
  /// until restart.
  static const _allPhotosTtl = Duration(seconds: 60);

  /// Results land in their own albums so they are easy to find — and easy to
  /// delete if they were not wanted.
  static const _enhancedAlbum = 'VidNexa Enhanced';
  static const _collageAlbum = 'VidNexa Collage';
  static const _textAlbum = 'VidNexa Text';
  static const _filteredAlbum = 'VidNexa Filters';

  /// Long edge the filter preview works at. Small enough that a slider move
  /// re-renders faster than the next one arrives.
  static const _filterPreviewEdge = 720;

  final GalleryAssetDatasource _assets;
  final MediaWriteDatasource _writer;
  final PhotoSignatureDatabase _signatures;

  List<PhotoEntity>? _allPhotosCache;
  DateTime? _allPhotosCachedAt;

  /// Surfaces currently watching the library — the Photos tab's controller,
  /// and an open album's. Counted so [stopWatchingLibrary] knows when the
  /// repository's own listener can come off too.
  final Set<void Function()> _watchers = {};

  @override
  Future<GalleryPermission> ensurePermission() => _assets.ensurePermission();

  @override
  Future<List<PhotoAlbum>> loadAlbums() => _assets.loadAlbums();

  @override
  Future<int> photoCount({String? albumId}) =>
      _assets.photoCount(albumId: albumId);

  @override
  Future<List<PhotoEntity>> loadPhotos({
    String? albumId,
    required int offset,
    required int limit,
  }) =>
      _assets.loadPhotos(albumId: albumId, offset: offset, limit: limit);

  @override
  Future<List<PhotoEntity>> allPhotos() async {
    final cached = _allPhotosCache;
    final cachedAt = _allPhotosCachedAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _allPhotosTtl) {
      return cached;
    }

    final photos = <PhotoEntity>[];
    var offset = 0;
    while (true) {
      final page = await _assets.loadPhotos(
        offset: offset,
        limit: _scanPageSize,
      );
      if (page.isEmpty) break;
      photos.addAll(page);
      offset += page.length;
      if (page.length < _scanPageSize) break;
    }

    _allPhotosCache = photos;
    _allPhotosCachedAt = DateTime.now();
    return photos;
  }

  @override
  Future<List<PhotoEntity>> searchPhotos(GalleryQuery query) async {
    final photos = await allPhotos();
    if (query.isEmpty) return photos;

    // Colour, brightness and size live in the signature index; everything else
    // is answerable from MediaStore metadata alone. Only pay for the index
    // read when the query actually needs it.
    Map<String, PhotoSignature> signatures = const {};
    if (query.needsSignatures) {
      final rows = await _signatures.allSignatures();
      signatures = {for (final row in rows) row.sourceId: row};
    }

    final words = query.text
        ?.toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    final results = photos.where((photo) {
      if (query.orientation != null &&
          _orientationOf(photo) != query.orientation) {
        return false;
      }
      // Any of the named sources, not all — see GalleryQuery.sources.
      if (query.sources.isNotEmpty &&
          !_pathContains(
            photo,
            query.sources.map((source) => source.pathMarker).toList(),
          )) {
        return false;
      }
      if (query.folder != null &&
          !_pathContains(photo, [query.folder!.toLowerCase()])) {
        return false;
      }
      if (query.extension != null &&
          !photo.fileName.toLowerCase().endsWith('.${query.extension}')) {
        return false;
      }
      if (query.fromDate != null && photo.createdAt.isBefore(query.fromDate!)) {
        return false;
      }
      if (query.toDate != null && photo.createdAt.isAfter(query.toDate!)) {
        return false;
      }
      if (words != null && words.isNotEmpty) {
        final name = photo.fileName.toLowerCase();
        // Every word must appear, in any order — spoken and typed queries
        // rarely arrive in filename order.
        if (!words.every(name.contains)) return false;
      }

      if (!query.needsSignatures) return true;

      final signature = signatures[photo.id];
      // Unsigned photos cannot answer a colour, brightness or size question.
      // Excluding them is the honest result; including them would be guessing.
      if (signature == null) return false;

      if (query.color != null &&
          !query.color!.bins.contains(signature.dominantHueBin)) {
        return false;
      }
      if (query.tone == PhotoTone.dark && signature.meanLuma > _darkLuma) {
        return false;
      }
      if (query.tone == PhotoTone.bright && signature.meanLuma < _brightLuma) {
        return false;
      }
      final size = signature.fileSizeBytes;
      if (query.minSizeBytes != null &&
          (size == null || size < query.minSizeBytes!)) {
        return false;
      }
      if (query.maxSizeBytes != null &&
          (size == null || size > query.maxSizeBytes!)) {
        return false;
      }
      return true;
    }).toList();

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  PhotoOrientation _orientationOf(PhotoEntity photo) {
    if (photo.width == photo.height) return PhotoOrientation.square;
    return photo.width > photo.height
        ? PhotoOrientation.landscape
        : PhotoOrientation.portrait;
  }

  @override
  Future<Uint8List?> thumbnail(String photoId, int pixelSize) =>
      _assets.thumbnail(photoId, pixelSize);

  @override
  Future<File?> originalFile(String photoId) => _assets.originalFile(photoId);

  @override
  Future<List<String>> deletePhotos(List<String> photoIds) async {
    final deleted = await _writer.deletePhotos(photoIds);
    if (deleted.isNotEmpty) {
      _assets.invalidate(deleted);
      // The listing now names files that are gone. Drop it rather than let a
      // re-analysis rebuild groups around deleted photos.
      _allPhotosCache = null;
      _allPhotosCachedAt = null;
      // Their signatures describe files that no longer exist. Leaving them
      // would keep deleted photos appearing as duplicate group members.
      await _signatures.deleteByIds(deleted);
    }
    return deleted;
  }

  @override
  Future<void> sharePhotos(List<String> photoIds) async {
    final files = <File>[];
    for (final id in photoIds) {
      final file = await _assets.originalFile(id);
      if (file != null) files.add(file);
    }
    await _writer.shareFiles(files);
  }

  @override
  Future<List<DuplicateGroup>> findDuplicates() async {
    final signatures = await _signatures.allSignatures();
    if (signatures.length < 2) return const [];

    final byId = {for (final item in signatures) item.sourceId: item};

    final clusters = await compute(
      groupDuplicates,
      DuplicateScanRequest(signatures: signatures),
    );
    if (clusters.isEmpty) return const [];

    final confirmedExact = await _confirmExactClusters(clusters, byId);

    final groups = <DuplicateGroup>[];
    for (final cluster in clusters) {
      final photos = <PhotoEntity>[];
      for (final id in cluster.sourceIds) {
        final photo = await _assets.photoById(id);
        // A member that no longer resolves has left the device since the last
        // signature pass. Drop it rather than showing a broken tile.
        if (photo != null) photos.add(photo);
      }
      if (photos.length < 2) continue;

      final sizes = <String, int>{
        for (final photo in photos)
          photo.id: byId[photo.id]?.fileSizeBytes ?? 0,
      };

      photos.sort((a, b) => _keeperRank(b, sizes).compareTo(
            _keeperRank(a, sizes),
          ));

      groups.add(
        DuplicateGroup(
          photos: photos,
          keeperId: photos.first.id,
          exact: confirmedExact.contains(cluster.sourceIds.first),
          sizes: sizes,
        ),
      );
    }

    groups.sort(
      (a, b) => b.reclaimableBytes.compareTo(a.reclaimableBytes),
    );
    return groups;
  }

  @override
  Future<List<JunkBucket>> scanJunk() async {
    final photos = await allPhotos();
    if (photos.isEmpty) return const [];

    final signatures = await _signatures.allSignatures();
    final byId = {for (final item in signatures) item.sourceId: item};

    int sizeOf(PhotoEntity photo) => byId[photo.id]?.fileSizeBytes ?? 0;
    Map<String, int> sizesFor(List<PhotoEntity> list) => {
          for (final photo in list) photo.id: sizeOf(photo),
        };

    final duplicates = await findDuplicates();
    final redundant = <PhotoEntity>[
      for (final group in duplicates)
        ...group.photos.where((photo) => photo.id != group.keeperId),
    ];

    final blurry = _blurryPhotos(photos, byId);

    final cutoff = DateTime.now().subtract(_screenshotAge);
    final oldScreenshots = photos
        .where((photo) =>
            _pathContains(photo, const ['screenshot']) &&
            photo.createdAt.isBefore(cutoff))
        .toList();

    final received = photos
        .where((photo) => _pathContains(photo, _receivedMarkers))
        .toList();

    final tiny = photos.where((photo) {
      final bytes = sizeOf(photo);
      final longEdge = photo.width > photo.height ? photo.width : photo.height;
      return (bytes > 0 && bytes < _tinyBytes) ||
          (longEdge > 0 && longEdge < _tinyEdge);
    }).toList();

    final buckets = <JunkBucket>[
      JunkBucket(
        category: JunkCategory.duplicates,
        photos: redundant,
        sizes: sizesFor(redundant),
      ),
      JunkBucket(
        category: JunkCategory.blurry,
        photos: blurry,
        sizes: sizesFor(blurry),
      ),
      JunkBucket(
        category: JunkCategory.oldScreenshots,
        photos: oldScreenshots,
        sizes: sizesFor(oldScreenshots),
      ),
      JunkBucket(
        category: JunkCategory.received,
        photos: received,
        sizes: sizesFor(received),
      ),
      JunkBucket(
        category: JunkCategory.tiny,
        photos: tiny,
        sizes: sizesFor(tiny),
      ),
    ];

    return buckets.where((bucket) => !bucket.isEmpty).toList();
  }

  @override
  Future<UpscaleReport> enhancePhoto(
    String photoId, {
    int targetLongEdge = 3840,
  }) async {
    final path = await _assets.filePathOf(photoId);
    if (path == null) {
      return const UpscaleReport(
        saved: false,
        failure: UpscaleFailure.unreadable,
      );
    }

    final outcome = await compute(
      upscalePhoto,
      UpscaleRequest(sourcePath: path, targetLongEdge: targetLongEdge),
    );

    final bytes = outcome.bytes;
    if (bytes == null) {
      return UpscaleReport(
        saved: false,
        failure: outcome.failure,
        sourceWidth: outcome.sourceWidth,
        sourceHeight: outcome.sourceHeight,
      );
    }

    final saved = await _writer.saveImageBytes(bytes, album: _enhancedAlbum);
    if (saved) _onLibraryChanged();
    return UpscaleReport(
      saved: saved,
      failure: saved ? null : UpscaleFailure.notSaved,
      sourceWidth: outcome.sourceWidth,
      sourceHeight: outcome.sourceHeight,
      outputWidth: outcome.outputWidth,
      outputHeight: outcome.outputHeight,
    );
  }

  @override
  Future<CollageReport> buildCollage({
    required List<String> photoIds,
    required CollageTemplate template,
    int canvasLongEdge = 2048,
    Map<int, CollageAdjustment> adjustments = const {},
    bool save = true,
  }) async {
    if (photoIds.isEmpty) return const CollageReport(saved: false);

    // Paths resolve here, on the root isolate — the worker only reads them.
    final paths = <String>[];
    for (final id in photoIds) {
      final path = await _assets.filePathOf(id);
      if (path != null) paths.add(path);
    }
    if (paths.isEmpty) return const CollageReport(saved: false);

    final aspect = template.canvasAspect;
    final canvasWidth =
        aspect >= 1 ? canvasLongEdge : (canvasLongEdge * aspect).round();
    final canvasHeight =
        aspect >= 1 ? (canvasLongEdge / aspect).round() : canvasLongEdge;

    final cells = <double>[
      for (final cell in template.cells) ...[
        cell.left,
        cell.top,
        cell.width,
        cell.height,
      ],
    ];

    // Parallel lists, one entry per cell. A zoom of 0 marks "not adjusted",
    // which is what tells the worker to fall back to the automatic crop.
    final focusX = <double>[];
    final focusY = <double>[];
    final zoom = <double>[];
    for (var index = 0; index < paths.length; index++) {
      final adjustment = adjustments[index];
      focusX.add(adjustment?.focusX ?? 0);
      focusY.add(adjustment?.focusY ?? 0);
      zoom.add(adjustment == null ? 0 : adjustment.zoom);
    }

    final bytes = await compute(
      renderCollage,
      CollageRequest(
        sourcePaths: paths,
        cells: cells,
        canvasWidth: canvasWidth,
        canvasHeight: canvasHeight,
        focusX: focusX,
        focusY: focusY,
        zoom: zoom,
      ),
    );
    if (bytes == null) return const CollageReport(saved: false);
    if (!save) return CollageReport(saved: false, previewBytes: bytes);

    final saved = await _writer.saveImageBytes(bytes, album: _collageAlbum);
    if (saved) _onLibraryChanged();
    return CollageReport(saved: saved, previewBytes: bytes);
  }

  /// Assigns photos to a template's cells by shape.
  ///
  /// Greedy: take the cell furthest from square first and give it the photo
  /// whose aspect ratio is closest, comparing in log space so a 2:1 cell and a
  /// 1:2 photo are penalised symmetrically. Cheap, and it reliably keeps
  /// portraits out of landscape slots — which is the whole point of choosing a
  /// layout automatically.
  static List<PhotoEntity> assignToCells(
    List<PhotoEntity> photos,
    CollageTemplate template,
  ) {
    final cells = template.cells;
    final order = List.generate(cells.length, (index) => index)
      ..sort((a, b) {
        final aspectA = cells[a].aspectOn(template.canvasAspect);
        final aspectB = cells[b].aspectOn(template.canvasAspect);
        return (math.log(aspectB).abs()).compareTo(math.log(aspectA).abs());
      });

    final remaining = [...photos];
    final assigned = List<PhotoEntity?>.filled(cells.length, null);

    for (final cellIndex in order) {
      if (remaining.isEmpty) break;
      final target = math.log(cells[cellIndex].aspectOn(template.canvasAspect));
      var bestIndex = 0;
      var bestCost = double.infinity;
      for (var i = 0; i < remaining.length; i++) {
        final cost = (math.log(remaining[i].aspectRatio) - target).abs();
        if (cost < bestCost) {
          bestCost = cost;
          bestIndex = i;
        }
      }
      assigned[cellIndex] = remaining.removeAt(bestIndex);
    }

    return [
      for (var i = 0; i < assigned.length; i++)
        if (assigned[i] != null) assigned[i]!,
    ];
  }

  /// How well [template] suits [photos] — lower is better.
  ///
  /// Used to pick a layout automatically: the same shape-matching cost as
  /// [assignToCells], totalled.
  static double templateCost(
    List<PhotoEntity> photos,
    CollageTemplate template,
  ) {
    if (template.cellCount != photos.length) {
      // A layout that cannot hold every photo is not a candidate.
      return double.infinity;
    }
    final ordered = assignToCells(photos, template);
    var total = 0.0;
    for (var i = 0; i < ordered.length && i < template.cells.length; i++) {
      final cellAspect =
          template.cells[i].aspectOn(template.canvasAspect);
      total += (math.log(ordered[i].aspectRatio) - math.log(cellAspect)).abs();
    }
    return total;
  }

  @override
  Future<Uint8List?> previewFilter({
    required String photoId,
    required PhotoFilter filter,
    required FilterAdjustments adjustments,
  }) async {
    final path = await _assets.filePathOf(photoId);
    if (path == null) return null;
    return compute(
      applyPhotoFilter,
      FilterRequest(
        sourcePath: path,
        filter: filter,
        adjustments: adjustments,
        maxEdge: _filterPreviewEdge,
        quality: 88,
      ),
    );
  }

  @override
  Future<List<Uint8List?>> filterStrip(String photoId) async {
    final path = await _assets.filePathOf(photoId);
    if (path == null) {
      return List<Uint8List?>.filled(PhotoFilter.values.length, null);
    }
    return compute(
      renderFilterStrip,
      FilterStripRequest(
        sourcePath: path,
        filters: PhotoFilter.values,
      ),
    );
  }

  @override
  Future<bool> saveFilteredPhoto({
    required String photoId,
    required PhotoFilter filter,
    required FilterAdjustments adjustments,
  }) async {
    final path = await _assets.filePathOf(photoId);
    if (path == null) return false;

    // maxEdge 0 means "leave it at the source's own size" — the preview is
    // downscaled for speed, the saved file never is.
    final bytes = await compute(
      applyPhotoFilter,
      FilterRequest(
        sourcePath: path,
        filter: filter,
        adjustments: adjustments,
        maxEdge: 0,
        quality: 95,
      ),
    );
    if (bytes == null) return false;
    final saved = await _writer.saveImageBytes(bytes, album: _filteredAlbum);
    if (saved) _onLibraryChanged();
    return saved;
  }

  @override
  Future<bool> saveComposedImage(Uint8List bytes) async {
    final saved = await _writer.saveImageBytes(bytes, album: _textAlbum);
    if (saved) _onLibraryChanged();
    return saved;
  }

  /// Called after anything writes a new photo to the device.
  ///
  /// Drops the cached library listing and the cached album handles, so the
  /// grid, the tools and search all see the file that was just saved instead
  /// of a snapshot taken before it existed.
  void _onLibraryChanged() {
    _allPhotosCache = null;
    _allPhotosCachedAt = null;
    // Not `invalidateAlbums()`: dropping the caches only means the *next* read
    // is correct, and nothing was asking for one. The open grid holds the list
    // it loaded before the save, so it kept showing the library without the
    // photo that had just been written. This tells it to go and read again.
    _assets.notifyLibraryChanged();
  }

  @override
  void watchLibrary(void Function() onChanged) {
    // Registered as its own listener, and passed through unwrapped so that
    // removing it later matches by identity. A Set keeps the internal one
    // from being added twice.
    if (_watchers.add(onChanged)) _assets.addLibraryListener(onChanged);
    _assets.addLibraryListener(_dropListingCache);
  }

  @override
  void stopWatchingLibrary(void Function() onChanged) {
    if (!_watchers.remove(onChanged)) return;
    _assets.removeLibraryListener(onChanged);
    // The internal listener goes only once the last real watcher has, and it
    // has to go: while any listener remains the datasource keeps the platform
    // change observer running, so leaving it behind meant every visit to the
    // gallery registered another `PhotoManager` callback that nothing ever
    // took down.
    if (_watchers.isEmpty) _assets.removeLibraryListener(_dropListingCache);
  }

  void _dropListingCache() {
    _allPhotosCache = null;
    _allPhotosCachedAt = null;
  }

  @override
  void releaseMemory() => _assets.releaseMemory();

  /// Confirms which candidate clusters really are byte-identical.
  ///
  /// Returns the first source id of every cluster that survived verification,
  /// which is how [findDuplicates] tags a group as exact. Clusters the grouper
  /// only *suspected* were exact but whose bytes disagree stay in the results
  /// as similar — safer than dropping them, since they are still the same
  /// picture as far as the user is concerned.
  Future<Set<String>> _confirmExactClusters(
    List<RawDuplicateCluster> clusters,
    Map<String, PhotoSignature> byId,
  ) async {
    final candidates = clusters.where((cluster) => cluster.exact).toList();
    if (candidates.isEmpty) return const {};

    // Only hash what is not already hashed from a previous run.
    final paths = <String, String>{};
    for (final cluster in candidates) {
      for (final id in cluster.sourceIds) {
        if (byId[id]?.contentHash != null) continue;
        final path = await _assets.filePathOf(id);
        if (path != null) paths[id] = path;
      }
    }

    var hashes = <String, String>{
      for (final entry in byId.entries)
        if (entry.value.contentHash != null)
          entry.key: entry.value.contentHash!,
    };

    if (paths.isNotEmpty) {
      final fresh = await compute(
        verifyExactGroups,
        ExactVerifyRequest(pathsBySourceId: paths),
      );
      await _signatures.updateContentHashes(fresh);
      hashes = {...hashes, ...fresh};
    }

    final confirmed = <String>{};
    for (final cluster in candidates) {
      final first = hashes[cluster.sourceIds.first];
      // No hash means the file could not be read — treat as unconfirmed.
      if (first == null) continue;
      final allMatch = cluster.sourceIds
          .every((id) => hashes[id] != null && hashes[id] == first);
      if (allMatch) confirmed.add(cluster.sourceIds.first);
    }
    return confirmed;
  }

  /// Highest resolution wins; file size breaks ties. Packed into one number so
  /// it can drive a plain sort.
  int _keeperRank(PhotoEntity photo, Map<String, int> sizes) =>
      (photo.width * photo.height) * 1000 + (sizes[photo.id] ?? 0) ~/ 1024;

  /// Photos that are both below the absolute floor and in the softest quarter
  /// of everything signed. See [_blurFloor] for why it takes both.
  List<PhotoEntity> _blurryPhotos(
    List<PhotoEntity> photos,
    Map<String, PhotoSignature> byId,
  ) {
    final scored = photos
        .where((photo) => byId[photo.id] != null)
        .map((photo) => (photo: photo, score: byId[photo.id]!.blurScore))
        .toList();
    if (scored.isEmpty) return const [];

    final sorted = [...scored]..sort((a, b) => a.score.compareTo(b.score));
    final cutIndex = (sorted.length * _blurPercentile).floor();
    if (cutIndex <= 0) return const [];
    final percentileScore = sorted[cutIndex].score;

    return sorted
        .where((entry) =>
            entry.score < _blurFloor && entry.score <= percentileScore)
        .map((entry) => entry.photo)
        .toList();
  }

  bool _pathContains(PhotoEntity photo, List<String> markers) {
    final path = photo.relativePath?.toLowerCase();
    if (path == null || path.isEmpty) return false;
    return markers.any(path.contains);
  }
}
