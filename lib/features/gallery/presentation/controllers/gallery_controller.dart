import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/gallery_permission.dart';
import '../../domain/entities/grid_density.dart';
import '../../domain/entities/photo_album.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/entities/photo_section.dart';
import '../../domain/repositories/gallery_repository.dart';

/// Drives one browsing surface — either the whole library ([albumId] null) or
/// a single album.
///
/// A plain `ChangeNotifier`, matching the app's existing Provider pattern and
/// `VoiceSearchController`. Scoped to its route rather than registered in
/// `main.dart`: the album page pushes its own instance so it pages
/// independently of the Photos tab.
///
/// Selection lives here, not in a page's `setState`, because it is shared —
/// delete and share use it today, and collage and the junk cleaner will use
/// the same set in later phases.
class GalleryController extends ChangeNotifier with WidgetsBindingObserver {
  GalleryController({
    required GalleryRepository repository,
    this.albumId,
  }) : _repository = repository;

  static const _pageSize = 120;
  static const _densityPrefKey = 'gallery_grid_density';

  /// Null browses the whole library; set browses one album.
  final String? albumId;

  final GalleryRepository _repository;

  GalleryPermission _permission = GalleryPermission.denied;
  GalleryPermission get permission => _permission;

  bool _ready = false;
  bool get ready => _ready;

  bool _loadingPhotos = false;
  bool get loadingPhotos => _loadingPhotos;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  final List<PhotoEntity> _photos = [];
  List<PhotoEntity> get photos => List.unmodifiable(_photos);

  List<PhotoSection> _sections = const [];
  List<PhotoSection> get sections => _sections;

  List<PhotoAlbum> _albums = const [];
  List<PhotoAlbum> get albums => _albums;

  GridDensity _density = GridDensity.medium;
  GridDensity get density => _density;

  bool _selectionMode = false;
  bool get selectionMode => _selectionMode;

  /// A Dart set is insertion-ordered, so shares keep the order photos were
  /// tapped in.
  final Set<String> _selected = <String>{};
  Set<String> get selected => Set.unmodifiable(_selected);

  int get selectedCount => _selected.length;

  bool isSelected(String photoId) => _selected.contains(photoId);

  bool get isEmpty => _ready && _photos.isEmpty;

  /// Coalesces bursts of change events. Saving one photo can emit several
  /// MediaStore notifications, and reloading the library once per event would
  /// make the grid flicker for no benefit.
  static const _reloadDebounce = Duration(milliseconds: 400);

  Timer? _reloadTimer;

  /// The reload is debounced, so it can fire after the route is gone.
  bool _disposed = false;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await _restoreDensity();

    _permission = await _repository.ensurePermission();
    if (!_permission.canRead) {
      _ready = true;
      notifyListeners();
      return;
    }

    await _loadFirstPage();
    if (albumId == null) await _loadAlbums();

    // React to the library changing underneath us — this app saving an
    // enhance or a filter, the camera taking a shot, another app deleting a
    // file. Without this the grid keeps showing the list it loaded on open,
    // which is what made a successful save look like it had done nothing.
    _repository.watchLibrary(_onLibraryChanged);

    _ready = true;
    notifyListeners();
  }

  void _onLibraryChanged() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(_reloadDebounce, () {
      if (_disposed) return;
      refresh();
    });
  }

  /// Re-runs the permission request. Used by the denied state's retry button,
  /// which is the only place the module asks a second time.
  Future<void> retryPermission() async {
    _permission = await _repository.ensurePermission();
    notifyListeners();
    if (_permission.canRead) await refresh();
  }

  Future<void> refresh() async {
    _photos.clear();
    _sections = const [];
    _hasMore = true;
    _selected.clear();
    _selectionMode = false;
    notifyListeners();

    await _loadFirstPage();
    if (albumId == null) await _loadAlbums();
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (_loadingPhotos || !_hasMore || !_permission.canRead) return;
    _loadingPhotos = true;
    notifyListeners();

    final page = await _repository.loadPhotos(
      albumId: albumId,
      offset: _photos.length,
      limit: _pageSize,
    );

    _photos.addAll(page);
    _hasMore = page.length == _pageSize;
    _rebuildSections();
    _loadingPhotos = false;
    notifyListeners();
  }

  Future<Uint8List?> thumbnail(String photoId) =>
      _repository.thumbnail(photoId, _density.thumbnailPx);

  /// First photo of [albumId], used as an album's cover. Reads a one-item page
  /// rather than a dedicated query — the datasource caches the resolved album
  /// path, so this is one MediaStore range read per album.
  Future<String?> coverPhotoFor(String albumId) async {
    final page = await _repository.loadPhotos(
      albumId: albumId,
      offset: 0,
      limit: 1,
    );
    return page.isEmpty ? null : page.first.id;
  }

  Future<File?> originalFile(String photoId) =>
      _repository.originalFile(photoId);

  void setDensity(GridDensity density) {
    if (density == _density) return;
    _density = density;
    notifyListeners();
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_densityPrefKey, density.name));
  }

  void zoomIn() => setDensity(_density.zoomIn);

  void zoomOut() => setDensity(_density.zoomOut);

  void toggleSelection(String photoId) {
    if (_selected.contains(photoId)) {
      _selected.remove(photoId);
      if (_selected.isEmpty) _selectionMode = false;
    } else {
      _selected.add(photoId);
      _selectionMode = true;
    }
    notifyListeners();
  }

  void startSelection(String photoId) {
    _selectionMode = true;
    _selected.add(photoId);
    notifyListeners();
  }

  void selectAll() {
    _selected
      ..clear()
      ..addAll(_photos.map((photo) => photo.id));
    _selectionMode = _selected.isNotEmpty;
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    _selectionMode = false;
    notifyListeners();
  }

  /// Deletes the current selection in one batch.
  ///
  /// Returns how many photos were actually removed. Zero means the user
  /// declined the system consent dialog — the caller shows nothing rather than
  /// an error, and the selection is left intact so they can try again.
  Future<int> deleteSelected() async {
    if (_selected.isEmpty) return 0;

    final deleted = await _repository.deletePhotos(_selected.toList());
    if (deleted.isEmpty) return 0;

    final removed = deleted.toSet();
    _photos.removeWhere((photo) => removed.contains(photo.id));
    _selected.removeAll(removed);
    _selectionMode = _selected.isNotEmpty;
    _rebuildSections();

    if (albumId == null) await _loadAlbums();
    notifyListeners();
    return deleted.length;
  }

  /// Deletes a single photo from the viewer, bypassing selection mode.
  Future<int> deletePhoto(String photoId) async {
    final deleted = await _repository.deletePhotos([photoId]);
    if (deleted.isEmpty) return 0;

    final removed = deleted.toSet();
    _photos.removeWhere((photo) => removed.contains(photo.id));
    _selected.removeAll(removed);
    _rebuildSections();

    if (albumId == null) await _loadAlbums();
    notifyListeners();
    return deleted.length;
  }

  Future<void> shareSelected() => sharePhotoIds(_selected.toList());

  Future<void> sharePhotoIds(List<String> photoIds) async {
    if (photoIds.isEmpty) return;
    await _repository.sharePhotos(photoIds);
  }

  @override
  void didHaveMemoryPressure() {
    _repository.releaseMemory();
    super.didHaveMemoryPressure();
  }

  @override
  void dispose() {
    _disposed = true;
    _reloadTimer?.cancel();
    _repository.stopWatchingLibrary(_onLibraryChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    _photos.clear();
    final page = await _repository.loadPhotos(
      albumId: albumId,
      offset: 0,
      limit: _pageSize,
    );
    _photos.addAll(page);
    _hasMore = page.length == _pageSize;
    _rebuildSections();
  }

  Future<void> _loadAlbums() async {
    _albums = await _repository.loadAlbums();
  }

  Future<void> _restoreDensity() async {
    final prefs = await SharedPreferences.getInstance();
    _density = GridDensity.fromName(prefs.getString(_densityPrefKey));
  }

  /// Groups the loaded photos into calendar-day sections.
  ///
  /// Runs whenever a page is appended rather than during layout — the grid
  /// builds one sticky header and one sliver per section, and recomputing that
  /// on every frame while scrolling would be wasted work.
  void _rebuildSections() {
    final sections = <PhotoSection>[];
    DateTime? currentDay;
    var bucket = <PhotoEntity>[];

    for (final photo in _photos) {
      final day = photo.day;
      if (currentDay == null) {
        currentDay = day;
      } else if (day != currentDay) {
        sections.add(PhotoSection(day: currentDay, photos: bucket));
        currentDay = day;
        bucket = <PhotoEntity>[];
      }
      bucket.add(photo);
    }

    if (currentDay != null && bucket.isNotEmpty) {
      sections.add(PhotoSection(day: currentDay, photos: bucket));
    }
    _sections = sections;
  }
}
