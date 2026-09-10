import 'dart:collection';

import 'eq_models.dart';
import 'eq_presets.dart';

/// One FFT frame, already bucketed by the native side.
///
/// [bands] is a share-of-total vector (sums to ~1), so it describes the SHAPE
/// of the spectrum independently of how loud playback is.
class SpectrumFrame {
  const SpectrumFrame({
    required this.bars,
    required this.bands,
    required this.rms,
  });

  /// 32 log-spaced magnitudes, 0..1 — for the painter only.
  final List<double> bars;

  /// sub-bass · bass · low-mid · mid · high-mid · treble, each 0..1.
  final List<double> bands;

  /// Overall level 0..1; near-silence is excluded from the rolling average.
  final double rms;

  static const SpectrumFrame silent = SpectrumFrame(
    bars: <double>[],
    bands: <double>[0, 0, 0, 0, 0, 0],
    rms: 0,
  );

  factory SpectrumFrame.fromMap(Map<Object?, Object?> map) {
    List<double> nums(Object? v, int fallbackLength) =>
        (v as List?)?.map((e) => (e as num).toDouble()).toList() ??
        List<double>.filled(fallbackLength, 0);
    return SpectrumFrame(
      bars: nums(map['bars'], 32),
      bands: nums(map['bands'], 6),
      rms: (map['rms'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Named accessors over [SpectrumFrame.bands], so the rules below read as
/// something a human can check.
extension SpectrumBands on List<double> {
  double get subBass => length > 0 ? this[0] : 0;
  double get bass => length > 1 ? this[1] : 0;
  double get lowMid => length > 2 ? this[2] : 0;
  double get mid => length > 3 ? this[3] : 0;
  double get highMid => length > 4 ? this[4] : 0;
  double get treble => length > 5 ? this[5] : 0;
}

/// What the classifier thinks is playing, and what to do about it.
class EqSuggestion {
  const EqSuggestion({
    required this.contentLabelKey,
    this.contentDetail,
    required this.presetId,
    required this.confidence,
  });

  /// Translation key for what is playing; the UI resolves it via EqStrings.
  final String contentLabelKey;

  /// Untranslatable extra shown after the label — currently only the raw genre
  /// tag read from file metadata, which is whatever the file happens to say.
  final String? contentDetail;

  final String presetId;

  /// 0..1. The UI only surfaces a chip above [AutoEqEngine.minConfidence].
  final double confidence;

  EqPreset? get preset => EqPresets.byId(presetId);
}

/// Everything the classifier gets to look at.
class ClassifierInput {
  const ClassifierInput({
    required this.bands,
    required this.mediaType,
    this.genreTag,
    this.sampleCount = 0,
  });

  /// Rolling-average band shares.
  final List<double> bands;
  final MediaType mediaType;

  /// Genre from file metadata, when the caller has it. Used as a tie-breaker
  /// and as the whole answer when no spectrum is available (no RECORD_AUDIO).
  final String? genreTag;

  final int sampleCount;
}

/// Pluggable so a TFLite model can replace the rules later without touching
/// the service, the controller or the UI.
abstract class GenreClassifier {
  /// Returns null when there is not enough evidence to say anything.
  EqSuggestion? classify(ClassifierInput input);
}

/// Rule-based classifier — deliberately not ML.
///
/// A 300 KB model to distinguish "speech" from "bass-heavy music" would cost
/// startup time and app size for a decision three thresholds already make
/// correctly, and it would be far harder to explain when it is wrong.
class RuleBasedGenreClassifier implements GenreClassifier {
  const RuleBasedGenreClassifier();

  @override
  EqSuggestion? classify(ClassifierInput input) {
    final b = input.bands;
    final total = b.fold<double>(0, (s, v) => s + v);

    // No usable spectrum: fall back to the metadata genre tag alone.
    if (total < 0.5) return _fromGenreTag(input);

    final isVideo = input.mediaType == MediaType.video;
    final low = b.subBass + b.bass;
    final speech = b.mid + b.highMid;

    // Speech: energy concentrated in 500 Hz–4 kHz with little below it. This
    // fires on dialogue, podcasts and news, and is checked FIRST because a
    // film's dialogue track is the case worth fixing.
    if (speech > 0.52 && low < 0.28) {
      final margin = ((speech - 0.52) / 0.30).clamp(0.0, 1.0);
      return EqSuggestion(
        contentLabelKey: 'eq_content_speech',
        presetId: isVideo ? EqPresets.dialogueClarity.id : EqPresets.vocalBoost.id,
        confidence: 0.55 + 0.45 * margin,
      );
    }

    // Bass-dominant: EDM, hip-hop, and most film action scenes.
    if (low > 0.48 && b.treble < 0.18) {
      final margin = ((low - 0.48) / 0.30).clamp(0.0, 1.0);
      return EqSuggestion(
        contentLabelKey: 'eq_content_bass',
        presetId: isVideo ? EqPresets.movie.id : EqPresets.bassBooster.id,
        confidence: 0.55 + 0.4 * margin,
      );
    }

    // Bright / thin: lots of treble, little weight underneath.
    if (b.treble > 0.30 && low < 0.25) {
      return EqSuggestion(
        contentLabelKey: 'eq_content_bright',
        presetId: EqPresets.trebleBooster.id,
        confidence: 0.6,
      );
    }

    // Wide and even — leave it alone. Suggesting a curve here is exactly how
    // auto-EQ earns a reputation for making things worse.
    return const EqSuggestion(
      contentLabelKey: 'eq_content_balanced',
      presetId: 'normal',
      confidence: 0.5,
    );
  }

  EqSuggestion? _fromGenreTag(ClassifierInput input) {
    final tag = input.genreTag?.toLowerCase().trim();
    if (tag == null || tag.isEmpty) return null;

    String? id;
    if (tag.contains('hip') || tag.contains('rap') || tag.contains('trap')) {
      id = EqPresets.hipHop.id;
    } else if (tag.contains('edm') ||
        tag.contains('dance') ||
        tag.contains('house') ||
        tag.contains('techno')) {
      id = EqPresets.dance.id;
    } else if (tag.contains('rock') || tag.contains('punk')) {
      id = EqPresets.rock.id;
    } else if (tag.contains('metal')) {
      id = EqPresets.metal.id;
    } else if (tag.contains('jazz') || tag.contains('blues')) {
      id = EqPresets.jazz.id;
    } else if (tag.contains('classic') || tag.contains('orchestr')) {
      id = EqPresets.classical.id;
    } else if (tag.contains('pop')) {
      id = EqPresets.pop.id;
    } else if (tag.contains('podcast') ||
        tag.contains('speech') ||
        tag.contains('audiobook') ||
        tag.contains('spoken')) {
      id = EqPresets.podcast.id;
    }
    if (id == null) return null;

    return EqSuggestion(
      contentLabelKey: 'eq_content_genre_tag',
      contentDetail: input.genreTag,
      presetId: id,
      // Lower than any spectrum-derived verdict — tags are frequently wrong.
      confidence: 0.55,
    );
  }
}

/// Keeps a rolling window of spectrum frames and asks the classifier what is
/// playing. Pure Dart, no platform calls — trivially unit-testable.
class AutoEqEngine {
  AutoEqEngine({
    GenreClassifier? classifier,
    this.windowFrames = 140, // ~7 s at the native 20 fps emit rate
    this.minFrames = 60, // ~3 s before the first verdict
  }) : classifier = classifier ?? const RuleBasedGenreClassifier();

  final GenreClassifier classifier;
  final int windowFrames;
  final int minFrames;

  /// Below this a suggestion is kept internal and never shown as a chip.
  static const double minConfidence = 0.6;

  final Queue<List<double>> _window = Queue<List<double>>();

  /// Frames quieter than this are dropped: a silent passage would otherwise
  /// drag the rolling average toward whatever noise floor the device has.
  static const double _silenceFloor = 0.06;

  void add(SpectrumFrame frame) {
    if (frame.rms < _silenceFloor) return;
    _window.addLast(frame.bands);
    while (_window.length > windowFrames) {
      _window.removeFirst();
    }
  }

  void reset() => _window.clear();

  bool get hasEnoughData => _window.length >= minFrames;

  /// Rolling average of the band shares over the current window.
  List<double> get averageBands {
    if (_window.isEmpty) return List<double>.filled(6, 0);
    final sum = List<double>.filled(6, 0);
    for (final f in _window) {
      for (var i = 0; i < 6 && i < f.length; i++) {
        sum[i] += f[i];
      }
    }
    return sum.map((v) => v / _window.length).toList();
  }

  /// Null until the window has filled enough to be worth trusting.
  EqSuggestion? evaluate({required MediaType mediaType, String? genreTag}) {
    if (!hasEnoughData) {
      // No spectrum yet (or no permission) — a genre tag alone is still
      // better than nothing.
      if (_window.isEmpty && genreTag != null) {
        return classifier.classify(ClassifierInput(
          bands: List<double>.filled(6, 0),
          mediaType: mediaType,
          genreTag: genreTag,
        ));
      }
      return null;
    }
    return classifier.classify(ClassifierInput(
      bands: averageBands,
      mediaType: mediaType,
      genreTag: genreTag,
      sampleCount: _window.length,
    ));
  }
}
