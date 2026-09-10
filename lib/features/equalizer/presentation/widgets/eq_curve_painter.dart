import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Draws the EQ response as a smooth spline through the band gains.
///
/// The sliders alone tell the user what each band is set to; the curve tells
/// them what the whole thing will SOUND like, which is the part people actually
/// read. A Catmull-Rom spline is used rather than straight segments because a
/// graphic EQ's real response is smooth — polyline corners would be a lie about
/// what the filters do.
class EqCurvePainter extends CustomPainter {
  EqCurvePainter({
    required this.gainsDb,
    required this.minDb,
    required this.maxDb,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
    this.enabled = true,
  });

  final List<double> gainsDb;
  final double minDb;
  final double maxDb;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _paintGrid(canvas, size);
    if (gainsDb.length < 2) return;

    final points = _points(size);
    final path = _spline(points);

    // Filled area down to the 0 dB line, so cuts read as clearly as boosts.
    final zeroY = _yFor(0, size.height);
    final fill = Path.from(path)
      ..lineTo(points.last.dx, zeroY)
      ..lineTo(points.first.dx, zeroY)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, size.height),
          [fillColor.withValues(alpha: enabled ? 0.34 : 0.10), fillColor.withValues(alpha: 0.0)],
        ),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = enabled ? lineColor : lineColor.withValues(alpha: 0.35),
    );

    // A dot per band anchors the curve to the slider underneath it.
    final dot = Paint()
      ..color = enabled ? lineColor : lineColor.withValues(alpha: 0.35);
    for (final p in points) {
      canvas.drawCircle(p, 3.0, dot);
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // 0 dB is drawn solid; the ±half-range lines are the faint reference.
    for (final db in [maxDb / 2, 0.0, minDb / 2]) {
      final y = _yFor(db, size.height);
      paint.color = db == 0 ? gridColor.withValues(alpha: 0.55) : gridColor.withValues(alpha: 0.22);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  List<Offset> _points(Size size) {
    final n = gainsDb.length;
    // Half a step of inset at each end lines the first and last point up with
    // the centre of the first and last slider.
    final step = size.width / n;
    return List<Offset>.generate(n, (i) {
      final x = step * (i + 0.5);
      return Offset(x, _yFor(gainsDb[i], size.height));
    });
  }

  double _yFor(double db, double height) {
    final t = ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);
    // Keep the extremes a few px inside the box so the stroke is never clipped.
    return height - (t * (height - 8) + 4);
  }

  /// Catmull-Rom through every point, emitted as cubic beziers.
  Path _spline(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = i == 0 ? pts[0] : pts[i - 1];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = i + 2 < pts.length ? pts[i + 2] : p2;

      // The /6 tension is the standard uniform Catmull-Rom -> Bezier factor;
      // anything larger overshoots and invents gain the EQ does not apply.
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6,
        p1.dy + (p2.dy - p0.dy) / 6,
        p2.dx - (p3.dx - p1.dx) / 6,
        p2.dy - (p3.dy - p1.dy) / 6,
        p2.dx,
        p2.dy,
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant EqCurvePainter old) =>
      old.enabled != enabled ||
      old.lineColor != lineColor ||
      old.minDb != minDb ||
      old.maxDb != maxDb ||
      !_sameGains(old.gainsDb);

  bool _sameGains(List<double> other) {
    if (other.length != gainsDb.length) return false;
    for (var i = 0; i < gainsDb.length; i++) {
      if ((other[i] - gainsDb[i]).abs() > 0.01) return false;
    }
    return true;
  }
}

/// Frequency labels under the curve (60Hz · 230Hz · 910Hz · 3.6kHz · 14kHz).
class EqFrequencyLabels extends StatelessWidget {
  const EqFrequencyLabels({
    super.key,
    required this.labels,
    required this.color,
    this.fontSize = 9,
  });

  final List<String> labels;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final label in labels)
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: fontSize,
                color: color,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
      ],
    );
  }
}

/// Small helper so the curve box keeps a sane aspect ratio on tablets.
double eqCurveHeightFor(double width) => math.min(140, math.max(84, width * 0.28));
