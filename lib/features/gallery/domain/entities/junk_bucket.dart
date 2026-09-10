import 'photo_entity.dart';

/// The junk cleaner's categories.
///
/// Deliberately photo-scoped. It does not touch non-photo files and does not
/// assemble a headline "1.2 GB found" out of cache directories Android would
/// have reclaimed anyway — both are standard cleaner-app patterns and both are
/// why people uninstall cleaner apps.
enum JunkCategory {
  duplicates('duplicates'),
  blurry('blurry'),
  oldScreenshots('screenshots'),
  received('received'),
  tiny('tiny');

  const JunkCategory(this.slug);

  final String slug;

  String get titleKey => 'gallery_junk_${slug}_title';

  String get subtitleKey => 'gallery_junk_${slug}_sub';

  /// Whether the UI may arrive with this bucket's photos already ticked.
  ///
  /// False for everything. [blurry] is the clearest case why: the score is a
  /// heuristic on a downscaled thumbnail, and it will flag intentional bokeh,
  /// macro shots and motion blur that people love. Nothing here is certain
  /// enough to tick on a user's behalf.
  bool get safeToPreselect => false;
}

/// One reviewable category, with everything the UI needs to size it.
class JunkBucket {
  const JunkBucket({
    required this.category,
    required this.photos,
    required this.sizes,
  });

  final JunkCategory category;
  final List<PhotoEntity> photos;
  final Map<String, int> sizes;

  int sizeOf(String photoId) => sizes[photoId] ?? 0;

  int get totalBytes =>
      photos.fold(0, (total, photo) => total + sizeOf(photo.id));

  int get count => photos.length;

  bool get isEmpty => photos.isEmpty;
}
