import 'package:flutter/foundation.dart';

import '../domain/eq_models.dart';
import 'audio_effects_platform.dart';
import 'eq_backend.dart';

/// `android.media.audiofx` bound to one audio session id.
///
/// This is the good path: the effects run in the audio HAL, cost almost no CPU,
/// and keep working while the screen is off and playback is in the background.
class NativeEffectsBackend implements EqBackend {
  NativeEffectsBackend._(this.sessionId, this._capabilities);

  /// Attaches to [sessionId]. Returns null when the device refuses — the caller
  /// then falls back to another backend rather than showing a broken EQ.
  ///
  /// [allowGlobalFallback] permits session id 0 (the global output mix). It is
  /// deprecated since Android 10 and a silent no-op on many devices, so it is
  /// only ever a last resort and never the primary target.
  static Future<NativeEffectsBackend?> attach(
    int sessionId, {
    bool allowGlobalFallback = false,
  }) async {
    final caps = await AudioEffectsPlatform.instance
        .attach(sessionId, allowGlobalFallback: allowGlobalFallback);
    if (!caps.attached) {
      debugPrint('[eq] native attach refused: ${caps.reason}');
      return null;
    }
    return NativeEffectsBackend._(sessionId, caps);
  }

  final int sessionId;
  final EqCapabilities _capabilities;

  final AudioEffectsPlatform _platform = AudioEffectsPlatform.instance;

  /// Last values written, so dragging a slider does not spam the channel with
  /// the four effect writes that did not change.
  EqSettings? _last;
  bool _disposed = false;

  @override
  EqCapabilities get capabilities => _capabilities;

  @override
  bool get supportsVisualizer => true;

  @override
  String get engineLabelKey => _capabilities.isGlobalSession
      ? 'eq_engine_system_global'
      : 'eq_engine_system';

  @override
  Future<void> apply(EqSettings settings) => _write(settings, force: false);

  @override
  Future<void> reapply(EqSettings settings) => _write(settings, force: true);

  Future<void> _write(EqSettings s, {required bool force}) async {
    if (_disposed) return;
    final prev = force ? null : _last;

    // Master switch first: turning effects on before writing levels avoids the
    // brief window where old levels are audible at the new enabled state.
    if (prev == null || prev.enabled != s.enabled) {
      await _platform.setEnabled(sessionId, s.enabled);
    }

    if (!s.enabled) {
      _last = s;
      return;
    }

    if (_capabilities.hasEqualizer &&
        (prev == null || !listEquals(prev.gainsDb, s.gainsDb))) {
      await _platform.setBandLevels(sessionId, s.toDeviceLevelsMb(_capabilities));
    }

    if (_capabilities.hasBassBoost &&
        (prev == null || prev.bassBoost != s.bassBoost)) {
      await _platform.setBassBoost(sessionId, s.bassBoost);
    }

    if (_capabilities.hasVirtualizer &&
        (prev == null || prev.virtualizer != s.virtualizer)) {
      await _platform.setVirtualizer(sessionId, s.virtualizer);
    }

    if (_capabilities.hasReverb && (prev == null || prev.reverb != s.reverb)) {
      await _platform.setReverb(sessionId, s.reverb);
    }

    if (_capabilities.hasLoudness) {
      // Night mode IS dynamic-range control, and LoudnessEnhancer is AOSP's
      // DRC + makeup gain — so it doubles as the night-mode engine here. The
      // floor keeps quiet dialogue audible even if the user left the slider
      // at zero.
      final target = s.nightMode ? (s.loudnessMb < 500 ? 500 : s.loudnessMb) : s.loudnessMb;
      final prevTarget = prev == null
          ? null
          : (prev.nightMode
              ? (prev.loudnessMb < 500 ? 500 : prev.loudnessMb)
              : prev.loudnessMb);
      if (prevTarget != target) {
        await _platform.setLoudness(sessionId, target);
      }
    }

    _last = s;
  }

  /// Starts/stops the FFT capture. Caller must already hold RECORD_AUDIO.
  Future<void> setVisualizerEnabled(bool enabled) =>
      _platform.setVisualizerEnabled(sessionId, enabled);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    // Release, do not merely disable: a live AudioEffect held on a dead session
    // is what makes the NEXT attach fail with "effect creation failed".
    await _platform.setVisualizerEnabled(sessionId, false);
    await _platform.release(sessionId);
  }
}
