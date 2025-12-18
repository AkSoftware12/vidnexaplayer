import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query_forked/on_audio_query.dart';

class GlobalAudioController {
  /// 🔥 SINGLETON
  static final GlobalAudioController _instance =
  GlobalAudioController._internal();

  factory GlobalAudioController() => _instance;

  GlobalAudioController._internal() {
    player.playerStateStream.listen((state) {
      // show mini player
      if (state.processingState == ProcessingState.ready &&
          player.sequenceState?.sequence.isNotEmpty == true &&
          hasPlayedOnce.value == false) {
        hasPlayedOnce.value = true;
      }

      // hide mini player
      if (state.processingState == ProcessingState.idle &&
          player.sequenceState == null) {
        hasPlayedOnce.value = false;
      }
    });
  }


  /// 🎧 AUDIO PLAYER
  final AudioPlayer player = AudioPlayer();

  /// 🔥 MINI PLAYER VISIBILITY FLAG
  final ValueNotifier<bool> hasPlayedOnce = ValueNotifier(false);

  // ---------------------------------------------------------------------------
  // 🎶 PLAY SINGLE (resume)
  // ---------------------------------------------------------------------------
  void play() {
    player.play();
  }

  // ---------------------------------------------------------------------------
  // 🎵 PLAY SONG LIST (FIRST TIME / NEW PLAYLIST)
  // ---------------------------------------------------------------------------
  Future<void> playSongs(List<SongModel> songs, int index) async {
    if (songs.isEmpty) return;

    final playlist = ConcatenatingAudioSource(
      children: songs.map((song) {
        return AudioSource.uri(
          Uri.parse(song.uri!),
          tag: MediaItem(
            id: song.id.toString(),
            title: song.title,
            artist: song.artist ?? 'Unknown',
            /// 🖼️ ALBUM ART
            artUri: Uri.parse(
              "content://media/external/audio/album/${song.albumId}",
            ),
          ),
        );
      }).toList(),
    );

    await player.setAudioSource(
      playlist,
      initialIndex: index,
      preload: true,
    );

    await player.play();
  }

  // ---------------------------------------------------------------------------
  // ⏸ PAUSE
  // ---------------------------------------------------------------------------
  void pause() {
    player.pause();
  }

  // ---------------------------------------------------------------------------
  // ⏭ NEXT
  // ---------------------------------------------------------------------------
  void next() {
    if (player.hasNext) {
      player.seekToNext();
    }
  }

  // ---------------------------------------------------------------------------
  // ⏮ PREVIOUS
  // ---------------------------------------------------------------------------
  void previous() {
    if (player.hasPrevious) {
      player.seekToPrevious();
    }
  }

  // ---------------------------------------------------------------------------
  // ❌ CLOSE MINI PLAYER + STOP AUDIO
  // ---------------------------------------------------------------------------
  Future<void> closeMiniPlayer() async {
    await player.stop();
    hasPlayedOnce.value = false;
  }

  // ---------------------------------------------------------------------------
  // 🧹 DISPOSE (optional – app close)
  // ---------------------------------------------------------------------------
  Future<void> dispose() async {
    await player.dispose();
  }
}
