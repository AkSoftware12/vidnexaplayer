import '../../domain/entities/junk_bucket.dart';
import '../services/gallery_tool_stats.dart';
import 'review_controller.dart';

/// Drives the junk cleaner.
class JunkController extends ReviewController {
  JunkController({required super.repository});

  List<JunkBucket> _buckets = const [];
  List<JunkBucket> get buckets => _buckets;

  Map<String, int> _sizes = const {};

  /// Which categories are expanded. All collapsed on arrival: the point of the
  /// screen is to show what was found before showing hundreds of thumbnails.
  final Set<JunkCategory> _expanded = <JunkCategory>{};

  bool isExpanded(JunkCategory category) => _expanded.contains(category);

  void toggleExpanded(JunkCategory category) {
    if (!_expanded.remove(category)) _expanded.add(category);
    notifyListeners();
  }

  @override
  int sizeOf(String photoId) => _sizes[photoId] ?? 0;

  @override
  Future<void> analyse() async {
    _buckets = await repository.scanJunk();
    // Flattened across buckets — a photo in two buckets has one size, and this
    // is what keeps [selectedBytes] from counting it twice.
    _sizes = {
      for (final bucket in _buckets) ...bucket.sizes,
    };
    _expanded.removeWhere(
      (category) => !_buckets.any((bucket) => bucket.category == category),
    );
  }

  /// Total bytes across every bucket, de-duplicated by photo id.
  ///
  /// Adding bucket totals would over-report, because a tiny blurry screenshot
  /// is genuinely in three of them. This is the number the screen is allowed
  /// to show as "found".
  int get totalBytes {
    final seen = <String>{};
    var total = 0;
    for (final bucket in _buckets) {
      for (final photo in bucket.photos) {
        if (seen.add(photo.id)) total += bucket.sizeOf(photo.id);
      }
    }
    return total;
  }

  int get totalPhotos {
    final seen = <String>{};
    for (final bucket in _buckets) {
      seen.addAll(bucket.photos.map((photo) => photo.id));
    }
    return seen.length;
  }

  @override
  Future<void> recordStats() =>
      GalleryToolStatsStore.instance.recordJunk(bytes: totalBytes);

  bool isBucketFullySelected(JunkBucket bucket) =>
      bucket.photos.isNotEmpty &&
      bucket.photos.every((photo) => isSelected(photo.id));

  void toggleBucket(JunkBucket bucket) {
    final ids = bucket.photos.map((photo) => photo.id);
    if (isBucketFullySelected(bucket)) {
      deselectAllOf(ids);
    } else {
      selectAllOf(ids);
    }
  }
}
