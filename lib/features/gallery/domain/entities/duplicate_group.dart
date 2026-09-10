import 'photo_entity.dart';

/// A set of photos that are the same picture.
class DuplicateGroup {
  const DuplicateGroup({
    required this.photos,
    required this.keeperId,
    required this.exact,
    required this.sizes,
  });

  /// Members, best copy first. Never fewer than two.
  final List<PhotoEntity> photos;

  /// The copy the UI suggests keeping — highest resolution, then largest file.
  ///
  /// A *suggestion*. It arrives pre-selected as the keeper and every other
  /// member is left unticked; the user chooses what actually gets deleted.
  /// Pre-ticking deletions in a tool that removes photos permanently is how
  /// cleaner apps lose people their pictures.
  final String keeperId;

  /// Bytes verified identical, not merely similar-looking. Exact groups can be
  /// resolved confidently; similar ones need a human to look at them.
  final bool exact;

  final Map<String, int> sizes;

  int sizeOf(String photoId) => sizes[photoId] ?? 0;

  /// What deleting everything except the keeper would free.
  int get reclaimableBytes => photos
      .where((photo) => photo.id != keeperId)
      .fold(0, (total, photo) => total + sizeOf(photo.id));

  int get redundantCount => photos.length - 1;
}
