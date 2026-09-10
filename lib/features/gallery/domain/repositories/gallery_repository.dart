import 'dart:io';
import 'dart:typed_data';

import '../entities/upscale_failure.dart';
import '../entities/collage_template.dart';
import '../entities/duplicate_group.dart';
import '../entities/gallery_permission.dart';
import '../entities/gallery_query.dart';
import '../entities/junk_bucket.dart';
import '../entities/photo_album.dart';
import '../entities/photo_entity.dart';
import '../entities/photo_filter.dart';

/// Storage-agnostic contract for browsing and mutating the device's photos.
///
/// Implemented by `GalleryRepositoryImpl` on top of `photo_manager`. Kept
/// abstract for the same reason `VideoSearchRepository` is: the controllers
/// can then be exercised against a fake without touching platform channels.
///
/// Later phases of the module extend this interface rather than adding a
/// second repository — smart-search facets (phase 4), duplicate groups and
/// junk buckets (phase 3) all read the same assets and the same index.
abstract class GalleryRepository {
  /// Asks once, at the module root. Every page reads the cached result from
  /// the controller instead of prompting again.
  Future<GalleryPermission> ensurePermission();

  /// Device albums, largest first. Excludes the synthetic "all" container,
  /// which backs the Photos tab instead.
  Future<List<PhotoAlbum>> loadAlbums();

  /// Total photos in [albumId], or in the whole library when it is null.
  Future<int> photoCount({String? albumId});

  /// One page of photos, newest first. [albumId] null reads the whole library.
  Future<List<PhotoEntity>> loadPhotos({
    String? albumId,
    required int offset,
    required int limit,
  });

  /// Every photo on the device, metadata only. Used by the tools, which start
  /// from the whole library rather than from a scroll position.
  Future<List<PhotoEntity>> allPhotos();

  /// Thumbnail bytes for [photoId] at [pixelSize], served from a bounded LRU.
  /// Returns null when the asset has no renderable thumbnail (deleted, or
  /// cloud-only and not downloaded).
  Future<Uint8List?> thumbnail(String photoId, int pixelSize);

  /// The backing file, for full-resolution viewing and sharing. Null when the
  /// asset exists in MediaStore but has no local file.
  Future<File?> originalFile(String photoId);

  /// Deletes [photoIds] in a single batch so Android 11+ raises one system
  /// consent dialog rather than one per photo.
  ///
  /// Returns the ids actually removed. An empty result is a normal outcome —
  /// it is what cancelling the consent dialog looks like — and callers must
  /// not report it as an error.
  Future<List<String>> deletePhotos(List<String> photoIds);

  /// Shares the given photos through the system sheet.
  Future<void> sharePhotos(List<String> photoIds);

  /// Photos matching every facet in [query], newest first.
  ///
  /// Facet search, not semantic search: it answers "red photos from WhatsApp
  /// last month" and cannot answer "photos of my dog". A query touching
  /// colour, brightness or file size reads the signature index, so photos that
  /// have not been signed yet cannot match those facets.
  Future<List<PhotoEntity>> searchPhotos(GalleryQuery query);

  /// Groups photos that are the same picture, reading the signature index.
  ///
  /// Returns groups of two or more, largest reclaimable space first. Every
  /// group nominates a keeper but selects nothing — what gets deleted is the
  /// user's call.
  Future<List<DuplicateGroup>> findDuplicates();

  /// Sorts photos into the junk cleaner's reviewable categories.
  ///
  /// A photo may legitimately appear in more than one bucket (a tiny blurry
  /// screenshot is all three). Callers must size a selection from the union of
  /// selected ids, never by summing bucket totals, or the same bytes get
  /// counted repeatedly.
  Future<List<JunkBucket>> scanJunk();

  /// Enlarges and sharpens [photoId] to [targetLongEdge], saving the result to
  /// its own album.
  ///
  /// High-quality resampling, not generative super-resolution — it does not
  /// invent detail the source never had. Runs on a worker isolate and refuses
  /// sources too large to process safely rather than risking the process being
  /// killed mid-way.
  Future<UpscaleReport> enhancePhoto(String photoId, {int targetLongEdge});

  /// Renders [photoIds] into [template] and, when [save] is set, writes the
  /// result to the gallery.
  ///
  /// Photos are assigned to cells by shape and cropped toward the busiest part
  /// of each frame, so the layout suits the pictures rather than the other way
  /// round.
  /// [adjustments] overrides the automatic crop for the cells the user has
  /// repositioned by hand, keyed by cell index. Cells left out keep the
  /// automatic crop.
  ///
  /// [save] exists because the page renders through this same call to paint its
  /// preview, once per layout tap and once per crop adjustment. While saving
  /// was unconditional, each of those wrote a preview-resolution file into the
  /// user's gallery — the collage album filled with thumbnails nobody asked
  /// for, and the export the user actually wanted was buried among them. Pass
  /// false for a preview; the bytes still come back in [CollageReport].
  Future<CollageReport> buildCollage({
    required List<String> photoIds,
    required CollageTemplate template,
    int canvasLongEdge,
    Map<int, CollageAdjustment> adjustments,
    bool save,
  });

  /// One look rendered onto [photoId] at preview size.
  ///
  /// Deliberately small and fast: this runs again on every slider move, and a
  /// full-resolution pass per frame would make the sliders unusable.
  Future<Uint8List?> previewFilter({
    required String photoId,
    required PhotoFilter filter,
    required FilterAdjustments adjustments,
  });

  /// Every look rendered onto one thumbnail, for the filter strip.
  Future<List<Uint8List?>> filterStrip(String photoId);

  /// Applies the look at the source's own resolution and saves it.
  Future<bool> saveFilteredPhoto({
    required String photoId,
    required PhotoFilter filter,
    required FilterAdjustments adjustments,
  });

  /// Saves an already-composed image — the text editor's boundary capture.
  ///
  /// Separate from [enhancePhoto] and [buildCollage] because the pixels were
  /// produced by Flutter's renderer rather than by a worker isolate; only the
  /// saving half is shared.
  Future<bool> saveComposedImage(Uint8List bytes);

  /// Calls [onChanged] whenever the device's photo library changes — this
  /// app's own saves included, and anything another app does too.
  void watchLibrary(void Function() onChanged);

  void stopWatchingLibrary(void Function() onChanged);

  /// Drops cached thumbnail bytes. Called on memory pressure.
  void releaseMemory();
}

/// What an enhance produced, or why it produced nothing.
class UpscaleReport {
  const UpscaleReport({
    required this.saved,
    this.failure,
    this.sourceWidth = 0,
    this.sourceHeight = 0,
    this.outputWidth = 0,
    this.outputHeight = 0,
  });

  final bool saved;

  /// Null when [saved] is true. Otherwise names what stopped it, so the UI can
  /// explain rather than show a generic error.
  final UpscaleFailure? failure;

  final int sourceWidth;
  final int sourceHeight;
  final int outputWidth;
  final int outputHeight;
}

/// What a collage render produced.
class CollageReport {
  const CollageReport({required this.saved, this.previewBytes});

  final bool saved;

  /// The rendered JPEG, kept so the screen can show what was saved.
  final Uint8List? previewBytes;
}
