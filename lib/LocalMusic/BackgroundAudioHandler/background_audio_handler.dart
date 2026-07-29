import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class BackgroundAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  AudioPlayer get player => _player;

  Timer? _sleepTimer;
  Timer? _ticker;
  DateTime? _sleepEndAt;

  // Kept so they can actually be cancelled — the old code subscribed without
  // ever holding on to the subscriptions.
  StreamSubscription<PlaybackEvent>? _eventSub;
  StreamSubscription<int?>? _indexSub;

  BackgroundAudioHandler() {
    _eventSub = _player.playbackEventStream.listen(
      _broadcastState,
      onError: (Object e, StackTrace st) {
        // A decode error must not kill the whole media session.
        debugPrint('Playback error: $e');
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.error,
            playing: false,
          ),
        );
      },
    );

    // ✅ current item sync
    _indexSub = _player.currentIndexStream.listen((index) {
      final q = queue.value;
      if (index == null || q.isEmpty || index >= q.length) return;
      mediaItem.add(q[index]);
    });
  }

  /// Releases the player and its subscriptions.
  Future<void> shutdown() async {
    await _eventSub?.cancel();
    await _indexSub?.cancel();
    _sleepTimer?.cancel();
    _ticker?.cancel();
    await _player.dispose();
  }

  // ---------------- Playlist ----------------
  Future<void> setPlaylist({
    required List<MediaItem> items,
    required List<AudioSource> sources,
    int initialIndex = 0,
    bool autoplay = true,
  }) async {
    if (items.isEmpty || sources.isEmpty) return;

    // ✅ keep same length
    queue.add(List<MediaItem>.from(items));

    final start = initialIndex.clamp(0, items.length - 1);

    // `ConcatenatingAudioSource` is deprecated in just_audio 0.10.
    await _player.setAudioSources(
      sources,
      initialIndex: start,
      preload: true,
    );

    mediaItem.add(items[start]);

    if (autoplay) {
      await _player.play();
    } else {
      await _player.pause();
    }
  }

  // ---------------- Sleep Timer ----------------
  Future<void> setSleepTimer(Duration? duration) async {
    await cancelSleepTimer();
    if (duration == null || duration == Duration.zero) return;

    _sleepEndAt = DateTime.now().add(duration);

    _emitRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _emitRemaining());

    _sleepTimer = Timer(duration, () async {
      // ✅ pause + clear
      await pause();
      await cancelSleepTimer();
    });
  }

  Future<void> cancelSleepTimer() async {
    _sleepTimer?.cancel();
    _sleepTimer = null;

    _ticker?.cancel();
    _ticker = null;

    _sleepEndAt = null;

    customEvent.add({"type": "sleep_timer", "remaining_ms": 0});
  }

  void _emitRemaining() {
    if (_sleepEndAt == null) return;
    final diff = _sleepEndAt!.difference(DateTime.now());
    final remaining = diff.isNegative ? Duration.zero : diff;

    customEvent.add({
      "type": "sleep_timer",
      "remaining_ms": remaining.inMilliseconds,
    });

    // ✅ auto stop when reaches zero (extra safety)
    if (remaining == Duration.zero) {
      cancelSleepTimer();
    }
  }

  // UI will call via handler.customAction(...)
  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case 'setSleepTimer':
        final ms = extras?['ms'] as int?;
        if (ms == null) return null;
        await setSleepTimer(Duration(milliseconds: ms));
        return true;

      case 'cancelSleepTimer':
        await cancelSleepTimer();
        return true;

      case 'getSleepRemaining':
        if (_sleepEndAt == null) return 0;
        final diff = _sleepEndAt!.difference(DateTime.now());
        return diff.isNegative ? 0 : diff.inMilliseconds;
    }
    return super.customAction(name, extras);
  }

  // ---------------- Device Controls ----------------
  @override
  Future<void> play() async {
    // ✅ Fix: if completed then restart
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }

    // ✅ Fix: if ready but position == duration (some devices)
    final dur = _player.duration;
    if (dur != null && _player.position >= dur) {
      await _player.seek(Duration.zero);
    }

    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    await cancelSleepTimer();

    // ✅ clear playback safely
    await _player.stop();
    await _player.seek(Duration.zero);

    queue.add(<MediaItem>[]);
    mediaItem.add(null); // ⚠️ BaseAudioHandler allows nullable stream

    // ✅ also broadcast idle state
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        queueIndex: null,
      ),
    );

    return super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Wraps to the first track at the end of the queue.
  /// The old version silently did nothing on the last song, so the notification
  /// "next" button appeared broken.
  @override
  Future<void> skipToNext() async {
    final len = queue.value.length;
    if (len == 0) return;

    if (_player.hasNext) {
      await _player.seekToNext();
    } else {
      await _player.seek(Duration.zero, index: 0);
    }
    await _player.play();
  }

  /// Standard media behaviour: restart the track if we're more than 3 seconds
  /// in, otherwise go to the previous one (wrapping to the last).
  @override
  Future<void> skipToPrevious() async {
    final len = queue.value.length;
    if (len == 0) return;

    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      await _player.seek(Duration.zero, index: len - 1);
    }
    await _player.play();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    // ✅ bounds safe
    final qLen = queue.value.length;
    if (qLen == 0) return;
    final i = index.clamp(0, qLen - 1);

    await _player.seek(Duration.zero, index: i);
    await _player.play(); // ✅ always play on selection
  }

  // ---------------- PlaybackState sync ----------------
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;

    final ps = _player.processingState;
    final audioState = _mapProcessingState(ps);

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: audioState,
        playing: playing,

        // ✅ critical: use event position for accuracy
        updatePosition: event.updatePosition,
        bufferedPosition: event.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState ps) {
    switch (ps) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
