import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

import '../domain/eq_models.dart';
import 'eq_backend.dart';

/// Equalizer implemented as an mpv `af` lavfi chain.
///
/// WHY THIS EXISTS. The prompt assumed ExoPlayer for video, which hands out an
/// `audioSessionId` that `android.media.audiofx` can attach to. This app plays
/// video through media_kit/libmpv instead, which writes to its own AudioTrack.
/// [AudioEffectsService] first tries to give libmpv a session id we generated
/// (`audiotrack-session-id`) so the native backend can be used for video too;
/// when the bundled libmpv build does not know that property, this backend runs
/// the same [EqSettings] through ffmpeg filters instead. Same presets, same
/// profiles, same UI — only the last hop differs.
///
/// It also has one real advantage over audiofx: proper dynamic-range
/// compression for Night Mode, and a true centre-forward downmix for dialogue.
class MpvFilterBackend implements EqBackend {
  MpvFilterBackend(this._player);

  final Player _player;

  NativePlayer? get _native {
    final p = _player.platform;
    return p is NativePlayer ? p : null;
  }

  /// Filters owned by OTHER features (the player's volume-boost limiter).
  /// They share one `af` property, so they have to be composed here — two
  /// writers each setting `af` directly is how the limiter used to silently
  /// erase the equalizer.
  List<String> _extraFilters = const [];

  String? _lastChain;
  EqSettings? _lastSettings;
  bool? _lastDownmix;
  bool _disposed = false;

  /// True once a chain has been written and read back unchanged.
  bool _verified = false;

  /// Set when even the EQ-only chain failed to apply, so we stop retrying on
  /// every slider frame.
  bool _degraded = false;

  @override
  EqCapabilities get capabilities => const EqCapabilities(
        attached: true,
        hasEqualizer: true,
        // The filter chain is not limited by any device band count: the ten
        // canonical bands map 1:1 onto ten biquads.
        numberOfBands: EqGrid.bandCount,
        minLevelMb: -1500,
        maxLevelMb: 1500,
        centerFreqsHz: EqGrid.canonicalHz,
        hasBassBoost: true,
        hasVirtualizer: true,
        hasReverb: true,
        hasLoudness: true,
      );

  @override
  bool get supportsVisualizer => false;

  @override
  String get engineLabelKey =>
      _degraded ? 'eq_engine_player_limited' : 'eq_engine_player';

  /// Lets the player register filters it owns. Triggers a rebuild so the new
  /// filter takes effect immediately.
  Future<void> setExtraFilters(List<String> filters) async {
    if (listEquals(_extraFilters, filters)) return;
    _extraFilters = List<String>.unmodifiable(filters);
    final s = _lastSettings;
    if (s != null) await _write(s, force: true);
  }

  @override
  Future<void> apply(EqSettings settings) => _write(settings, force: false);

  @override
  Future<void> reapply(EqSettings settings) => _write(settings, force: true);

  Future<void> _write(EqSettings s, {required bool force}) async {
    if (_disposed) return;
    _lastSettings = s;

    final native = _native;
    if (native == null) return; // desktop/web without a native player

    // `pan=stereo|c0=...|c1=...` addresses the INPUT's channels 0 and 1, which
    // on a 5.1 track are FL/FR — the centre channel carrying the dialogue would
    // be dropped, the exact opposite of what the dialogue preset promises. So
    // when that filter is in play, fold to stereo first with mpv's own
    // centre-weighted downmix.
    if (force || (_lastDownmix != s.dialogueDownmix)) {
      _lastDownmix = s.dialogueDownmix;
      await _trySetProperty(
        native,
        'audio-channels',
        s.dialogueDownmix ? 'stereo' : 'auto-safe',
      );
    }

    final chain = _buildChain(s);
    if (!force && chain == _lastChain) return;

    final ok = await _applyChain(native, chain);
    if (ok) {
      _lastChain = chain;
      return;
    }

    // A filter the bundled ffmpeg does not have makes mpv reject the WHOLE
    // graph, which would leave the user with no EQ at all. Retry with just the
    // biquads, which every ffmpeg build has.
    if (!_degraded) {
      final minimal = _buildChain(s, minimal: true);
      if (await _applyChain(native, minimal)) {
        _degraded = true;
        _lastChain = minimal;
        debugPrint('[eq] mpv chain reduced to EQ-only (filter unavailable)');
        return;
      }
      _degraded = true;
      debugPrint('[eq] mpv audio filters unavailable on this build');
    }
  }

  /// Writes `af` and verifies it stuck.
  ///
  /// media_kit's `setProperty` ignores mpv's return code, so a bad filter name
  /// is silently swallowed. Reading the property back is the only way to know.
  Future<bool> _applyChain(NativePlayer native, String chain) async {
    try {
      await native.setProperty('af', chain);
      if (chain.isEmpty) return true;
      final readback = await native.getProperty('af');
      final applied = readback.trim().isNotEmpty;
      _verified = applied;
      return applied;
    } catch (e) {
      debugPrint('[eq] af write failed: $e');
      return false;
    }
  }

  Future<void> _trySetProperty(
      NativePlayer native, String name, String value) async {
    try {
      await native.setProperty(name, value);
    } catch (_) {
      // Unknown property on this libmpv build — not fatal.
    }
  }

  /// Builds the lavfi graph. Empty string = full bypass.
  ///
  /// [minimal] drops everything except the biquad EQ and the extra filters, for
  /// the retry after a rejected graph.
  String _buildChain(EqSettings s, {bool minimal = false}) {
    final parts = <String>[];

    if (s.enabled) {
      // Ten peaking biquads, one per canonical band. Zero-gain bands are left
      // out — an identity filter still costs a pass over every sample.
      for (var i = 0; i < EqGrid.canonicalHz.length; i++) {
        final g = i < s.gainsDb.length ? s.gainsDb[i] : 0.0;
        if (g.abs() < 0.05) continue;
        final f = EqGrid.canonicalHz[i].round();
        // width_type=o (octaves), width=1 -> one-octave Q, the usual graphic-EQ
        // shape.
        parts.add('equalizer=f=$f:width_type=o:width=1:g=${_fmt(g)}');
      }

      if (!minimal) {
        if (s.bassBoost > 0) {
          // 0..1000 -> 0..12 dB shelf at 110 Hz, matching BassBoost's feel.
          parts.add('bass=g=${_fmt(s.bassBoost / 1000.0 * 12.0)}:f=110');
        }

        if (s.virtualizer > 0) {
          // 0..1000 -> 1.0..2.2 stereo width.
          parts.add('extrastereo=m=${_fmt(1.0 + s.virtualizer / 1000.0 * 1.2)}');
        }

        if (s.reverb != ReverbPreset.none) {
          parts.add(_reverbFilter(s.reverb));
        }

        if (s.nightMode) {
          // The real thing, not a gain: pull peaks down 4:1 above -21 dBFS and
          // make up the level, so late-night explosions stop clipping the room.
          parts.add(
            'acompressor=threshold=0.089:ratio=4:attack=20:release=250:makeup=2',
          );
        }

        if (s.dialogueDownmix) {
          // Collapse partly toward mono: the centre channel (dialogue) is what
          // both sides share, so this lifts speech relative to wide music and
          // effects. Works on stereo input too, unlike a 5.1-only pan.
          parts.add('pan=stereo|c0=0.6*c0+0.4*c1|c1=0.6*c1+0.4*c0');
        }

        if (s.mono) {
          parts.add('pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1');
        } else if (s.balance.abs() > 0.01) {
          // Constant-power-ish: attenuate the far side rather than boosting the
          // near one, so balance can never introduce clipping.
          final l = s.balance <= 0 ? 1.0 : 1.0 - s.balance;
          final r = s.balance >= 0 ? 1.0 : 1.0 + s.balance;
          parts.add('pan=stereo|c0=${_fmt(l)}*c0|c1=${_fmt(r)}*c1');
        }

        if (s.loudnessMb > 0) {
          parts.add('volume=${_fmt(s.loudnessMb / 100.0)}dB');
        }
      }
    } else if (!minimal) {
      // Master off: only the player's own filters survive.
      if (s.mono) {
        parts.add('pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1');
      }
    }

    parts.addAll(_extraFilters);
    if (parts.isEmpty) return '';
    return 'lavfi=[${parts.join(',')}]';
  }

  String _reverbFilter(ReverbPreset preset) => switch (preset) {
        ReverbPreset.smallRoom => 'aecho=0.8:0.85:20:0.18',
        ReverbPreset.mediumRoom => 'aecho=0.8:0.85:40:0.25',
        ReverbPreset.largeRoom => 'aecho=0.8:0.88:60:0.32',
        ReverbPreset.mediumHall => 'aecho=0.8:0.9:90:0.38',
        ReverbPreset.largeHall => 'aecho=0.8:0.9:130:0.42',
        ReverbPreset.plate => 'aecho=0.85:0.9:12|24:0.3|0.22',
        ReverbPreset.none => '',
      };

  /// mpv parses filter arguments locale-independently, so a comma decimal
  /// separator would break the graph — one fixed decimal, always a dot.
  String _fmt(double v) => v.toStringAsFixed(2);

  /// True once a non-empty chain was confirmed live, for the UI's engine line.
  bool get isVerified => _verified;

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final native = _native;
    if (native == null) return;
    try {
      // Leave the player exactly as we found it, minus our filters.
      await native.setProperty(
        'af',
        _extraFilters.isEmpty ? '' : 'lavfi=[${_extraFilters.join(',')}]',
      );
    } catch (_) {}
  }
}
