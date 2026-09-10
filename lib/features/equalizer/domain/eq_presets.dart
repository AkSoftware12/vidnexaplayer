import 'package:flutter/material.dart';

import 'eq_models.dart';

/// Where a preset is most useful. Video presets get a highlighted row in the
/// carousel — dialogue intelligibility is this player's differentiator, and it
/// should not be buried between "Jazz" and "Metal".
enum PresetCategory { general, music, video }

/// A built-in curve. Values are gains in dB on [EqGrid.canonicalHz]:
/// 31 · 62 · 125 · 250 · 500 · 1k · 2k · 4k · 8k · 16k
class EqPreset {
  const EqPreset({
    required this.id,
    required this.icon,
    required this.gainsDb,
    this.category = PresetCategory.general,
    this.bassBoost = 0,
    this.virtualizer = 0,
    this.reverb = ReverbPreset.none,
    this.loudnessMb = 0,
    this.nightMode = false,
    this.dialogueDownmix = false,
    this.hasSubtitle = false,
  });

  final String id;
  final IconData icon;
  final List<double> gainsDb;
  final PresetCategory category;
  final int bassBoost;
  final int virtualizer;
  final ReverbPreset reverb;
  final int loudnessMb;
  final bool nightMode;
  final bool dialogueDownmix;

  /// Whether this preset shows a second line under its name.
  final bool hasSubtitle;

  /// Translation keys, derived from [id] so the string table and the catalogue
  /// cannot drift apart. Resolved through `EqStrings` at the widget — the model
  /// never holds a display string, so a saved profile can't bake in the
  /// language it was created under.
  String get nameKey => 'eq_preset_$id';

  String get subtitleKey => 'eq_preset_${id}_sub';

  /// Applies the preset while leaving user-owned, preset-independent controls
  /// (master switch, balance, mono) exactly where they were.
  EqSettings applyTo(EqSettings current) => current.copyWith(
        gainsDb: List<double>.from(gainsDb),
        bassBoost: bassBoost,
        virtualizer: virtualizer,
        reverb: reverb,
        loudnessMb: loudnessMb,
        nightMode: nightMode,
        dialogueDownmix: dialogueDownmix,
        presetId: id,
      );
}

/// The built-in preset catalogue.
class EqPresets {
  const EqPresets._();

  static const EqPreset normal = EqPreset(
    id: 'normal',
    icon: Icons.graphic_eq_rounded,
    gainsDb: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  // ── music ────────────────────────────────────────────────────────────────

  static const EqPreset pop = EqPreset(
    id: 'pop',
    icon: Icons.music_note_rounded,
    category: PresetCategory.music,
    gainsDb: [-1, -0.5, 0, 2, 4, 4, 2, 0, -1, -1.5],
  );

  static const EqPreset rock = EqPreset(
    id: 'rock',
    icon: Icons.local_fire_department_rounded,
    category: PresetCategory.music,
    gainsDb: [5, 4, 2.5, 0, -1, -0.5, 1.5, 3.5, 4.5, 5],
  );

  static const EqPreset jazz = EqPreset(
    id: 'jazz',
    icon: Icons.piano_rounded,
    category: PresetCategory.music,
    gainsDb: [4, 3, 1, 2, -1, -1, 0, 1, 3, 4],
  );

  static const EqPreset classical = EqPreset(
    id: 'classical',
    icon: Icons.library_music_rounded,
    category: PresetCategory.music,
    gainsDb: [4, 3.5, 3, 2, -1, -1, 0, 2, 3, 4],
  );

  static const EqPreset dance = EqPreset(
    id: 'dance',
    icon: Icons.nightlife_rounded,
    category: PresetCategory.music,
    gainsDb: [6, 5, 3, 0, 1, 2, 3.5, 4, 3, 1],
    bassBoost: 350,
  );

  static const EqPreset hipHop = EqPreset(
    id: 'hip_hop',
    icon: Icons.headphones_rounded,
    category: PresetCategory.music,
    gainsDb: [6, 5.5, 3.5, 1.5, -1, 0.5, 1.5, 2, 3, 3.5],
    bassBoost: 400,
  );

  static const EqPreset metal = EqPreset(
    id: 'metal',
    icon: Icons.bolt_rounded,
    category: PresetCategory.music,
    gainsDb: [5, 4, 1, -1, -2, 1, 4, 5, 4.5, 3],
  );

  static const EqPreset bassBooster = EqPreset(
    id: 'bass_booster',
    icon: Icons.speaker_rounded,
    category: PresetCategory.music,
    gainsDb: [9, 8, 6, 3.5, 1, 0, 0, 0, 0, 0],
    bassBoost: 600,
  );

  static const EqPreset trebleBooster = EqPreset(
    id: 'treble_booster',
    icon: Icons.auto_awesome_rounded,
    category: PresetCategory.music,
    gainsDb: [0, 0, 0, 0, 0, 1, 3, 5.5, 7.5, 9],
  );

  static const EqPreset vocalBoost = EqPreset(
    id: 'vocal_boost',
    icon: Icons.mic_rounded,
    category: PresetCategory.music,
    gainsDb: [-2.5, -2, -1, 1, 4, 5.5, 5, 3, 0.5, -1],
  );

  // ── video / speech ───────────────────────────────────────────────────────

  static const EqPreset movie = EqPreset(
    id: 'movie',
    icon: Icons.movie_filter_rounded,
    category: PresetCategory.video,
    hasSubtitle: true,
    gainsDb: [5, 4.5, 2, -0.5, 1.5, 3, 3, 2.5, 3.5, 4],
    virtualizer: 700,
    loudnessMb: 200,
  );

  /// The one preset that fixes the single most common complaint about phone
  /// video playback: a loud score with unintelligible dialogue. Cuts rumble,
  /// lifts 1–4 kHz, and folds 5.1 down centre-forward.
  static const EqPreset dialogueClarity = EqPreset(
    id: 'dialogue',
    icon: Icons.record_voice_over_rounded,
    category: PresetCategory.video,
    hasSubtitle: true,
    gainsDb: [-4, -3.5, -2.5, -1, 2.5, 5, 6, 4.5, 1, -1],
    loudnessMb: 300,
    dialogueDownmix: true,
  );

  static const EqPreset podcast = EqPreset(
    id: 'podcast',
    icon: Icons.podcasts_rounded,
    category: PresetCategory.video,
    hasSubtitle: true,
    gainsDb: [-5, -4, -2, 0, 3, 4.5, 4, 2.5, 0, -2],
    loudnessMb: 400,
    nightMode: true,
  );

  /// Dynamic-range compression: explosions down, whispers up.
  static const EqPreset night = EqPreset(
    id: 'night',
    icon: Icons.bedtime_rounded,
    category: PresetCategory.video,
    hasSubtitle: true,
    gainsDb: [-1, -1, 0, 1, 3, 4, 3.5, 2, 0.5, -1],
    loudnessMb: 600,
    nightMode: true,
    dialogueDownmix: true,
  );

  static const EqPreset headphone = EqPreset(
    id: 'headphone',
    icon: Icons.headset_rounded,
    gainsDb: [3, 2.5, 1, -0.5, -1, 0, 1.5, 3, 3.5, 3],
    virtualizer: 500,
  );

  /// Sentinel used when the user has dragged a slider. It has no curve of its
  /// own — [EqSettings.gainsDb] is the truth — so it must never be `applyTo`'d.
  static const EqPreset custom = EqPreset(
    id: EqSettings.customId,
    icon: Icons.tune_rounded,
    gainsDb: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  static const List<EqPreset> all = [
    normal,
    movie,
    dialogueClarity,
    night,
    podcast,
    pop,
    rock,
    jazz,
    classical,
    dance,
    hipHop,
    metal,
    bassBooster,
    trebleBooster,
    vocalBoost,
    headphone,
  ];

  /// Ordering shown in the carousel: video presets first for the video player,
  /// music presets first for the music player.
  static List<EqPreset> orderedFor(MediaType type) {
    final wanted =
        type == MediaType.video ? PresetCategory.video : PresetCategory.music;
    final head = <EqPreset>[normal];
    final promoted = all.where((p) => p.category == wanted && p.id != normal.id);
    final rest = all
        .where((p) => p.category != wanted && p.id != normal.id);
    return [...head, ...promoted, ...rest];
  }

  static EqPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return id == custom.id ? custom : null;
  }
}
