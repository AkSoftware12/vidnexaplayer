import 'package:flutter_test/flutter_test.dart';
import 'package:videoplayer/features/voice_search/domain/entities/video_search_query.dart';

void main() {
  group('VideoSearchQuery', () {
    test('empty query has isEmpty = true', () {
      expect(VideoSearchQuery.empty.isEmpty, isTrue);
    });

    test('any single non-null field makes isEmpty false', () {
      expect(VideoSearchQuery.empty.copyWith(text: 'x').isEmpty, isFalse);
      expect(VideoSearchQuery.empty.copyWith(folder: 'download').isEmpty, isFalse);
      expect(VideoSearchQuery.empty.copyWith(extension: 'mp4').isEmpty, isFalse);
      expect(VideoSearchQuery.empty.copyWith(minSizeBytes: 1).isEmpty, isFalse);
    });

    test('copyWith only overrides the given field', () {
      const base = VideoSearchQuery(folder: 'download', extension: 'mp4');
      final updated = base.copyWith(extension: 'mkv');
      expect(updated.folder, 'download');
      expect(updated.extension, 'mkv');
    });

    test('equality is value-based', () {
      const a = VideoSearchQuery(folder: 'download', extension: 'mp4');
      const b = VideoSearchQuery(folder: 'download', extension: 'mp4');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('sortBy defaults to relevance', () {
      expect(VideoSearchQuery.empty.sortBy, VideoSortOrder.relevance);
    });
  });
}
