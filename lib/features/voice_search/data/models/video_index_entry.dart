import 'package:path/path.dart' as p;

import '../../domain/entities/media_kind.dart';
import '../../domain/entities/video_entity.dart';

/// The sqflite row shape for `video_index`. Separate from [VideoEntity] so
/// the domain layer never has to know about column names or that
/// `fileSizeBytes` can be transiently null while phase-2 backfill catches up.
///
/// [id] is the DB primary key: `"<mediaKind>:<sourceId>"`. Video, photo and
/// music ids are drawn from independent MediaStore sequences (`AssetEntity`
/// for video/photo, `SongModel` for music) and can collide numerically, so a
/// bare source id can't be the primary key on its own — [sourceId] is kept
/// alongside it for building playback lookups.
class VideoIndexEntry {
  final String sourceId;
  final MediaKind mediaKind;
  final String fileName;
  final String? filePath;
  final String? folderName;
  final String? folderPath;
  final int? fileSizeBytes;
  final int durationMs;
  final int createdAt;
  final int modifiedAt;
  final String? mimeType;
  final String extension;
  final int width;
  final int height;
  final int indexedAt;

  const VideoIndexEntry({
    required this.sourceId,
    required this.mediaKind,
    required this.fileName,
    this.filePath,
    this.folderName,
    this.folderPath,
    this.fileSizeBytes,
    required this.durationMs,
    required this.createdAt,
    required this.modifiedAt,
    this.mimeType,
    required this.extension,
    required this.width,
    required this.height,
    required this.indexedAt,
  });

  String get id => compositeId(mediaKind, sourceId);

  static String compositeId(MediaKind kind, String sourceId) =>
      '${kind.storageKey}:$sourceId';

  factory VideoIndexEntry.fromMap(Map<String, Object?> map) {
    return VideoIndexEntry(
      sourceId: map['source_id'] as String,
      mediaKind: MediaKind.fromStorageKey(map['media_kind'] as String?),
      fileName: map['file_name'] as String,
      filePath: map['file_path'] as String?,
      folderName: map['folder_name'] as String?,
      folderPath: map['folder_path'] as String?,
      fileSizeBytes: map['file_size_bytes'] as int?,
      durationMs: map['duration_ms'] as int? ?? 0,
      createdAt: map['created_at'] as int? ?? 0,
      modifiedAt: map['modified_at'] as int? ?? 0,
      mimeType: map['mime_type'] as String?,
      extension: map['extension'] as String? ?? '',
      width: map['width'] as int? ?? 0,
      height: map['height'] as int? ?? 0,
      indexedAt: map['indexed_at'] as int? ?? 0,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'source_id': sourceId,
        'media_kind': mediaKind.storageKey,
        'file_name': fileName,
        'file_name_lower': fileName.toLowerCase(),
        'file_path': filePath,
        'folder_name': folderName,
        'folder_name_lower': folderName?.toLowerCase(),
        'folder_path': folderPath,
        'file_size_bytes': fileSizeBytes,
        'duration_ms': durationMs,
        'created_at': createdAt,
        'modified_at': modifiedAt,
        'mime_type': mimeType,
        'extension': extension,
        'width': width,
        'height': height,
        'indexed_at': indexedAt,
      };

  VideoEntity toEntity() => VideoEntity(
        id: sourceId,
        mediaKind: mediaKind,
        fileName: fileName,
        filePath: filePath,
        folderName: folderName,
        folderPath: folderPath,
        fileSizeBytes: fileSizeBytes,
        duration: Duration(milliseconds: durationMs),
        createdDate: DateTime.fromMillisecondsSinceEpoch(createdAt),
        modifiedDate: DateTime.fromMillisecondsSinceEpoch(modifiedAt),
        mimeType: mimeType,
        extension: extension,
        width: width,
        height: height,
      );

  static String extensionOf(String fileName) {
    final ext = p.extension(fileName);
    return ext.isEmpty ? '' : ext.substring(1).toLowerCase();
  }
}
