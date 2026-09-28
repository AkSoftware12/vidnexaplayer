import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../domain/genre_classifier.dart';

/// Live spectrum bars, drawn behind the EQ curve.
class VisualizerPainter extends CustomPainter {
  VisualizerPainter({
    required this.levels,
    required this.color,
    required this.repaint,
  }) : super(repaint: repaint);

  /// 0..1 per bar, already smoothed by [LiveVisualizer].
  final List<double> levels;
  final Color color;
  final Listenable repaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.isEmpty || size.width <= 0 || size.height <= 0) return;

    final slot = size.width / levels.length;
    final barWidth = math.max(1.5, slot * 0.62);
    final radius = Radius.circular(barWidth / 2);

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, size.height),
        const Offset(0, 0),
        [color.withValues(alpha: 0.10), color.withValues(alpha: 0.55)],
      );

    for (var i = 0; i < levels.length; i++) {
      final h = (levels[i].clamp(0.0, 1.0)) * size.height;
      if (h < 1) continue;
      final left = slot * i + (slot - barWidth) / 2;
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          left,
          size.height - h,
          left + barWidth,
          size.height,
          topLeft: radius,
          topRight: radius,
        ),
        paint,
      );
    }
  }

  // Repainting is driven by the `repaint` Listenable, so this can stay false —
  // the widget above only rebuilds when its own configuration changes.
  @override
  bool shouldRepaint(covariant VisualizerPainter old) =>
      old.color != color || old.levels.length != levels.length;
}

/// Drives [VisualizerPainter] from the service's spectrum notifier.
///
/// The native side emits at ~20 fps. Painting those values raw looks jittery,
/// so bars rise instantly and fall with a decay — the standard analyser feel,
/// and it also hides a dropped frame instead of flickering to zero.
class LiveVisualizer extends StatefulWidget {
  const LiveVisualizer({
    super.key,
    required this.spectrum,
    required this.color,
    this.barCount = 32,
    this.active = true,
  });

  final ValueListenable<SpectrumFrame> spectrum;
  final Color color;
  final int barCount;

  /// When false the bars decay to zero and no repaints are scheduled.
  final bool active;

  @override
  State<LiveVisualizer> createState() => _LiveVisualizerState();
}

class _LiveVisualizerState extends State<LiveVisualizer>
    with SingleTickerProviderStateMixin {
  late final List<double> _levels =
      List<double>.filled(widget.barCount, 0, growable: false);

  /// Ticks the decay. A Listenable handed to the painter, so the whole subtree
  /// never rebuilds — only the canvas repaints.
  late final Ticker _ticker = createTicker(_onTick);
  final _RepaintSignal _repaint = _RepaintSignal();

  Duration _lastTick = Duration.zero;

  @override
  void initState() {
    super.initState();
    widget.spectrum.addListener(_onFrame);
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant LiveVisualizer old) {
    super.didUpdateWidget(old);
    if (old.spectrum != widget.spectrum) {
      old.spectrum.removeListener(_onFrame);
      widget.spectrum.addListener(_onFrame);
    }
    if (widget.active && !_ticker.isActive) {
      _ticker.start();
    } else if (!widget.active && _ticker.isActive) {
      _ticker.stop();
      for (var i = 0; i < _levels.length; i++) {
        _levels[i] = 0;
      }
      _repaint.tick();
    }
  }

  void _onFrame() {
    final bars = widget.spectrum.value.bars;
    if (bars.isEmpty) return;
    for (var i = 0; i < _levels.length; i++) {
      // Map however many bars the platform sent onto however many we draw.
      final src = bars[(i * bars.length ~/ _levels.length).clamp(0, bars.length - 1)];
      if (src > _levels[i]) _levels[i] = src; // attack: instant
    }
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0) return;

    // ~3.5 units/second decay: fast enough to follow a beat, slow enough not
    // to strobe.
    final drop = 3.5 * dt;
    var changed = false;
    for (var i = 0; i < _levels.length; i++) {
      if (_levels[i] > 0) {
        _levels[i] = math.max(0, _levels[i] - drop);
        changed = true;
      }
    }
    if (changed) _repaint.tick();
  }

  @override
  void dispose() {
    widget.spectrum.removeListener(_onFrame);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: VisualizerPainter(
          levels: _levels,
          color: widget.color,
          repaint: _repaint,
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// A bare repaint trigger. Exists only because `notifyListeners` is protected —
/// a plain `ChangeNotifier` field cannot be poked from outside itself.
class _RepaintSignal extends ChangeNotifier {
  void tick() => notifyListeners();
}
