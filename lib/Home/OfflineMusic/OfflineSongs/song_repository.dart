import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart' show SongModel;

/// Standalone playlist helper.
///
/// NOTE: the app's real playback path is `BackgroundAudioHandler` +
/// `GlobalAudioController`. This class is not wired into any screen; it is kept
/// only because it is referenced by older code paths. Prefer deleting it rather
/// than adding new call sites.
///
/// Previously this file imported `just_audio_background`, whose `MediaItem` is a
/// *different type* from `audio_service`'s — mixing the two silently broke the
/// media session. It now uses `audio_service` like the rest of the app.
class SongRepository {
  final AudioPlayer audioPlayer = AudioPlayer();

  final List<AudioSource> _sources = <AudioSource>[];
  final List<MediaItem> _mediaItems = <MediaItem>[];

  List<MediaItem> get mediaItems => List.unmodifiable(_mediaItems);

  /// Builds an [AudioSource], or `null` when the song has no usable uri.
  AudioSource? _createAudioSource(SongModel song, MediaItem tag) {
    final raw = song.uri;
    if (raw == null || raw.trim().isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    return AudioSource.uri(uri, tag: tag);
  }

  /// Replaces the playlist with [songs], skipping entries that cannot be played.
  Future<void> setSongs(List<SongModel> songs) async {
    _sources.clear();
    _mediaItems.clear();

    for (final song in songs) {
      final item = mediaItemFromSong(song);
      final source = _createAudioSource(song, item);
      if (source == null) {
        debugPrint('Skipping unplayable song: ${song.title}');
        continue;
      }
      _mediaItems.add(item);
      _sources.add(source);
    }

    if (_sources.isEmpty) return;

    try {
      // `ConcatenatingAudioSource` is deprecated in just_audio 0.10.
      await audioPlayer.setAudioSources(List.of(_sources));
    } catch (err) {
      debugPrint('setSongs failed: $err');
    }
  }

  /// `song.duration` is null for plenty of real-world files — the old code did
  /// `Duration(milliseconds: song.duration!)` and crashed on those.
  MediaItem mediaItemFromSong(SongModel song) {
    final ms = song.duration;
    return MediaItem(
      id: song.id.toString(),
      album: song.album,
      title: song.title,
      artist: song.artist ?? 'Unknown',
      duration: ms == null ? null : Duration(milliseconds: ms),
      extras: {'url': song.uri},
    );
  }

  int indexOfMediaItem(MediaItem item) =>
      _mediaItems.indexWhere((e) => e.id == item.id);

  // ---------------- Streams ----------------
  Stream<int?> get currentIndex => audioPlayer.currentIndexStream;

  /// Emits `null` while there is no valid current item, instead of throwing a
  /// `RangeError` / null-check error the way `mediaItems[index!]` did.
  Stream<MediaItem?> get mediaItem =>
      audioPlayer.currentIndexStream.map((index) {
        if (index == null) return null;
        if (index < 0 || index >= _mediaItems.length) return null;
        return _mediaItems[index];
      });

  Stream<Duration> get position => audioPlayer.positionStream;

  Stream<bool> get shuffleModeEnabled => audioPlayer.shuffleModeEnabledStream;

  Stream<LoopMode> get loopMode => audioPlayer.loopModeStream;

  Stream<bool> get playing => audioPlayer.playingStream;

  // ---------------- Controls ----------------
  Future<void> play() => audioPlayer.play();

  Future<void> pause() => audioPlayer.pause();

  Future<void> stop() => audioPlayer.stop();

  Future<void> seek(Duration position) => audioPlayer.seek(position);

  Future<void> setVolume(double volume) => audioPlayer.setVolume(volume);

  Future<void> setSpeed(double speed) => audioPlayer.setSpeed(speed);

  Future<void> setLoopMode(LoopMode mode) => audioPlayer.setLoopMode(mode);

  Future<void> setShuffleModeEnabled(bool enabled) =>
      audioPlayer.setShuffleModeEnabled(enabled);

  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= _sources.length) return;
    await audioPlayer.seek(Duration.zero, index: index);
    await audioPlayer.play();
  }

  /// Wraps around at the end of the queue.
  Future<void> seekNext() async {
    if (_sources.isEmpty) return;
    if (audioPlayer.hasNext) {
      await audioPlayer.seekToNext();
    } else {
      await audioPlayer.seek(Duration.zero, index: 0);
    }
  }

  /// Wraps around at the start of the queue.
  Future<void> seekPrevious() async {
    if (_sources.isEmpty) return;
    if (audioPlayer.hasPrevious) {
      await audioPlayer.seekToPrevious();
    } else {
      await audioPlayer.seek(Duration.zero, index: _sources.length - 1);
    }
  }

  /// Releases the underlying player. Callers own this object's lifetime.
  Future<void> dispose() => audioPlayer.dispose();
}
