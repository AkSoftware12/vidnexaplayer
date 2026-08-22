import 'media_kind.dart';

/// A single indexed local media item — video, photo, or music track.
///
/// [id] is the id the source plugin uses (`photo_manager`'s `AssetEntity.id`
/// for video/photo, `on_audio_query_forked`'s `SongModel.id` for music) —
/// kept here so a search result can be turned back into a playable/viewable
/// asset without another storage query.
class VideoEntity {
  final String id;
  final MediaKind mediaKind;
  final String fileName;
  final String? filePath;
  final String? folderName;
  final String? folderPath;
  final int? fileSizeBytes;
  final Duration duration;
  final DateTime createdDate;
  final DateTime modifiedDate;
  final String? mimeType;
  final String extension;
  final int width;
  final int height;

  const VideoEntity({
    required this.id,
    this.mediaKind = MediaKind.video,
    required this.fileName,
    this.filePath,
    this.folderName,
    this.folderPath,
    this.fileSizeBytes,
    required this.duration,
    required this.createdDate,
    required this.modifiedDate,
    this.mimeType,
    required this.extension,
    required this.width,
    required this.height,
  });
}
