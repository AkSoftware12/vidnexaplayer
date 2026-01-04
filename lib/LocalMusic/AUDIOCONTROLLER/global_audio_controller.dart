import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

  GlobalAudioController._internal() {
    _bindStreams();
  }

  final OnAudioQuery _audioQuery = OnAudioQuery();

  BackgroundAudioHandler get handler => AudioServiceInit.handler;
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

  // ---------------- Play playlist ----------------
  Future<void> playSongs(List<SongModel> songs, int index) async {
    if (songs.isEmpty) return;

    currentSongs.value = songs;
    currentIndex.value = index;

    // ✅ parallel artwork caching (fast)
    final artUris = await Future.wait(
      songs.map((s) => _cacheArtworkToFile(songId: s.id)).toList(),
    );

    final mediaItems = <MediaItem>[];
    final sources = <AudioSource>[];

    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      final artFileUri = artUris[i];

      final item = MediaItem(
        id: song.id.toString(),
        title: song.title,
        artist: song.artist ?? 'Unknown',
        artUri: artFileUri,
      );

      mediaItems.add(item);
      sources.add(
        AudioSource.uri(
          Uri.parse(song.uri!),
          tag: item,
        ),
      );
    }

    await handler.setPlaylist(
      items: mediaItems,
      sources: sources,
      initialIndex: index,
      autoplay: true,
    );

    hasPlayedOnce.value = true;
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

  Future<void> dispose() async {
    await _indexSub?.cancel();
    await _pbSub?.cancel();
    await _stateSub?.cancel();
    await _queueSub?.cancel();
    await _customSub?.cancel();
    await player.dispose();
  }
}
