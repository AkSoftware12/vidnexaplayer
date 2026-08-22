import 'package:flutter_test/flutter_test.dart';
import 'package:videoplayer/features/voice_search/domain/entities/media_kind.dart';
import 'package:videoplayer/features/voice_search/domain/entities/video_entity.dart';
import 'package:videoplayer/features/voice_search/domain/entities/video_search_query.dart';
import 'package:videoplayer/features/voice_search/domain/repositories/video_search_repository.dart';
import 'package:videoplayer/features/voice_search/presentation/controllers/voice_search_controller.dart';

/// In-memory fake — the controller is only ever exercised through the
/// `VideoSearchRepository` interface, never through real sqflite/photo_manager
/// plugin channels (those aren't available under `flutter test`).
class FakeVideoSearchRepository implements VideoSearchRepository {
  FakeVideoSearchRepository(this._all);

  final List<VideoEntity> _all;
  Object? searchError;
  int searchCallCount = 0;
  final List<String> removedIds = [];

  @override
  Future<List<VideoEntity>> search(
    VideoSearchQuery query, {
    int offset = 0,
    int limit = 40,
  }) async {
    searchCallCount++;
    if (searchError != null) throw searchError!;
    if (offset >= _all.length) return [];
    final end = (offset + limit).clamp(0, _all.length);
    return _all.sublist(offset, end);
  }

  @override
  Future<bool> isIndexReady() async => _all.isNotEmpty;

  @override
  Future<int> indexedCount() async => _all.length;

  @override
  Future<void> rebuildIndex({void Function(int done, int total)? onProgress}) async {}

  @override
  Future<VideoEntity?> findById(MediaKind kind, String id) async {
    for (final v in _all) {
      if (v.id == id && v.mediaKind == kind) return v;
    }
    return null;
  }

  @override
  Future<void> removeStaleEntry(MediaKind kind, String id) async {
    removedIds.add(id);
    _all.removeWhere((v) => v.id == id && v.mediaKind == kind);
  }
}

VideoEntity _video(String id) => VideoEntity(
      id: id,
      fileName: '$id.mp4',
      duration: const Duration(minutes: 2),
      createdDate: DateTime(2026, 1, 1),
      modifiedDate: DateTime(2026, 1, 1),
      extension: 'mp4',
      width: 1920,
      height: 1080,
    );

void main() {
  group('VoiceSearchController.runTextQuery', () {
    test('idle -> processing -> searching -> results', () async {
      final repo = FakeVideoSearchRepository([_video('a'), _video('b')]);
      final controller = VoiceSearchController(repository: repo);
      final states = <VoiceSearchState>[];
      controller.addListener(() => states.add(controller.state));

      await controller.runTextQuery('recent videos');

      expect(states, containsAllInOrder([
        VoiceSearchState.processing,
        VoiceSearchState.searching,
        VoiceSearchState.results,
      ]));
      expect(controller.results, hasLength(2));
      expect(controller.lastQuery, isNotNull);
      expect(controller.lastQuery!.sortBy, VideoSortOrder.dateDesc);
    });

    test('moves to noResults when nothing matches', () async {
      final repo = FakeVideoSearchRepository([]);
      final controller = VoiceSearchController(repository: repo);

      await controller.runTextQuery('birthday video');

      expect(controller.state, VoiceSearchState.noResults);
      expect(controller.results, isEmpty);
    });

    test('moves to speechError with a friendly message when search throws', () async {
      final repo = FakeVideoSearchRepository([])..searchError = Exception('db exploded');
      final controller = VoiceSearchController(repository: repo);

      await controller.runTextQuery('mp4 videos');

      expect(controller.state, VoiceSearchState.speechError);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, isNot(contains('db exploded')));
    });
  });

  group('VoiceSearchController.loadMore', () {
    test('appends the next page and flags hasMore = false on a short page', () async {
      final videos = List.generate(45, (i) => _video('v$i'));
      final repo = FakeVideoSearchRepository(videos);
      final controller = VoiceSearchController(repository: repo);

      await controller.runTextQuery('recent videos'); // first page: 40
      expect(controller.results, hasLength(40));
      expect(controller.hasMore, isTrue);

      await controller.loadMore(); // second page: remaining 5
      expect(controller.results, hasLength(45));
      expect(controller.hasMore, isFalse);
    });

    test('does nothing before a search has run', () async {
      final repo = FakeVideoSearchRepository([_video('a')]);
      final controller = VoiceSearchController(repository: repo);

      await controller.loadMore();

      expect(repo.searchCallCount, 0);
      expect(controller.results, isEmpty);
    });

    test('ignores loadMore once hasMore is false', () async {
      final repo = FakeVideoSearchRepository([_video('a')]);
      final controller = VoiceSearchController(repository: repo);

      await controller.runTextQuery('mp4 videos');
      expect(controller.hasMore, isFalse);

      final callsBefore = repo.searchCallCount;
      await controller.loadMore();
      expect(repo.searchCallCount, callsBefore);
    });
  });

  group('VoiceSearchController.removeStale', () {
    test('drops the item and calls the repository', () async {
      final repo = FakeVideoSearchRepository([_video('a'), _video('b')]);
      final controller = VoiceSearchController(repository: repo);
      await controller.runTextQuery('mp4 videos');

      await controller.removeStale(MediaKind.video, 'a');

      expect(repo.removedIds, ['a']);
      expect(controller.results.map((v) => v.id), ['b']);
      expect(controller.state, VoiceSearchState.results);
    });

    test('moves to noResults when the last item is removed', () async {
      final repo = FakeVideoSearchRepository([_video('a')]);
      final controller = VoiceSearchController(repository: repo);
      await controller.runTextQuery('mp4 videos');

      await controller.removeStale(MediaKind.video, 'a');

      expect(controller.results, isEmpty);
      expect(controller.state, VoiceSearchState.noResults);
    });
  });

  group('VoiceSearchController.reset', () {
    test('clears everything back to idle', () async {
      final repo = FakeVideoSearchRepository([_video('a')]);
      final controller = VoiceSearchController(repository: repo);
      await controller.runTextQuery('mp4 videos');

      controller.reset();

      expect(controller.state, VoiceSearchState.idle);
      expect(controller.results, isEmpty);
      expect(controller.lastQuery, isNull);
      expect(controller.recognizedText, isEmpty);
    });
  });
}
