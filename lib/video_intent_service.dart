import 'package:flutter/services.dart';

class VideoIntentService {
  static const MethodChannel _channel = MethodChannel('open_video_channel');

  static Future<String?> getVideoPath() async {
    try {
      return await _channel.invokeMethod<String>('getVideoPath');
    } catch (_) {
      return null;
    }
  }
}