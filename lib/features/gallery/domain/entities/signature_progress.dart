/// Progress of the background signature pass.
///
/// A first run over a large library is a minute-scale job. Anything that shows
/// it needs to distinguish "not started", "working, N of M", and "finished" —
/// a bare spinner for a minute reads as frozen.
class SignatureProgress {
  const SignatureProgress({
    required this.done,
    required this.total,
    required this.running,
  });

  static const idle = SignatureProgress(done: 0, total: 0, running: false);

  /// Photos signed so far in this pass — not the size of the whole library,
  /// since an incremental pass only touches what changed.
  final int done;

  /// Photos this pass set out to sign.
  final int total;

  final bool running;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  bool get hasWork => total > 0;

  SignatureProgress copyWith({int? done, int? total, bool? running}) =>
      SignatureProgress(
        done: done ?? this.done,
        total: total ?? this.total,
        running: running ?? this.running,
      );
}
