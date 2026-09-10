/// A device album (a MediaStore bucket), as shown on the Albums tab.
class PhotoAlbum {
  final String id;
  final String name;
  final int assetCount;

  /// True for the synthetic "all photos" container `photo_manager` returns
  /// when asked with `onlyAll: true`. It backs the Photos tab, so the Albums
  /// tab filters it out rather than showing it twice.
  final bool isAll;

  const PhotoAlbum({
    required this.id,
    required this.name,
    required this.assetCount,
    this.isAll = false,
  });
}
