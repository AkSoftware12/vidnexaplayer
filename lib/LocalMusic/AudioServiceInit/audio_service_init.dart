import 'package:audio_service/audio_service.dart';
import '../BackgroundAudioHandler/background_audio_handler.dart';

class AudioServiceInit {
  AudioServiceInit._();

  static BackgroundAudioHandler? _handler;

  /// `true` once [init] has completed successfully.
  ///
  /// Callers that may run before start-up finishes should check this instead
  /// of touching [handler] — the old `static late final` threw a
  /// `LateInitializationError` both when read too early AND when `init()` ran
  /// a second time ("already initialized").
  static bool get isReady => _handler != null;

  static BackgroundAudioHandler get handler {
    final h = _handler;
    if (h == null) {
      throw StateError(
        'AudioServiceInit.init() has not completed yet. '
        'Check AudioServiceInit.isReady before using the handler.',
      );
    }
    return h;
  }

  /// Safe to call more than once — subsequent calls are no-ops.
  static Future<void> init() async {
    if (_handler != null) return;

    _handler = await AudioService.init(
      builder: BackgroundAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.videoplayer.app.audio',
        androidNotificationChannelName: 'Music Playback',

        // Android requires a white-silhouette drawable here. Without it the
        // launcher icon is used and renders as a grey/white blob.
        androidNotificationIcon: 'drawable/ic_stat_music',

        androidNotificationOngoing: false,

        // ✅ FIX: don't stop the service on pause (resume + position + seek stable)
        androidStopForegroundOnPause: false,
      ),
    );
  }
}
