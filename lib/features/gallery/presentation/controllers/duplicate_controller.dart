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

  /// Photo id → the group it belongs to, so [canSelect] does not walk every
  /// group on each tap.
  Map<String, DuplicateGroup> _groupOf = const {};

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
    _groupOf = {
      for (final group in _groups)
        for (final photo in group.photos) photo.id: group,
    };
  }

  /// After a delete re-analyses, a photo stays selected only if it is still
  /// listed and is not now its group's keeper — the keeper can change when the
  /// old one was deleted, and it must never be pre-selected for deletion.
  @override
  bool isSelectable(String photoId) {
    final group = _groupOf[photoId];
    return group != null && group.keeperId != photoId;
  }

  @override
  Future<void> recordStats() =>
      GalleryToolStatsStore.instance.recordDuplicates(groups: _groups.length);

  /// False when selecting [photoId] would select every copy in its group.
  ///
  /// Deleting a whole group deletes the photo itself, not a duplicate of it.
  /// The keeper can still be picked — the user may prefer another copy — as
  /// long as at least one copy in the group stays unselected.
  bool canSelect(String photoId) {
    if (isSelected(photoId)) return true; // deselecting is always fine
    final group = _groupOf[photoId];
    if (group == null) return true;
    return group.photos
        .where((photo) => photo.id != photoId)
        .any((photo) => !isSelected(photo.id));
  }

  @override
  void toggle(String photoId) {
    if (!canSelect(photoId)) return;
    super.toggle(photoId);
  }

  /// Whether every non-keeper copy in the identical groups is already
  /// selected — the "Select identical" action then reads as its undo.
  bool get allRedundantSelected {
    var any = false;
    for (final group in _groups) {
      if (!group.exact) continue;
      for (final photo in group.photos) {
        if (photo.id == group.keeperId) continue;
        any = true;
        if (!isSelected(photo.id)) return false;
      }
    }
    return any;
  }

  /// Selects every copy except each group's keeper — or, when that is already
  /// the selection, clears it again.
  ///
  /// The one bulk action offered, and it is still a deliberate tap. Exact
  /// groups are the safe case — verified byte-identical — so this is where a
  /// user who trusts the scan can move quickly without the app having decided
  /// for them.
  ///
  /// Selecting also unselects those groups' keepers. It only ever added
  /// before, so a keeper the user had tapped earlier stayed selected and the
  /// whole group — every copy of the photo — went to the delete bar.
  void selectAllRedundant({bool exactOnly = false}) {
    final deselect = exactOnly && allRedundantSelected;
    final redundant = <String>[];
    final keepers = <String>[];
    for (final group in _groups) {
      if (exactOnly && !group.exact) continue;
      keepers.add(group.keeperId);
      redundant.addAll(
        group.photos
            .where((photo) => photo.id != group.keeperId)
            .map((photo) => photo.id),
      );
    }

    if (deselect) {
      deselectAllOf(redundant);
      return;
    }
    deselectAllOf(keepers);
    selectAllOf(redundant);
  }

  bool isKeeper(DuplicateGroup group, String photoId) =>
      group.keeperId == photoId;
}
