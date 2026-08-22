import 'media_kind.dart';

/// How results should be ordered when no free-text relevance ranking applies.
enum VideoSortOrder {
  /// Filename relevance (exact > prefix > folder match > rest), then newest first.
  relevance,

  /// Newest first — used by "recent"/"latest" style commands.
  dateDesc,
}

/// A structured, storage-agnostic description of what the user asked for.
///
/// Produced by `VoiceCommandParser.parse()` and consumed by
/// `VideoSearchRepository.search()`. Every field is an independent filter —
/// callers combine as many as apply, which is what makes commands like
/// "Downloads folder me 1 GB se badi MP4 videos dikhao" work: each clause is
/// just another non-null field on the same query.
class VideoSearchQuery {
  final MediaKind mediaKind;
  final String? text;
  final String? folder;
  final String? extension;
  final int? minSizeBytes;
  final int? maxSizeBytes;
  final Duration? minDuration;
  final Duration? maxDuration;
  final DateTime? fromDate;
  final DateTime? toDate;
  final VideoSortOrder sortBy;

  const VideoSearchQuery({
    this.mediaKind = MediaKind.video,
    this.text,
    this.folder,
    this.extension,
    this.minSizeBytes,
    this.maxSizeBytes,
    this.minDuration,
    this.maxDuration,
    this.fromDate,
    this.toDate,
    this.sortBy = VideoSortOrder.relevance,
  });

  static const empty = VideoSearchQuery();

  /// True when nothing distinguishes this from "just show me videos" — the
  /// default [mediaKind] doesn't count as a filter, but an explicit
  /// photo/music kind does (e.g. a bare "photo dikhao" is a real query).
  bool get isEmpty =>
      mediaKind == MediaKind.video &&
      text == null &&
      folder == null &&
      extension == null &&
      minSizeBytes == null &&
      maxSizeBytes == null &&
      minDuration == null &&
      maxDuration == null &&
      fromDate == null &&
      toDate == null;

  VideoSearchQuery copyWith({
    MediaKind? mediaKind,
    String? text,
    String? folder,
    String? extension,
    int? minSizeBytes,
    int? maxSizeBytes,
    Duration? minDuration,
    Duration? maxDuration,
    DateTime? fromDate,
    DateTime? toDate,
    VideoSortOrder? sortBy,
  }) {
    return VideoSearchQuery(
      mediaKind: mediaKind ?? this.mediaKind,
      text: text ?? this.text,
      folder: folder ?? this.folder,
      extension: extension ?? this.extension,
      minSizeBytes: minSizeBytes ?? this.minSizeBytes,
      maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
      minDuration: minDuration ?? this.minDuration,
      maxDuration: maxDuration ?? this.maxDuration,
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  @override
  String toString() =>
      'VideoSearchQuery(mediaKind: $mediaKind, text: $text, folder: $folder, '
      'extension: $extension, minSizeBytes: $minSizeBytes, maxSizeBytes: $maxSizeBytes, '
      'minDuration: $minDuration, maxDuration: $maxDuration, '
      'fromDate: $fromDate, toDate: $toDate, sortBy: $sortBy)';

  @override
  bool operator ==(Object other) =>
      other is VideoSearchQuery &&
      other.mediaKind == mediaKind &&
      other.text == text &&
      other.folder == folder &&
      other.extension == extension &&
      other.minSizeBytes == minSizeBytes &&
      other.maxSizeBytes == maxSizeBytes &&
      other.minDuration == minDuration &&
      other.maxDuration == maxDuration &&
      other.fromDate == fromDate &&
      other.toDate == toDate &&
      other.sortBy == sortBy;

  @override
  int get hashCode => Object.hash(
        mediaKind,
        text,
        folder,
        extension,
        minSizeBytes,
        maxSizeBytes,
        minDuration,
        maxDuration,
        fromDate,
        toDate,
        sortBy,
      );
}
