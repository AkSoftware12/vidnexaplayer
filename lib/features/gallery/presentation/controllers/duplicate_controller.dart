import '../../domain/entities/duplicate_group.dart';
import '../services/gallery_tool_stats.dart';
import 'review_controller.dart';

/// Drives the duplicate finder.
class DuplicateController extends ReviewController {
  DuplicateController({required super.repository});

  List<DuplicateGroup> _groups = const [];
  List<DuplicateGroup> get groups => _groups;

  /// Cached across groups so [sizeOf] stays a map lookup — it is called once
  /// per selected photo every time the action bar rebuilds.
  Map<String, int> _sizes = const {};

  int get groupCount => _groups.length;

  int get redundantCount =>
      _groups.fold(0, (total, group) => total + group.redundantCount);

  /// What deleting every non-keeper would free. A ceiling for the UI to quote,
  /// not a target — the user decides what actually goes.
  int get reclaimableBytes =>
      _groups.fold(0, (total, group) => total + group.reclaimableBytes);

  @override
  int sizeOf(String photoId) => _sizes[photoId] ?? 0;

  @override
  Future<void> analyse() async {
    _groups = await repository.findDuplicates();
    _sizes = {
      for (final group in _groups) ...group.sizes,
    };
  }

  @override
  Future<void> recordStats() =>
      GalleryToolStatsStore.instance.recordDuplicates(groups: _groups.length);

  /// Selects every copy except each group's keeper.
  ///
  /// The one bulk action offered, and it is still a deliberate tap. Exact
  /// groups are the safe case — verified byte-identical — so this is where a
  /// user who trusts the scan can move quickly without the app having decided
  /// for them.
  void selectAllRedundant({bool exactOnly = false}) {
    final ids = <String>[];
    for (final group in _groups) {
      if (exactOnly && !group.exact) continue;
      ids.addAll(
        group.photos
            .where((photo) => photo.id != group.keeperId)
            .map((photo) => photo.id),
      );
    }
    selectAllOf(ids);
  }

  bool isKeeper(DuplicateGroup group, String photoId) =>
      group.keeperId == photoId;
}
