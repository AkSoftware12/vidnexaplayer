import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/eq_models.dart';
import '../domain/genre_classifier.dart';

/// Thin, total wrapper over the `AudioEffectsPlugin` channels.
///
/// Every call is guarded: on a non-Android platform, on a device whose vendor
/// audiofx stack rejects the effect, or if the plugin is simply not registered,
/// the call returns a benign default instead of throwing. The rest of the
/// feature is written assuming this class never raises.
class AudioEffectsPlatform {
  AudioEffectsPlatform._();

  static final AudioEffectsPlatform instance = AudioEffectsPlatform._();

  static const MethodChannel _method = MethodChannel('vidnexa/audio_effects');
  static const EventChannel _visualizer =
      EventChannel('vidnexa/audio_effects/visualizer');
  static const EventChannel _device =
      EventChannel('vidnexa/audio_effects/output_device');

  bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    if (!isSupportedPlatform) return null;
    try {
      return await _method.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('[eq] $method failed: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('[eq] $method failed: $e');
      return null;
    }
  }

  /// A session id we own. Handed to libmpv via `audiotrack-session-id` so the
  /// video path can use the same hardware effects as music.
  /// Returns null when the platform could not allocate one.
  Future<int?> generateSessionId() async {
    final id = await _invoke<int>('generateSessionId');
    // AudioManager.ERROR (-1) and 0 both mean "no usable session".
    if (id == null || id <= 0) return null;
    return id;
  }

  /// Creates the effect bundle for [sessionId] and reports what the device
  /// really supports.
  ///
  /// [allowGlobalFallback] opts in to session id 0 (the global output mix).
  /// That path is deprecated since Android 10 and silently does nothing on many
  /// devices, so it is never the primary choice — the caller degrades the UI
  /// rather than pretending it worked.
  Future<EqCapabilities> attach(
    int sessionId, {
    bool allowGlobalFallback = false,
  }) async {
    final map = await _invoke<Map<Object?, Object?>>('attach', {
      'sessionId': sessionId,
      'allowGlobalFallback': allowGlobalFallback,
    });
    if (map == null) {
      return const EqCapabilities.unsupported(reason: 'no_platform');
    }
    return EqCapabilities.fromMap(map);
  }

  Future<void> release(int sessionId) =>
      _invoke<bool>('release', {'sessionId': sessionId});

  Future<void> releaseAll() => _invoke<bool>('releaseAll');

  Future<void> setEnabled(int sessionId, bool enabled) =>
      _invoke<bool>('setEnabled', {
        'sessionId': sessionId,
        'enabled': enabled,
      });

  Future<void> setBandLevels(int sessionId, List<int> levelsMb) =>
      _invoke<bool>('setBandLevels', {
        'sessionId': sessionId,
        'levelsMb': levelsMb,
      });

  Future<void> setBandLevel(int sessionId, int band, int levelMb) =>
      _invoke<bool>('setBandLevel', {
        'sessionId': sessionId,
        'band': band,
        'levelMb': levelMb,
      });

  Future<void> setBassBoost(int sessionId, int strength) =>
      _invoke<bool>('setBassBoost', {
        'sessionId': sessionId,
        'strength': strength,
      });

  Future<void> setVirtualizer(int sessionId, int strength) =>
      _invoke<bool>('setVirtualizer', {
        'sessionId': sessionId,
        'strength': strength,
      });

  Future<void> setReverb(int sessionId, ReverbPreset preset) =>
      _invoke<bool>('setReverb', {
        'sessionId': sessionId,
        'preset': preset.platformValue,
      });

  Future<void> setLoudness(int sessionId, int gainMb) =>
      _invoke<bool>('setLoudness', {
        'sessionId': sessionId,
        'gainMb': gainMb,
      });

  /// Requires RECORD_AUDIO — the caller must have it granted before enabling.
  Future<void> setVisualizerEnabled(int sessionId, bool enabled) =>
      _invoke<bool>('setVisualizerEnabled', {
        'sessionId': sessionId,
        'enabled': enabled,
      });

  Future<OutputDevice> currentOutputDevice() async {
    final raw = await _invoke<String>('getOutputDevice');
    return OutputDeviceX.parse(raw);
  }

  Stream<SpectrumFrame>? _visualizerStream;

  /// ~20 fps FFT frames. Broadcast, so the painter and the Auto-EQ engine can
  /// both listen without opening two native captures.
  Stream<SpectrumFrame> get visualizerStream {
    if (!isSupportedPlatform) return const Stream<SpectrumFrame>.empty();
    return _visualizerStream ??= _visualizer
        .receiveBroadcastStream()
        .map((e) => SpectrumFrame.fromMap(e as Map<Object?, Object?>))
        .handleError((Object e) => debugPrint('[eq] visualizer stream: $e'))
        .asBroadcastStream();
  }

  Stream<OutputDevice>? _deviceStream;

  /// Emits on headphone plug/unplug and Bluetooth connect/disconnect.
  Stream<OutputDevice> get outputDeviceStream {
    if (!isSupportedPlatform) return const Stream<OutputDevice>.empty();
    return _deviceStream ??= _device
        .receiveBroadcastStream()
        .map((e) => OutputDeviceX.parse(e as String?))
        .handleError((Object e) => debugPrint('[eq] device stream: $e'))
        .asBroadcastStream();
  }
}
