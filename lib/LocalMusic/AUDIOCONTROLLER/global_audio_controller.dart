import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';

import '../AudioServiceInit/audio_service_init.dart';
import '../BackgroundAudioHandler/background_audio_handler.dart';

class GlobalAudioController {
  static final GlobalAudioController _instance =
  GlobalAudioController._internal();
  factory GlobalAudioController() => _instance;

  // Streams are bound lazily on first use. Binding them in the constructor
  // reached for `AudioServiceInit.handler` — a `late final` — so merely
  // touching this singleton before AudioService finished initialising threw
  // a LateInitializationError.
  GlobalAudioController._internal();

  bool _bound = false;

  void _ensureBound() {
    if (_bound) return;
    if (!AudioServiceInit.isReady) return;
    _bound = true;
    _bindStreams();
  }

  final OnAudioQuery _audioQuery = OnAudioQuery();

  BackgroundAudioHandler get handler {
    final h = AudioServiceInit.handler;
    _ensureBound();
    return h;
  }

  AudioPlayer get player => handler.player;

  final ValueNotifier<List<SongModel>> currentSongs =
  ValueNotifier<List<SongModel>>([]);
  final ValueNotifier<int> currentIndex = ValueNotifier<int>(0);
  final ValueNotifier<bool> hasPlayedOnce = ValueNotifier(false);

  /// ✅ Remaining timer countdown for badge
  final ValueNotifier<Duration?> sleepRemaining =
  ValueNotifier<Duration?>(null);

  StreamSubscription<int?>? _indexSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<List<MediaItem>>? _queueSub;
  StreamSubscription<dynamic>? _customSub;
  StreamSubscription<PlaybackState>? _pbSub;

  void _bindStreams() {
    _indexSub = player.currentIndexStream.listen((i) {
      if (i != null) currentIndex.value = i;
    });

    // ✅ MORE RELIABLE index sync (device/notification changes)
    _pbSub = handler.playbackState.listen((ps) {
      final idx = ps.queueIndex;
      if (idx != null) currentIndex.value = idx;
    });

    // ✅ fixed show/hide logic
    _stateSub = player.playerStateStream.listen((state) {
      final hasQueue = handler.queue.value.isNotEmpty;

      if (state.processingState == ProcessingState.ready && hasQueue) {
        hasPlayedOnce.value = true;
      }

      if (state.processingState == ProcessingState.idle || !hasQueue) {
        hasPlayedOnce.value = false;
      }
    });

    _queueSub = handler.queue.listen((q) {
      if (q.isEmpty) hasPlayedOnce.value = false;
    });

    /// ✅ listen countdown events from handler
    _customSub = handler.customEvent.listen((event) {
      if (event is Map && event["type"] == "sleep_timer") {
        final ms = (event["remaining_ms"] as int?) ?? 0;
        sleepRemaining.value =
        ms <= 0 ? null : Duration(milliseconds: ms);
      }
    });
  }

  // ---------------- Player controls (device-safe) ----------------
  void play() => handler.play();
  void pause() => handler.pause();
  void next() => handler.skipToNext();
  void previous() => handler.skipToPrevious();

  Future<void> closeMiniPlayer() async {
    await handler.stop();
    hasPlayedOnce.value = false;
  }

  // ---------------- Sleep timer bridge ----------------
  Future<void> setSleepTimer(Duration? d) async {
    if (d == null || d == Duration.zero) {
      await cancelSleepTimer();
      return;
    }
    await handler.customAction('setSleepTimer', {'ms': d.inMilliseconds});
  }

  Future<void> cancelSleepTimer() async {
    await handler.customAction('cancelSleepTimer');
  }

  // ---------------- Artwork cache (file:// for notification) ----------------
  Future<Uri?> _cacheArtworkToFile({required int songId}) async {
    try {
      final Uint8List? bytes = await _audioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        size: 800,
        quality: 100,
      );
      if (bytes == null || bytes.isEmpty) return null;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/art_$songId.jpg');

      // ✅ always overwrite (avoid wrong/stale image)
      await file.writeAsBytes(bytes, flush: true);

      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  // ---------------- Play a single external "Open with" audio file ----------------
  /// Plays an arbitrary `content://`/`file://` audio uri handed to the app by
  /// another app (file manager, WhatsApp, etc.) via "Open with". Unlike
  /// [playSongs] this has no [SongModel] from the device library to work
  /// with, so it builds a single-item queue directly and clears
  /// [currentSongs] — the full-player artwork carousel falls back to a plain
  /// music-note icon for it instead of crashing on a fake id.
  Future<void> playExternalUri(String uriString, {String? title}) async {
    final uri = Uri.tryParse(uriString);
    if (uri == null) return;

    final item = MediaItem(
      id: uriString,
      title: (title == null || title.trim().isEmpty) ? 'Audio' : title.trim(),
      artist: 'Unknown',
    );

    currentSongs.value = [];
    currentIndex.value = 0;

    await handler.setPlaylist(
      items: [item],
      sources: [AudioSource.uri(uri, tag: item)],
      initialIndex: 0,
      autoplay: true,
    );

    hasPlayedOnce.value = true;
  }

  // ---------------- Play playlist ----------------
  /// How many artworks around the current track are pre-cached.
  ///
  /// The old code did `Future.wait(songs.map(_cacheArtworkToFile))` over the
  /// ENTIRE list — on a 2000-song library that is 2000 concurrent 800px artwork
  /// queries plus 2000 temp files, i.e. a guaranteed ANR / OOM.
  static const int _artworkPrefetchRadius = 3;

  Future<void> playSongs(List<SongModel> songs, int index) async {
    if (songs.isEmpty) return;

    final mediaItems = <MediaItem>[];
    final sources = <AudioSource>[];
    final playable = <SongModel>[];

    for (final song in songs) {
      final raw = song.uri;
      if (raw == null || raw.trim().isEmpty) continue;

      // `Uri.parse(song.uri!)` threw on both null and malformed uris.
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;

      final item = MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown',
        album: song.album,
        duration: song.duration == null
            ? null
            : Duration(milliseconds: song.duration!),
      );

      playable.add(song);
      mediaItems.add(item);
      sources.add(AudioSource.uri(uri, tag: item));
    }

    if (mediaItems.isEmpty) return;

    // The requested song may have been filtered out; keep pointing at it.
    final requested = index >= 0 && index < songs.length ? songs[index] : null;
    var startIndex = requested == null
        ? 0
        : playable.indexWhere((s) => s.id == requested.id);
    if (startIndex < 0) startIndex = 0;

    currentSongs.value = playable;
    currentIndex.value = startIndex;

    await handler.setPlaylist(
      items: mediaItems,
      sources: sources,
      initialIndex: startIndex,
      autoplay: true,
    );

    hasPlayedOnce.value = true;

    // Fill in artwork for the current track and its neighbours only, and update
    // the media items in place so the notification still shows cover art.
    unawaited(_prefetchArtwork(playable, mediaItems, startIndex));
  }

  Future<void> _prefetchArtwork(
    List<SongModel> songs,
    List<MediaItem> items,
    int centre,
  ) async {
    final from = (centre - _artworkPrefetchRadius).clamp(0, songs.length - 1);
    final to = (centre + _artworkPrefetchRadius).clamp(0, songs.length - 1);

    for (int i = from; i <= to; i++) {
      final art = await _cacheArtworkToFile(songId: songs[i].id);
      if (art == null) continue;

      items[i] = items[i].copyWith(artUri: art);
      try {
        await handler.updateMediaItem(items[i]);
      } catch (_) {
        // Item may no longer be in the queue.
      }
    }
  }

  /// Deletes cached artwork thumbnails from the temp directory.
  /// Nothing used to clean these up, so they accumulated forever.
  Future<void> clearArtworkCache() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list()) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is File && name.startsWith('art_') && name.endsWith('.jpg')) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  // ---------------- Seek helpers ----------------
  Future<void> seekBackward({int seconds = 10}) async {
    final current = player.position;
    final newPos = current - Duration(seconds: seconds);
    await handler.seek(newPos < Duration.zero ? Duration.zero : newPos);
  }

  Future<void> seekForward({int seconds = 10}) async {
    final total = player.duration;
    if (total == null) return;
    final current = player.position;
    final newPos = current + Duration(seconds: seconds);
    await handler.seek(newPos > total ? total : newPos);
  }

  /// Detaches this controller's listeners.
  ///
  /// Deliberately does NOT dispose the player: this is an app-wide singleton
  /// sharing the audio handler's player, and disposing it here killed playback
  /// for everyone.
  Future<void> dispose() async {
    await _indexSub?.cancel();
    await _pbSub?.cancel();
    await _stateSub?.cancel();
    await _queueSub?.cancel();
    await _customSub?.cancel();
    _bound = false;
  }
}
