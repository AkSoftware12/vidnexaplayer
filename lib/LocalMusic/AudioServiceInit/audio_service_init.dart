import 'package:audio_service/audio_service.dart';
import '../BackgroundAudioHandler/background_audio_handler.dart';

class AudioServiceInit {
  static late final BackgroundAudioHandler handler;

  static Future<void> init() async {
    handler = await AudioService.init(
      builder: () => BackgroundAudioHandler(),
      config:  AudioServiceConfig(
        androidNotificationChannelId: 'com.videoplayer.app.audio',
        androidNotificationChannelName: 'Music Playback',

        androidNotificationOngoing: false,

        // ✅ FIX: pause pe service stop mat karo (resume + position + seek stable)
        androidStopForegroundOnPause: false,
      ),
    );
  }
}
