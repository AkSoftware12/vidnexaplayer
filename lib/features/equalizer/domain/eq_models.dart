import 'dart:math' as math;

/// Which player the settings belong to. Video and music keep separate
/// "last used" state so a cinema curve does not follow the user into music.
enum MediaType { video, music }

/// Coarse output route reported by the platform, used to auto-switch profiles.
enum OutputDevice { speaker, wired, bluetooth, usb }

extension OutputDeviceX on OutputDevice {
  static OutputDevice parse(String? raw) => switch (raw) {
        'wired' => OutputDevice.wired,
        'bluetooth' => OutputDevice.bluetooth,
        'usb' => OutputDevice.usb,
        _ => OutputDevice.speaker,
      };

  /// Translation key, not a display string — the domain stays
  /// language-independent, and the UI resolves this through `EqStrings`.
  String get labelKey => switch (this) {
        OutputDevice.speaker => 'eq_out_speaker',
        OutputDevice.wired => 'eq_out_wired',
        OutputDevice.bluetooth => 'eq_out_bluetooth',
        OutputDevice.usb => 'eq_out_usb',
      };

  /// True where a virtualizer actually does something audible.
  bool get isHeadphoneLike => this != OutputDevice.speaker;
}

/// `PresetReverb` preset indices, in the platform's own order.
enum ReverbPreset { none, smallRoom, mediumRoom, largeRoom, mediumHall, largeHall, plate }

extension ReverbPresetX on ReverbPreset {
  int get platformValue => index;

  String get labelKey => switch (this) {
        ReverbPreset.none => 'eq_reverb_none',
        ReverbPreset.smallRoom => 'eq_reverb_small_room',
        ReverbPreset.mediumRoom => 'eq_reverb_medium_room',
        ReverbPreset.largeRoom => 'eq_reverb_large_room',
        ReverbPreset.mediumHall => 'eq_reverb_medium_hall',
        ReverbPreset.largeHall => 'eq_reverb_large_hall',
        ReverbPreset.plate => 'eq_reverb_plate',
      };
}

/// How many sliders the UI shows. Both modes edit the SAME underlying curve.
enum EqBandMode { five, ten }

/// The canonical EQ grid.
///
/// Everything — presets, saved profiles, the UI — is expressed as gains on
/// these ten frequencies, never on the device's own band layout. Devices report
/// anywhere from 3 to 12 bands at frequencies that differ per chipset, so
/// storing raw device levels would make a profile meaningless on the next
/// phone and would break the moment the user switched output routes.
/// [EqSettings.toDeviceLevelsMb] projects this curve onto whatever the device
/// actually has.
class EqGrid {
  const EqGrid._();

  /// Hz. 10-band mode shows one slider per entry.
  static const List<double> canonicalHz = [
    31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
  ];

  /// Hz. The classic 5-band layout, sampled off the same curve.
  static const List<double> fiveBandHz = [60, 230, 910, 3600, 14000];

  static List<double> hzFor(EqBandMode mode) =>
      mode == EqBandMode.ten ? canonicalHz : fiveBandHz;

  /// Gains are clamped to this before they ever reach the device.
  static const double minDb = -15.0;
  static const double maxDb = 15.0;

  static const int bandCount = 10;

  static List<double> get flat => List<double>.filled(bandCount, 0.0);

  /// Short axis label: 60Hz, 3.6kHz, 14kHz…
  static String labelFor(double hz) {
    if (hz < 1000) return '${hz.round()}Hz';
    final k = hz / 1000.0;
    final text = k >= 10 || k == k.roundToDouble()
        ? k.toStringAsFixed(k == k.roundToDouble() ? 0 : 1)
        : k.toStringAsFixed(1);
    return '${text}kHz';
  }

  /// Linear interpolation of [gainsDb] (defined on [canonicalHz]) at [hz],
  /// done in log-frequency space because that is how the ear spaces bands.
  /// Outside the grid the nearest endpoint is held flat — extrapolating a
  /// 16 kHz slope down to 20 kHz produces wild, inaudible gain.
  static double sample(List<double> gainsDb, double hz) {
    if (gainsDb.isEmpty) return 0;
    final x = math.log(hz);
    final first = math.log(canonicalHz.first);
    final last = math.log(canonicalHz.last);
    if (x <= first) return gainsDb.first;
    if (x >= last) return gainsDb[math.min(gainsDb.length - 1, canonicalHz.length - 1)];

    for (var i = 0; i < canonicalHz.length - 1; i++) {
      final lo = math.log(canonicalHz[i]);
      final hi = math.log(canonicalHz[i + 1]);
      if (x >= lo && x <= hi) {
        final t = (x - lo) / (hi - lo);
        final a = i < gainsDb.length ? gainsDb[i] : 0.0;
        final b = i + 1 < gainsDb.length ? gainsDb[i + 1] : a;
        return a + (b - a) * t;
      }
    }
    return gainsDb.last;
  }

  /// Reads the curve at the frequencies a given UI mode displays.
  static List<double> viewGains(List<double> gainsDb, EqBandMode mode) {
    if (mode == EqBandMode.ten) {
      return List<double>.generate(
        bandCount,
        (i) => i < gainsDb.length ? gainsDb[i] : 0.0,
      );
    }
    return fiveBandHz.map((hz) => sample(gainsDb, hz)).toList();
  }

  /// Writes one 5-band slider back onto the canonical curve.
  ///
  /// A 5-band slider owns a *range*, not a point, so the edit is spread with a
  /// triangular weight over the neighbouring canonical bands. Without that,
  /// dragging "Bass" would move 62 Hz and leave 31 Hz and 125 Hz behind, and
  /// the curve would grow spikes the user never asked for.
  static List<double> applyViewGain(
    List<double> gainsDb,
    EqBandMode mode,
    int viewIndex,
    double db,
  ) {
    final next = List<double>.from(gainsDb);
    final value = db.clamp(minDb, maxDb).toDouble();

    if (mode == EqBandMode.ten) {
      if (viewIndex >= 0 && viewIndex < next.length) next[viewIndex] = value;
      return next;
    }

    final centre = math.log(fiveBandHz[viewIndex]);
    // Half-width of one 5-band slice in log space.
    final width = fiveBandHz.length > 1
        ? (math.log(fiveBandHz.last) - math.log(fiveBandHz.first)) /
            (fiveBandHz.length - 1)
        : 1.0;

    final current = sample(gainsDb, fiveBandHz[viewIndex]);
    final delta = value - current;

    for (var i = 0; i < canonicalHz.length; i++) {
      final d = (math.log(canonicalHz[i]) - centre).abs();
      if (d >= width) continue;
      final weight = 1.0 - (d / width);
      next[i] = (next[i] + delta * weight).clamp(minDb, maxDb).toDouble();
    }
    return next;
  }
}

/// What the device reported when the effects were attached.
///
/// Band count, level range and centre frequencies are always READ from the
/// device — hardcoding 5 bands at fixed frequencies is why third-party
/// equalizers sound wrong on half the phones out there.
class EqCapabilities {
  const EqCapabilities({
    required this.attached,
    this.sessionId = 0,
    this.isGlobalSession = false,
    this.hasEqualizer = false,
    this.numberOfBands = 0,
    this.minLevelMb = -1500,
    this.maxLevelMb = 1500,
    this.centerFreqsHz = const [],
    this.devicePresets = const [],
    this.hasBassBoost = false,
    this.hasVirtualizer = false,
    this.hasReverb = false,
    this.hasLoudness = false,
    this.reason,
  });

  /// Everything off — used for the "not supported on this device" state and
  /// for the mpv filter backend, which reports its own capabilities instead.
  const EqCapabilities.unsupported({this.reason})
      : attached = false,
        sessionId = 0,
        isGlobalSession = false,
        hasEqualizer = false,
        numberOfBands = 0,
        minLevelMb = -1500,
        maxLevelMb = 1500,
        centerFreqsHz = const [],
        devicePresets = const [],
        hasBassBoost = false,
        hasVirtualizer = false,
        hasReverb = false,
        hasLoudness = false;

  final bool attached;
  final int sessionId;
  final bool isGlobalSession;
  final bool hasEqualizer;
  final int numberOfBands;
  final int minLevelMb;
  final int maxLevelMb;
  final List<double> centerFreqsHz;
  final List<String> devicePresets;
  final bool hasBassBoost;
  final bool hasVirtualizer;
  final bool hasReverb;
  final bool hasLoudness;
  final String? reason;

  /// True when the device gives fewer sliders than the 10-band UI implies, so
  /// the UI can tell the user their 10-band curve is being interpolated down.
  bool get isInterpolated => hasEqualizer && numberOfBands < EqGrid.bandCount;

  factory EqCapabilities.fromMap(Map<Object?, Object?> map) {
    if (map['attached'] != true) {
      return EqCapabilities.unsupported(reason: map['reason'] as String?);
    }
    final freqs = (map['centerFreqsMilliHz'] as List?)
            ?.map((e) => ((e as num?)?.toDouble() ?? 0) / 1000.0)
            .toList() ??
        const <double>[];
    return EqCapabilities(
      attached: true,
      sessionId: (map['sessionId'] as num?)?.toInt() ?? 0,
      isGlobalSession: map['isGlobalSession'] == true,
      hasEqualizer: map['equalizer'] == true,
      numberOfBands: (map['numberOfBands'] as num?)?.toInt() ?? 0,
      minLevelMb: (map['minLevelMb'] as num?)?.toInt() ?? -1500,
      maxLevelMb: (map['maxLevelMb'] as num?)?.toInt() ?? 1500,
      centerFreqsHz: freqs,
      devicePresets:
          (map['devicePresets'] as List?)?.map((e) => '$e').toList() ?? const [],
      hasBassBoost: map['bassBoost'] == true,
      hasVirtualizer: map['virtualizer'] == true,
      hasReverb: map['reverb'] == true,
      hasLoudness: map['loudness'] == true,
    );
  }
}

/// The complete, serialisable audio-effect state.
///
/// One object drives both backends and both players; nothing here knows about
/// audiofx or mpv.
class EqSettings {
  const EqSettings({
    this.enabled = false,
    this.gainsDb = const [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    this.bassBoost = 0,
    this.virtualizer = 0,
    this.reverb = ReverbPreset.none,
    this.loudnessMb = 0,
    this.balance = 0.0,
    this.mono = false,
    this.dialogueDownmix = false,
    this.nightMode = false,
    this.presetId = 'normal',
  });

  /// Master switch. When false the backends push a fully bypassed chain.
  final bool enabled;

  /// Gains in dB on [EqGrid.canonicalHz]. Always ten entries.
  final List<double> gainsDb;

  /// 0..1000, the platform's own strength scale.
  final int bassBoost;
  final int virtualizer;
  final ReverbPreset reverb;

  /// LoudnessEnhancer target gain in millibel, 0..2000.
  final int loudnessMb;

  /// -1 = full left, 0 = centred, +1 = full right.
  final double balance;

  /// Accessibility: collapse both channels to the same signal.
  final bool mono;

  /// 5.1 -> stereo downmix that keeps the centre (dialogue) channel forward.
  final bool dialogueDownmix;

  /// Dynamic-range compression: quiet passages up, loud ones down.
  final bool nightMode;

  /// Which preset or saved profile produced this state; 'custom' once edited.
  final String presetId;

  static const String customId = 'custom';

  bool get isFlat => gainsDb.every((g) => g.abs() < 0.05);

  EqSettings copyWith({
    bool? enabled,
    List<double>? gainsDb,
    int? bassBoost,
    int? virtualizer,
    ReverbPreset? reverb,
    int? loudnessMb,
    double? balance,
    bool? mono,
    bool? dialogueDownmix,
    bool? nightMode,
    String? presetId,
  }) {
    return EqSettings(
      enabled: enabled ?? this.enabled,
      gainsDb: gainsDb ?? this.gainsDb,
      bassBoost: bassBoost ?? this.bassBoost,
      virtualizer: virtualizer ?? this.virtualizer,
      reverb: reverb ?? this.reverb,
      loudnessMb: loudnessMb ?? this.loudnessMb,
      balance: balance ?? this.balance,
      mono: mono ?? this.mono,
      dialogueDownmix: dialogueDownmix ?? this.dialogueDownmix,
      nightMode: nightMode ?? this.nightMode,
      presetId: presetId ?? this.presetId,
    );
  }

  /// Projects the canonical curve onto the device's real bands.
  ///
  /// Levels come back in millibel, clamped to the range the device reported —
  /// writing outside it is silently ignored by some vendors and throws on
  /// others.
  List<int> toDeviceLevelsMb(EqCapabilities caps) {
    final n = caps.numberOfBands;
    if (n <= 0) return const [];
    return List<int>.generate(n, (i) {
      final hz = i < caps.centerFreqsHz.length && caps.centerFreqsHz[i] > 0
          ? caps.centerFreqsHz[i]
          // Device did not report a usable centre frequency: fall back to an
          // even log spread across the audible range.
          : 31.0 * math.pow(2, i * (9.0 / math.max(1, n - 1))).toDouble();
      final db = EqGrid.sample(gainsDb, hz);
      return (db * 100).round().clamp(caps.minLevelMb, caps.maxLevelMb);
    });
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'gainsDb': gainsDb,
        'bassBoost': bassBoost,
        'virtualizer': virtualizer,
        'reverb': reverb.index,
        'loudnessMb': loudnessMb,
        'balance': balance,
        'mono': mono,
        'dialogueDownmix': dialogueDownmix,
        'nightMode': nightMode,
        'presetId': presetId,
      };

  factory EqSettings.fromJson(Map<dynamic, dynamic> json) {
    final raw = (json['gainsDb'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        EqGrid.flat;
    // Tolerate profiles written by an older build with a different band count.
    final gains = List<double>.generate(
      EqGrid.bandCount,
      (i) => i < raw.length ? raw[i].clamp(EqGrid.minDb, EqGrid.maxDb).toDouble() : 0.0,
    );
    return EqSettings(
      enabled: json['enabled'] == true,
      gainsDb: gains,
      bassBoost: ((json['bassBoost'] as num?)?.toInt() ?? 0).clamp(0, 1000),
      virtualizer: ((json['virtualizer'] as num?)?.toInt() ?? 0).clamp(0, 1000),
      reverb: ReverbPreset.values[
          ((json['reverb'] as num?)?.toInt() ?? 0).clamp(0, ReverbPreset.values.length - 1)],
      loudnessMb: ((json['loudnessMb'] as num?)?.toInt() ?? 0).clamp(0, 2000),
      balance: ((json['balance'] as num?)?.toDouble() ?? 0).clamp(-1.0, 1.0),
      mono: json['mono'] == true,
      dialogueDownmix: json['dialogueDownmix'] == true,
      nightMode: json['nightMode'] == true,
      presetId: json['presetId'] as String? ?? customId,
    );
  }
}
