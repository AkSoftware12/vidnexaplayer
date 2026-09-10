import 'photo_entity.dart';

/// A run of photos that share one calendar day.
///
/// The grid renders one sticky header plus one sliver grid per section, so
/// sections are rebuilt in the controller whenever a page of photos is
/// appended rather than being recomputed during layout.
class PhotoSection {
  final DateTime day;
  final List<PhotoEntity> photos;

  const PhotoSection({required this.day, required this.photos});
}
