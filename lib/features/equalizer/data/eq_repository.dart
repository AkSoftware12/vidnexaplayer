import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/eq_models.dart';
import '../domain/eq_profile.dart';

/// Persistence for equalizer state, saved profiles and the auto-switch map.
///
/// Backed by Hive (already initialised in `main()`), with an in-memory fallback
/// so that a box that fails to open degrades to "settings do not survive a
/// restart" instead of taking the audio feature down with it.
class EqRepository {
  EqRepository._();

  static final EqRepository instance = EqRepository._();

  static const String _boxName = 'equalizer';

  Box? _box;
  final Map<String, dynamic> _memory = {};

  bool get isPersistent => _box != null;

  /// Safe to call more than once.
  Future<void> init() async {
    if (_box != null) return;
    try {
      _box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
    } catch (e) {
      debugPrint('[eq] Hive unavailable, using in-memory store: $e');
      _box = null;
    }
  }

  T? _read<T>(String key) {
    try {
      final v = _box?.get(key) ?? _memory[key];
      return v is T ? v : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String key, Object? value) async {
    _memory[key] = value;
    try {
      await _box?.put(key, value);
    } catch (e) {
      debugPrint('[eq] write $key failed: $e');
    }
  }

  // ── per-media-type settings ──────────────────────────────────────────────

  String _settingsKey(MediaType type) => 'settings_${type.name}';

  /// The last state the user left this player in. Video and music are stored
  /// separately, so a cinema curve does not follow them into their music.
  EqSettings loadSettings(MediaType type) {
    final raw = _read<Map>(_settingsKey(type));
    if (raw == null) return const EqSettings();
    try {
      return EqSettings.fromJson(raw);
    } catch (e) {
      debugPrint('[eq] corrupt settings for ${type.name}: $e');
      return const EqSettings();
    }
  }

  Future<void> saveSettings(MediaType type, EqSettings settings) =>
      _write(_settingsKey(type), settings.toJson());

  // ── profiles ─────────────────────────────────────────────────────────────

  static const String _profilesKey = 'profiles';

  List<EqProfile> loadProfiles() {
    final raw = _read<List>(_profilesKey);
    if (raw == null) return const [];
    final out = <EqProfile>[];
    for (final entry in raw) {
      // One corrupt entry must not lose the user's whole profile list.
      try {
        if (entry is Map) out.add(EqProfile.fromJson(entry));
      } catch (e) {
        debugPrint('[eq] skipping corrupt profile: $e');
      }
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }

  Future<void> saveProfiles(List<EqProfile> profiles) =>
      _write(_profilesKey, profiles.map((p) => p.toJson()).toList());

  // ── default profile ──────────────────────────────────────────────────────

  String? get defaultProfileId => _read<String>('default_profile');

  Future<void> setDefaultProfileId(String? id) =>
      _write('default_profile', id);

  // ── output-device auto-switch map ────────────────────────────────────────

  String _bindingKey(MediaType type) => 'device_bindings_${type.name}';

  /// output route -> profile id. Applied the moment that route becomes active.
  Map<OutputDevice, String> loadDeviceBindings(MediaType type) {
    final raw = _read<Map>(_bindingKey(type));
    if (raw == null) return const {};
    final out = <OutputDevice, String>{};
    raw.forEach((k, v) {
      if (v is! String) return;
      for (final device in OutputDevice.values) {
        if (device.name == k) {
          out[device] = v;
          break;
        }
      }
    });
    return out;
  }

  Future<void> saveDeviceBindings(
    MediaType type,
    Map<OutputDevice, String> bindings,
  ) =>
      _write(
        _bindingKey(type),
        bindings.map((k, v) => MapEntry(k.name, v)),
      );

  // ── preferences ──────────────────────────────────────────────────────────

  EqBandMode get bandMode =>
      _read<String>('band_mode') == EqBandMode.five.name
          ? EqBandMode.five
          : EqBandMode.ten;

  Future<void> setBandMode(EqBandMode mode) => _write('band_mode', mode.name);

  bool get autoEqEnabled => _read<bool>('auto_eq') ?? false;

  Future<void> setAutoEqEnabled(bool value) => _write('auto_eq', value);

  bool get visualizerEnabled => _read<bool>('visualizer') ?? false;

  Future<void> setVisualizerEnabled(bool value) => _write('visualizer', value);

  /// Auto-compensate the level of AC3 / E-AC3 tracks, which are mastered
  /// quieter than stereo AAC and otherwise sound broken next to it.
  bool get codecCompensation => _read<bool>('codec_compensation') ?? true;

  Future<void> setCodecCompensation(bool value) =>
      _write('codec_compensation', value);
}
