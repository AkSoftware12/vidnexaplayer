import 'dart:async';
import 'package:flutter/services.dart';

class EqualizerFlutter {
  static const MethodChannel _ch = MethodChannel('equalizer_flutter');

  /// Open equalizer attached to a given [audioSessionId].
  /// Use 0 for global output mix. Returns true if supported.
  static Future<bool> open(int audioSessionId) async {
    final ok = await _ch.invokeMethod<bool>('open', {'sessionId': audioSessionId});
    return ok ?? false;
  }

  /// Release resources.
  static Future<void> release() => _ch.invokeMethod('release');

  /// Get available center band frequencies (Hz).
  static Future<List<int>?> getCenterBandFreqs() async {
    final list = await _ch.invokeMethod<List<dynamic>>('getCenterBandFreqs');
    return list?.map((e) => e as int).toList();
  }

  /// Get min gain (millibels), usually -1500.
  static Future<int?> getBandLevelRangeMin() async =>
      await _ch.invokeMethod<int>('getBandLevelRangeMin');

  /// Get max gain (millibels), usually +1500.
  static Future<int?> getBandLevelRangeMax() async =>
      await _ch.invokeMethod<int>('getBandLevelRangeMax');

  /// Set band [bandIndex] level in millibels.
  static Future<void> setBandLevel(int bandIndex, int levelMb) =>
      _ch.invokeMethod('setBandLevel', {'bandIndex': bandIndex, 'level': levelMb});

  /// Get band [bandIndex] level in millibels.
  static Future<int?> getBandLevel(int bandIndex) =>
      _ch.invokeMethod<int>('getBandLevel', {'bandIndex': bandIndex});

  /// Get available preset names (device-provided).
  static Future<List<String>?> getPresetNames() async {
    final list = await _ch.invokeMethod<List<dynamic>>('getPresetNames');
    return list?.map((e) => e.toString()).toList();
  }

  /// Apply a device preset by name. Returns true if applied.
  static Future<bool> setPreset(String presetName) async {
    final ok = await _ch.invokeMethod<bool>('setPreset', {'name': presetName});
    return ok ?? false;
  }
}
