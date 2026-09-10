import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:media_kit/media_kit.dart' as mk;
import 'package:permission_handler/permission_handler.dart';

import 'data/audio_effects_platform.dart';
import 'data/eq_backend.dart';
import 'data/eq_repository.dart';
import 'data/mpv_filter_backend.dart';
import 'data/native_effects_backend.dart';
import 'domain/eq_models.dart';
import 'domain/eq_presets.dart';
import 'domain/eq_profile.dart';
import 'domain/genre_classifier.dart';

/// The single audio-effects engine, shared by the video player and the music
/// player.
///
/// There is ONE service, ONE settings model, ONE profile store and ONE UI.
/// What differs per player is only how the settings reach the audio:
///
///  * **Music** — `just_audio` exposes ExoPlayer's `androidAudioSessionId`, so
///    effects attach to that session through `android.media.audiofx`. Real
///    hardware effects, near-zero CPU, and a `Visualizer` for the spectrum.
///
///  * **Video** — this app plays video through media_kit/libmpv, not ExoPlayer.
///    media_kit pins mpv's audio output to `ao=opensles`, which has no audio
///    session id to attach to, so audiofx is not reachable there. Video
///    therefore runs the same [EqSettings] through mpv's own `af` filter chain.
///    See [MpvFilterBackend] for the details and for the session-id upgrade
///    path if media_kit ever exposes an AudioTrack output.
///
/// Both players keep their own persisted settings ([MediaType]) and their own
/// backend instance, so background music does not lose its EQ when the user
/// opens a video.
class AudioEffectsService extends ChangeNotifier {
  AudioEffectsService._();

  static final AudioEffectsService instance = AudioEffectsService._();

  final EqRepository _repo = EqRepository.instance;
  final AudioEffectsPlatform _platform = AudioEffectsPlatform.instance;

  // ── state ────────────────────────────────────────────────────────────────

  final Map<MediaType, EqBackend> _backends = {};
  final Map<MediaType, EqSettings> _settings = {};

  /// Extra loudness applied for a quiet codec (AC3 / E-AC3). Kept OUT of
  /// [_settings] so it never gets saved into a user profile — it belongs to the
  /// current track, not to the user's taste.
  final Map<MediaType, int> _codecCompensationMb = {};

  MediaType _active = MediaType.music;
  List<EqProfile> _profiles = const [];
  OutputDevice _outputDevice = OutputDevice.speaker;
  EqBandMode _bandMode = EqBandMode.ten;

  bool _autoEqEnabled = false;
  bool _visualizerEnabled = false;
  bool _hasAudioPermission = false;
  bool _initialised = false;

  /// Set when the device refuses to give us any effects at all, so the UI can
  /// explain instead of silently doing nothing.
  String? _unsupportedReason;

  EqSuggestion? _suggestion;
  String? _dismissedSuggestionId;
  String? _genreTag;

  final AutoEqEngine _autoEq = AutoEqEngine();

  /// 20 fps spectrum frames. Deliberately NOT part of [notifyListeners] — a
  /// full rebuild of the equalizer page twenty times a second would drop
  /// frames. Only the visualizer painter listens to this.
  final ValueNotifier<SpectrumFrame> spectrum =
      ValueNotifier<SpectrumFrame>(SpectrumFrame.silent);

  StreamSubscription<int?>? _musicSessionSub;
  StreamSubscription<SpectrumFrame>? _spectrumSub;
  StreamSubscription<OutputDevice>? _deviceSub;
  Timer? _autoEqTimer;

  // ── getters ──────────────────────────────────────────────────────────────

  MediaType get activeMediaType => _active;

  EqSettings get settings => _settings[_active] ?? const EqSettings();

  EqSettings settingsFor(MediaType type) =>
      _settings[type] ?? const EqSettings();

  EqBackend? get _backend => _backends[_active];

  EqCapabilities get capabilities =>
      _backend?.capabilities ?? const EqCapabilities.unsupported();

  /// False when nothing could be attached for the active player.
  bool get isAvailable => _backend != null && capabilities.attached;

  String? get unsupportedReason => _unsupportedReason;

  /// True only when the DEVICE refused to give us effects at all.
  ///
  /// Distinct from [isAvailable], which is also false in the ordinary case of
  /// "nothing is playing yet". That distinction matters: the master switch and
  /// the curve are stored preferences, so they must stay editable from Settings
  /// before playback starts — they are pushed to the audio the moment a player
  /// binds. Only a genuinely unsupported device disables the controls.
  bool get isDeviceUnsupported => _unsupportedReason == 'device';

  String get engineLabelKey =>
      _backend?.engineLabelKey ?? 'eq_engine_unavailable';

  List<EqProfile> get profiles => List.unmodifiable(_profiles);

  String? get defaultProfileId => _repo.defaultProfileId;

  OutputDevice get outputDevice => _outputDevice;

  EqBandMode get bandMode => _bandMode;

  bool get autoEqEnabled => _autoEqEnabled;

  bool get visualizerEnabled => _visualizerEnabled;

  bool get hasAudioPermission => _hasAudioPermission;

  /// Whether an FFT stream can be shown/used for the active player.
  bool get supportsVisualizer => _backend?.supportsVisualizer ?? false;

  /// Non-null only when confidence is high enough and the user has not
  /// dismissed this exact suggestion for this track.
  EqSuggestion? get suggestion {
    final s = _suggestion;
    if (s == null) return null;
    if (s.confidence < AutoEqEngine.minConfidence) return null;
    if (s.presetId == _dismissedSuggestionId) return null;
    if (s.presetId == settings.presetId) return null;
    return s;
  }

  /// Gains at the frequencies the current UI mode displays.
  List<double> get viewGains => EqGrid.viewGains(settings.gainsDb, _bandMode);

  List<double> get viewFrequencies => EqGrid.hzFor(_bandMode);

  // ── lifecycle ────────────────────────────────────────────────────────────

  /// Loads persisted state. Safe to call repeatedly; cheap after the first run.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    await _repo.init();
    _settings[MediaType.music] = _repo.loadSettings(MediaType.music);
    _settings[MediaType.video] = _repo.loadSettings(MediaType.video);
    _profiles = _repo.loadProfiles();
    _bandMode = _repo.bandMode;
    _autoEqEnabled = _repo.autoEqEnabled;
    _visualizerEnabled = _repo.visualizerEnabled;

    // Read the permission WITHOUT prompting — a toggle the user turned on in a
    // previous session must come back on, but start-up is the wrong moment to
    // ask for the microphone.
    if (_platform.isSupportedPlatform) {
      try {
        _hasAudioPermission = await Permission.microphone.isGranted;
      } catch (_) {
        _hasAudioPermission = false;
      }
    }

    _outputDevice = await _platform.currentOutputDevice();
    _deviceSub ??= _platform.outputDeviceStream.listen(_onOutputDeviceChanged);

    notifyListeners();
  }

  // ── player binding ───────────────────────────────────────────────────────

  /// Attaches the music engine to `just_audio`.
  ///
  /// The session id changes whenever ExoPlayer rebuilds its audio sink — a new
  /// track, a sample-rate change, an offload transition. Every one of those has
  /// to tear the old effects down and re-attach, or the EQ silently stops
  /// applying partway through a playlist.
  Future<void> bindMusicPlayer(ja.AudioPlayer player) async {
    await init();
    await _musicSessionSub?.cancel();

    Future<void> handle(int? id) async {
      await _attachMusicSession(id);
    }

    _musicSessionSub = player.androidAudioSessionIdStream.listen(
      handle,
      onError: (Object e) => debugPrint('[eq] session id stream: $e'),
    );

    await handle(player.androidAudioSessionId);
  }

  Future<void> _attachMusicSession(int? sessionId) async {
    final existing = _backends[MediaType.music];
    if (existing is NativeEffectsBackend && existing.sessionId == sessionId) {
      // Same session — just make sure the current curve is live again.
      await existing.reapply(_effective(MediaType.music));
      return;
    }

    await _disposeBackend(MediaType.music);

    if (sessionId == null || sessionId == 0) {
      // No session yet. This is normal before the first track loads; we simply
      // wait for the stream to report a real one rather than falling back to
      // the deprecated global output mix.
      notifyListeners();
      return;
    }

    final backend = await NativeEffectsBackend.attach(sessionId);
    if (backend == null) {
      _unsupportedReason = 'device';
      notifyListeners();
      return;
    }

    _backends[MediaType.music] = backend;
    _unsupportedReason = null;
    await backend.reapply(_effective(MediaType.music));
    await _syncVisualizer();
    notifyListeners();
  }

  /// Attaches the video engine to a media_kit [mk.Player].
  ///
  /// Call this right after the Player is constructed and before `open()`, so
  /// the first frame of audio already carries the user's curve.
  Future<void> bindVideoPlayer(mk.Player player, {String? genreTag}) async {
    await init();
    await _disposeBackend(MediaType.video);

    _genreTag = genreTag;

    final native = player.platform;
    if (native is! mk.NativePlayer) {
      _backends[MediaType.video] = const NullEqBackend(reason: 'no_platform');
      notifyListeners();
      return;
    }

    final backend = MpvFilterBackend(player);
    _backends[MediaType.video] = backend;
    _unsupportedReason = null;
    await backend.reapply(_effective(MediaType.video));
    notifyListeners();
  }

  /// Lets the video player contribute its own mpv audio filters (its
  /// volume-boost limiter).
  ///
  /// mpv has ONE `af` property. Before this existed, the limiter and the
  /// equalizer each wrote it directly, so whichever ran last silently erased
  /// the other. Everything that wants a filter now goes through here and the
  /// backend composes a single chain.
  Future<void> setVideoExtraFilters(List<String> filters) async {
    final backend = _backends[MediaType.video];
    if (backend is MpvFilterBackend) {
      await backend.setExtraFilters(filters);
    }
  }

  /// Re-pushes the whole chain. Call on a new track/video, on audio-focus
  /// regain, and after a headphone plug — the cheapest way to be certain the
  /// effects survived whatever the platform just did to the audio sink.
  Future<void> reapply([MediaType? type]) async {
    final target = type ?? _active;
    final backend = _backends[target];
    if (backend == null) return;
    _autoEq.reset();
    _suggestion = null;
    _dismissedSuggestionId = null;
    await backend.reapply(_effective(target));
    notifyListeners();
  }

  /// Detaches one player. Always call this from the player's `dispose()`.
  Future<void> unbind(MediaType type) async {
    if (type == MediaType.music) {
      await _musicSessionSub?.cancel();
      _musicSessionSub = null;
    }
    await _disposeBackend(type);
    if (_active == type) {
      _autoEq.reset();
      _suggestion = null;
      spectrum.value = SpectrumFrame.silent;
    }
    notifyListeners();
  }

  Future<void> _disposeBackend(MediaType type) async {
    final backend = _backends.remove(type);
    if (backend == null) return;
    if (backend is NativeEffectsBackend) {
      await backend.setVisualizerEnabled(false);
    }
    await backend.dispose();
  }

  /// Which player the UI is currently editing.
  Future<void> setActiveMediaType(MediaType type) async {
    if (_active == type) return;
    _active = type;
    _autoEq.reset();
    _suggestion = null;
    _dismissedSuggestionId = null;
    spectrum.value = SpectrumFrame.silent;
    await _syncVisualizer();
    notifyListeners();
  }

  // ── settings mutation ────────────────────────────────────────────────────

  Future<void> _update(
    EqSettings next, {
    bool persist = true,
    MediaType? type,
  }) async {
    final target = type ?? _active;
    _settings[target] = next;
    notifyListeners();

    // Push to the audio first; persistence can lag a frame without anyone
    // noticing, an unresponsive slider cannot.
    await _backends[target]?.apply(_effective(target));
    if (persist) await _repo.saveSettings(target, next);
  }

  /// Master ON/OFF.
  Future<void> setEnabled(bool enabled) =>
      _update(settings.copyWith(enabled: enabled));

  /// Moves one slider in the CURRENT band mode. In 5-band mode the edit is
  /// spread across the neighbouring canonical bands (see [EqGrid.applyViewGain])
  /// so the curve stays smooth instead of growing spikes.
  Future<void> setBandGain(int viewIndex, double db) {
    final gains = EqGrid.applyViewGain(settings.gainsDb, _bandMode, viewIndex, db);
    return _update(settings.copyWith(
      gainsDb: gains,
      presetId: EqSettings.customId,
    ));
  }

  Future<void> setBandMode(EqBandMode mode) async {
    if (_bandMode == mode) return;
    _bandMode = mode;
    await _repo.setBandMode(mode);
    notifyListeners();
  }

  Future<void> applyPreset(EqPreset preset) {
    if (preset.id == EqSettings.customId) return Future.value();
    _dismissedSuggestionId = null;
    return _update(preset.applyTo(settings));
  }

  Future<void> setBassBoost(int strength) => _update(settings.copyWith(
        bassBoost: strength.clamp(0, 1000),
        presetId: EqSettings.customId,
      ));

  Future<void> setVirtualizer(int strength) => _update(settings.copyWith(
        virtualizer: strength.clamp(0, 1000),
        presetId: EqSettings.customId,
      ));

  Future<void> setReverb(ReverbPreset preset) =>
      _update(settings.copyWith(reverb: preset, presetId: EqSettings.customId));

  Future<void> setLoudness(int gainMb) => _update(settings.copyWith(
        loudnessMb: gainMb.clamp(0, 2000),
        presetId: EqSettings.customId,
      ));

  Future<void> setBalance(double balance) =>
      _update(settings.copyWith(balance: balance.clamp(-1.0, 1.0)));

  Future<void> setMono(bool mono) => _update(settings.copyWith(mono: mono));

  Future<void> setDialogueDownmix(bool value) => _update(
      settings.copyWith(dialogueDownmix: value, presetId: EqSettings.customId));

  Future<void> setNightMode(bool value) => _update(
      settings.copyWith(nightMode: value, presetId: EqSettings.customId));

  /// Back to flat, keeping the master switch where the user left it.
  Future<void> reset() => _update(EqSettings(
        enabled: settings.enabled,
        gainsDb: EqGrid.flat,
        presetId: EqPresets.normal.id,
      ));

  // ── codec compensation ───────────────────────────────────────────────────

  /// AC3 / E-AC3 tracks are mastered around 10 dB quieter than stereo AAC, so
  /// they sound broken next to everything else. Call this when a track's audio
  /// codec becomes known; passing null clears the compensation.
  Future<void> applyCodecHint(String? codec, {MediaType? type}) async {
    final target = type ?? _active;
    final normalised = codec?.toLowerCase() ?? '';
    final isDolby = _repo.codecCompensation &&
        (normalised.contains('eac3') ||
            normalised.contains('e-ac-3') ||
            normalised.contains('ac3') ||
            normalised.contains('ac-3'));

    final gain = isDolby ? 600 : 0;
    if (_codecCompensationMb[target] == gain) return;
    _codecCompensationMb[target] = gain;
    await _backends[target]?.reapply(_effective(target));
    notifyListeners();
  }

  /// True when the current track is getting the Dolby loudness bump, so the UI
  /// can say so rather than leaving the user wondering why it is louder.
  bool get codecCompensationActive =>
      (_codecCompensationMb[_active] ?? 0) > 0 && settings.enabled;

  /// What actually reaches the backend: the user's settings plus the current
  /// track's codec compensation.
  EqSettings _effective(MediaType type) {
    final base = _settings[type] ?? const EqSettings();
    final bump = _codecCompensationMb[type] ?? 0;
    if (bump == 0 || !base.enabled) return base;
    return base.copyWith(
      loudnessMb: (base.loudnessMb + bump).clamp(0, 2000),
    );
  }

  // ── profiles ─────────────────────────────────────────────────────────────

  Future<EqProfile> saveProfile(String name) async {
    final trimmed = name.trim().isEmpty ? 'Profile' : name.trim();
    final now = DateTime.now();
    final profile = EqProfile(
      id: EqProfile.newId(),
      name: trimmed,
      settings: settings,
      createdAt: now,
      updatedAt: now,
    );
    _profiles = [profile, ..._profiles];
    await _repo.saveProfiles(_profiles);
    // The saved profile is now the active identity, so the carousel stops
    // showing "Custom" for a curve the user has just named.
    await _update(settings.copyWith(presetId: profile.id), persist: true);
    return profile;
  }

  Future<void> applyProfile(EqProfile profile) =>
      _update(profile.settings.copyWith(
        enabled: settings.enabled,
        presetId: profile.id,
      ));

  Future<void> renameProfile(EqProfile profile, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _profiles = _profiles
        .map((p) => p.id == profile.id ? p.copyWith(name: trimmed) : p)
        .toList();
    await _repo.saveProfiles(_profiles);
    notifyListeners();
  }

  /// Overwrites a profile with what is on screen right now.
  Future<void> updateProfile(EqProfile profile) async {
    _profiles = _profiles
        .map((p) => p.id == profile.id ? p.copyWith(settings: settings) : p)
        .toList();
    await _repo.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<EqProfile> duplicateProfile(EqProfile profile) async {
    final now = DateTime.now();
    final copy = EqProfile(
      id: EqProfile.newId(),
      name: '${profile.name} copy',
      settings: profile.settings,
      createdAt: now,
      updatedAt: now,
    );
    _profiles = [copy, ..._profiles];
    await _repo.saveProfiles(_profiles);
    notifyListeners();
    return copy;
  }

  Future<void> deleteProfile(EqProfile profile) async {
    _profiles = _profiles.where((p) => p.id != profile.id).toList();
    await _repo.saveProfiles(_profiles);

    if (_repo.defaultProfileId == profile.id) {
      await _repo.setDefaultProfileId(null);
    }
    // Drop every output-route binding that pointed at it, otherwise plugging in
    // headphones would try to apply a profile that no longer exists.
    for (final type in MediaType.values) {
      final bindings = _repo.loadDeviceBindings(type);
      if (bindings.containsValue(profile.id)) {
        bindings.removeWhere((_, id) => id == profile.id);
        await _repo.saveDeviceBindings(type, bindings);
      }
    }
    notifyListeners();
  }

  Future<void> setDefaultProfile(EqProfile? profile) async {
    await _repo.setDefaultProfileId(profile?.id);
    notifyListeners();
  }

  /// Import a profile shared as JSON. Returns null when the text is not a
  /// Vidnexa profile.
  Future<EqProfile?> importProfile(String raw) async {
    final parsed = EqProfile.tryParseShareString(raw);
    if (parsed == null) return null;
    _profiles = [parsed, ..._profiles];
    await _repo.saveProfiles(_profiles);
    notifyListeners();
    return parsed;
  }

  String exportProfile(EqProfile profile) => profile.toShareString();

  // ── output-device auto-switch ────────────────────────────────────────────

  Map<OutputDevice, String> deviceBindings([MediaType? type]) =>
      _repo.loadDeviceBindings(type ?? _active);

  /// Binds a profile to an output route for the active player. Passing null
  /// clears the binding.
  Future<void> bindProfileToDevice(OutputDevice device, String? profileId) async {
    final bindings = Map<OutputDevice, String>.from(deviceBindings());
    if (profileId == null) {
      bindings.remove(device);
    } else {
      bindings[device] = profileId;
    }
    await _repo.saveDeviceBindings(_active, bindings);
    notifyListeners();

    if (device == _outputDevice) await _applyDeviceProfile();
  }

  Future<void> _onOutputDeviceChanged(OutputDevice device) async {
    if (_outputDevice == device) return;
    _outputDevice = device;
    notifyListeners();

    // Routing changes rebuild the audio sink on some devices, which can drop
    // the effects — re-push before anything else.
    for (final type in _backends.keys.toList()) {
      await _backends[type]?.reapply(_effective(type));
    }
    await _applyDeviceProfile();
  }

  Future<void> _applyDeviceProfile() async {
    final id = deviceBindings()[_outputDevice];
    if (id == null) return;
    for (final p in _profiles) {
      if (p.id == id) {
        await applyProfile(p);
        return;
      }
    }
  }

  // ── visualizer + Auto EQ ─────────────────────────────────────────────────

  /// Turns the live spectrum on. Requires RECORD_AUDIO, which is asked for here
  /// and nowhere else — see [requestAudioPermission] for what the user is told.
  Future<bool> setVisualizerEnabled(bool enabled) async {
    if (enabled && !await requestAudioPermission()) return false;
    _visualizerEnabled = enabled;
    await _repo.setVisualizerEnabled(enabled);
    await _syncVisualizer();
    notifyListeners();
    return true;
  }

  /// Auto-EQ needs the same capture as the visualizer, so it implies it.
  Future<bool> setAutoEqEnabled(bool enabled) async {
    if (enabled && !await requestAudioPermission()) return false;
    _autoEqEnabled = enabled;
    await _repo.setAutoEqEnabled(enabled);
    if (!enabled) {
      _suggestion = null;
      _autoEq.reset();
    }
    await _syncVisualizer();
    notifyListeners();
    return true;
  }

  /// `android.media.audiofx.Visualizer` is gated behind RECORD_AUDIO even
  /// though it only reads this app's OWN output mix — nothing from the
  /// microphone is captured. The UI must say so before this is called.
  Future<bool> requestAudioPermission() async {
    if (!_platform.isSupportedPlatform) return false;
    try {
      var status = await Permission.microphone.status;
      if (status.isGranted) {
        _hasAudioPermission = true;
        return true;
      }
      if (status.isPermanentlyDenied) {
        _hasAudioPermission = false;
        return false;
      }
      status = await Permission.microphone.request();
      _hasAudioPermission = status.isGranted;
      return _hasAudioPermission;
    } catch (e) {
      debugPrint('[eq] permission request failed: $e');
      return false;
    }
  }

  /// Starts or stops the native capture to match the current toggles.
  Future<void> _syncVisualizer() async {
    final backend = _backend;
    final wanted = (_visualizerEnabled || _autoEqEnabled) &&
        _hasAudioPermission &&
        backend is NativeEffectsBackend;

    // Stop any capture on the players that should not have one.
    for (final entry in _backends.entries) {
      final b = entry.value;
      if (b is! NativeEffectsBackend) continue;
      final on = wanted && identical(b, backend);
      await b.setVisualizerEnabled(on);
    }

    if (!wanted) {
      await _spectrumSub?.cancel();
      _spectrumSub = null;
      _autoEqTimer?.cancel();
      _autoEqTimer = null;
      spectrum.value = SpectrumFrame.silent;
      return;
    }

    _spectrumSub ??= _platform.visualizerStream.listen((frame) {
      spectrum.value = frame;
      if (_autoEqEnabled || _visualizerEnabled) _autoEq.add(frame);
    });

    // Evaluated on a timer, not per frame: the rolling window only moves
    // meaningfully every second or two, and classifying 20 times a second
    // would just burn battery.
    _autoEqTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _evaluateAutoEq(),
    );
  }

  void _evaluateAutoEq() {
    final next = _autoEq.evaluate(mediaType: _active, genreTag: _genreTag);
    if (next == null) return;
    if (next.presetId == _suggestion?.presetId) return;

    _suggestion = next;

    // Auto-apply ONLY with the toggle on. Otherwise the chip waits for the user.
    if (_autoEqEnabled && next.confidence >= AutoEqEngine.minConfidence) {
      final preset = next.preset;
      if (preset != null && preset.id != settings.presetId) {
        unawaited(applyPreset(preset));
      }
    }
    notifyListeners();
  }

  Future<void> applySuggestion() async {
    final preset = suggestion?.preset;
    if (preset == null) return;
    await applyPreset(preset);
  }

  void dismissSuggestion() {
    _dismissedSuggestionId = _suggestion?.presetId;
    notifyListeners();
  }

  /// Metadata genre for the current track, used as a classifier fallback.
  void setGenreTag(String? genre) {
    if (_genreTag == genre) return;
    _genreTag = genre;
  }

  // ── teardown ─────────────────────────────────────────────────────────────

  @override
  Future<void> dispose() async {
    await _musicSessionSub?.cancel();
    await _spectrumSub?.cancel();
    await _deviceSub?.cancel();
    _autoEqTimer?.cancel();
    for (final type in _backends.keys.toList()) {
      await _disposeBackend(type);
    }
    await _platform.releaseAll();
    spectrum.dispose();
    super.dispose();
  }
}
