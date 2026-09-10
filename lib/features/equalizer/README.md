# Shared AI Equalizer

One audio-effects engine for **both** players. Same presets, same profiles, same
state, same UI — the only thing that differs per player is the last hop into the
audio.

## Files

```
android/app/src/main/kotlin/com/vidnexa/videoplayer/audiofx/
  AudioEffectsPlugin.kt        MethodChannel + 2 EventChannels over android.media.audiofx
                               (registered from MainActivity.configureFlutterEngine,
                                released in cleanUpFlutterEngine)

lib/features/equalizer/
  audio_effects_service.dart   ChangeNotifier: session binding, state, profiles, Auto-EQ

  domain/
    eq_models.dart             MediaType, OutputDevice, ReverbPreset, EqGrid,
                               EqCapabilities, EqSettings
    eq_presets.dart            16 built-in presets
    eq_profile.dart            user profile model + share/import JSON
    genre_classifier.dart      SpectrumFrame, GenreClassifier interface,
                               RuleBasedGenreClassifier, AutoEqEngine

  data/
    audio_effects_platform.dart  total wrapper over the channels (never throws)
    eq_backend.dart              EqBackend interface + NullEqBackend
    native_effects_backend.dart  android.media.audiofx on a session id  (music)
    mpv_filter_backend.dart      mpv `af` lavfi chain                   (video)
    eq_repository.dart           Hive persistence (in-memory fallback)

  presentation/
    equalizer_page.dart          EqualizerPage + EqualizerBody + EqColors
    equalizer_sheet.dart         showEqualizerSheet(), openEqualizerPage()
    widgets/eq_curve_painter.dart
    widgets/visualizer_painter.dart
    widgets/eq_band_slider.dart
    widgets/preset_carousel.dart
    widgets/profile_sheet.dart
```

## Architecture: why there are two backends

The brief assumed ExoPlayer for video, which exposes an `audioSessionId` that
`android.media.audiofx` can attach to. **This app plays video through
media_kit/libmpv, not ExoPlayer**, and media_kit pins mpv's audio output to
`ao=opensles` (`media_kit/lib/src/player/native/player/real.dart`), which has no
audio session id at all. So:

| Player | Session id | Backend | Visualizer |
|---|---|---|---|
| Music (`just_audio`) | `player.androidAudioSessionIdStream` — real | `NativeEffectsBackend` (audiofx) | yes |
| Video (`media_kit`) | none available | `MpvFilterBackend` (ffmpeg `af` chain) | no |

Everything above the backend is shared: one `EqSettings` model, one preset
catalogue, one profile store, one `EqualizerBody` widget.

The plugin still exposes `generateSessionId`, and `MpvFilterBackend`'s header
documents the upgrade path: if media_kit ever switches Android to
`ao=audiotrack`, setting `audiotrack-session-id` to a generated id lets video use
the native backend too, with no change above the `EqBackend` interface.

**The global session (id 0) is never used as the primary target.** It is
deprecated since Android 10 and a silent no-op on many devices; the plugin
refuses it unless the caller passes `allowGlobalFallback: true`, and nothing in
the app currently does.

## The canonical band grid

Devices report 3–12 bands at frequencies that vary per chipset, so raw device
levels are not portable. Everything — presets, saved profiles, the UI — is stored
as **gains in dB on ten fixed frequencies** (31 · 62 · 125 · 250 · 500 · 1k · 2k ·
4k · 8k · 16k), and `EqSettings.toDeviceLevelsMb()` interpolates that curve onto
whatever the device actually has, clamped to the range it reported.

The 5-band UI mode samples the same curve at 60 · 230 · 910 · 3.6k · 14k Hz, and
writing a 5-band slider spreads the change across neighbouring canonical bands
with a triangular weight, so the curve stays smooth. If the device has fewer
bands than the UI shows, the header says so (`Device has N bands — curve
interpolated`).

## Wiring

**Music** — bound once, in `main.dart`'s deferred init:

```dart
final effects = AudioEffectsService.instance;
await effects.init();
await effects.bindMusicPlayer(AudioServiceInit.handler.player);
```

`bindMusicPlayer` subscribes to `androidAudioSessionIdStream`, so every session
change (new track, sample-rate change, offload transition) releases the old
effects and re-attaches to the new session automatically.

**Video** — in `4k_player.dart`:

```dart
await AudioEffectsService.instance.bindVideoPlayer(_player);   // after Player()
await AudioEffectsService.instance.reapply(MediaType.video);   // after every open()
await AudioEffectsService.instance.unbind(MediaType.video);    // in dispose()
```

`mpv` has exactly one `af` property, so the player's volume-boost limiter no
longer writes it directly — it registers through
`AudioEffectsService.setVideoExtraFilters(['alimiter=limit=0.92'])` and the
backend composes one chain. (Before this, whichever wrote `af` last silently
erased the other.)

**Entry points** — `Me → Preferences → Equalizer` (full page), the video player's
quick-actions sheet, and the music full-screen player's icon row. All three land
on the same widget.

## Permissions

`android.media.audiofx.Visualizer` is gated behind `RECORD_AUDIO` even though it
only reads **this app's own output mix** — nothing from the microphone is
captured and nothing leaves the device. It is therefore requested **only** when
the user turns on Live Spectrum or Auto EQ, with that explanation shown next to
the toggles. `MODIFY_AUDIO_SETTINGS` is install-time and needs no prompt.

## Auto EQ

Not ML. `Visualizer` FFT (capture size 1024) → six perceptual band shares →
7-second rolling average → three thresholds:

- mid+high-mid > 0.52 and lows < 0.28 → **Speech / Dialogue** → Dialogue Clarity
  (video) or Vocal Boost (music)
- sub-bass+bass > 0.48 and treble < 0.18 → **Bass Heavy** → Movie / Bass Booster
- treble > 0.30 and lows < 0.25 → **Bright** → Treble Booster
- otherwise **Balanced** → Normal

Frames below an RMS floor are dropped so silence cannot drag the average.
Metadata genre tags are the fallback when no spectrum is available. A suggestion
below 0.6 confidence is never shown. **It only auto-applies when the user has
turned Auto EQ on**; otherwise it is a chip with Apply / Dismiss.

`GenreClassifier` is an interface — a TFLite model can replace
`RuleBasedGenreClassifier` without touching the service or the UI.

## Reliability notes

- Every `AudioEffect` is constructed in its own try/catch and every setter is
  wrapped: a device where only some effects come up degrades to a capability
  flag, not a crash. If nothing at all attaches, the UI shows *"not supported on
  this device — its built-in sound settings may be holding the audio effects"*.
- Effects are **released**, not just disabled, on unbind/dispose — a live effect
  on a dead session is what produces `effect creation failed` on the next attach.
  `MainActivity.cleanUpFlutterEngine` releases everything as a backstop.
- mpv rejects the *whole* filter graph if one filter is missing from the bundled
  ffmpeg, so `MpvFilterBackend` reads `af` back after writing it and retries with
  a biquad-only chain rather than leaving the user with no EQ.
- Output-route changes re-push the whole chain before applying the route's bound
  profile, because routing changes rebuild the audio sink on some devices.
- Hive failing to open degrades to an in-memory store (settings do not survive a
  restart) instead of taking the feature down.

## Known device issues

- **MIUI / Samsung / Realme**: the OEM's own equalizer (MiSound, Dolby Atmos,
  Real Sound) can hold the audiofx slots exclusively. `Equalizer`/`BassBoost`
  construction throws and the UI reports the device as unsupported. Turning the
  OEM effect off in system settings usually frees them.
- **Android 10+**: session id 0 is deprecated and largely inert; not used.
- **AC3 / E-AC3** tracks are mastered ~10 dB below stereo AAC. When the video
  player reports such a codec, `applyCodecHint` adds +6 dB of LoudnessEnhancer /
  `volume` for that track only — it is never written into a saved profile.
- Bluetooth codecs with their own DSP (LDAC, AptX Adaptive) apply effects after
  ours; heavy boosts can clip at the receiver.
