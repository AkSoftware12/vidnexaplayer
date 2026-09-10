/// A single photo in the device gallery.
///
/// Plain fields only — no `photo_manager` types leak into the domain layer,
/// matching `VideoEntity` in `features/voice_search`. [id] is the
/// `AssetEntity.id`, which `GalleryAssetDatasource` resolves back into a real
/// asset when it needs thumbnail bytes or the underlying file, so a photo can
/// travel through the controller and the widget tree without anything holding
/// a live plugin object.
class PhotoEntity {
  final String id;
  final String fileName;
  final String? relativePath;
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final String? mimeType;

  const PhotoEntity({
    required this.id,
    required this.fileName,
    this.relativePath,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.modifiedAt,
    this.mimeType,
  });

  /// Day-precision bucket the date-sectioned grid groups on.
  DateTime get day => DateTime(createdAt.year, createdAt.month, createdAt.day);

  double get aspectRatio => height == 0 ? 1.0 : width / height;

  bool get isPortrait => height > width;

  bool get isLandscape => width > height;

  @override
  bool operator ==(Object other) => other is PhotoEntity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
