import '../domain/eq_models.dart';

/// How a set of [EqSettings] actually reaches the audio.
///
/// Two implementations exist because the two players are genuinely different
/// engines, NOT because there are two equalizers: the presets, the profiles,
/// the state and the whole UI are shared, and only this last hop differs.
///
///  * [NativeEffectsBackend] — `android.media.audiofx` on a real audio session
///    id. Used by the music player (just_audio exposes ExoPlayer's session id)
///    and by the video player whenever libmpv accepts the session id we hand it.
///  * [MpvFilterBackend] — an mpv `af` lavfi chain. The video fallback, and the
///    only option on devices whose libmpv build ignores `audiotrack-session-id`.
abstract class EqBackend {
  /// What this backend can do on this device, right now.
  EqCapabilities get capabilities;

  /// Whether an FFT stream is available. Only the native backend has one; the
  /// mpv chain has no Visualizer to attach to.
  bool get supportsVisualizer;

  /// Translation key for the UI's "engine" line, so a support ticket can
  /// say which path was in use.
  String get engineLabelKey;

  /// Pushes the full state. Implementations diff internally — this is called on
  /// every slider frame and must never restart playback.
  Future<void> apply(EqSettings settings);

  /// Re-pushes everything after a track change, an audio-focus regain, or a
  /// session id change, without assuming any cached state is still live.
  Future<void> reapply(EqSettings settings);

  Future<void> dispose();
}

/// Used when nothing can be attached — an unsupported device, a player with no
/// session, or a non-Android platform. Every call is a no-op, so the UI can
/// stay mounted and simply show its "not supported" state.
class NullEqBackend implements EqBackend {
  const NullEqBackend({this.reason});

  final String? reason;

  @override
  EqCapabilities get capabilities => EqCapabilities.unsupported(reason: reason);

  @override
  bool get supportsVisualizer => false;

  @override
  String get engineLabelKey => 'eq_engine_unavailable';

  @override
  Future<void> apply(EqSettings settings) async {}

  @override
  Future<void> reapply(EqSettings settings) async {}

  @override
  Future<void> dispose() async {}
}
