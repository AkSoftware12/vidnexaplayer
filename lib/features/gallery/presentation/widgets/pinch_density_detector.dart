import 'package:flutter/material.dart';

/// Pinch the photo grid to change how many columns it shows.
///
/// Built on [Listener] rather than `GestureDetector`, deliberately. A
/// `ScaleGestureRecognizer` enters the gesture arena and competes with the
/// scrollable underneath it, which costs you vertical drags — the grid stops
/// scrolling smoothly the moment you wrap it. [Listener] only observes pointer
/// events and never claims a gesture, so scrolling behaves exactly as it did
/// and pinches are read alongside it.
///
/// Each density step re-baselines the pinch, so one continuous spread can walk
/// 5 columns down to 2 without the user lifting their fingers.
class PinchDensityDetector extends StatefulWidget {
  const PinchDensityDetector({
    super.key,
    required this.child,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final Widget child;

  /// Fingers moved apart — bigger tiles, fewer columns.
  final VoidCallback onZoomIn;

  /// Fingers moved together — smaller tiles, more columns.
  final VoidCallback onZoomOut;

  @override
  State<PinchDensityDetector> createState() => _PinchDensityDetectorState();
}

class _PinchDensityDetectorState extends State<PinchDensityDetector> {
  /// Spread far enough to be unambiguous, but not so far that a step needs a
  /// full hand span.
  static const _zoomInRatio = 1.35;
  static const _zoomOutRatio = 0.74;

  final Map<int, Offset> _pointers = {};
  double? _baseDistance;

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    _baseDistance = _distance();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    final base = _baseDistance;
    final current = _distance();
    if (current == null) return;
    if (base == null || base <= 0) {
      _baseDistance = current;
      return;
    }

    final ratio = current / base;
    if (ratio >= _zoomInRatio) {
      widget.onZoomIn();
      _baseDistance = current;
    } else if (ratio <= _zoomOutRatio) {
      widget.onZoomOut();
      _baseDistance = current;
    }
  }

  void _onPointerGone(int pointer) {
    _pointers.remove(pointer);
    _baseDistance = _distance();
  }

  /// Distance between the first two active pointers, or null when fewer than
  /// two are down — a single finger is a scroll, not a pinch.
  double? _distance() {
    if (_pointers.length < 2) return null;
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (event) => _onPointerGone(event.pointer),
      onPointerCancel: (event) => _onPointerGone(event.pointer),
      child: widget.child,
    );
  }
}
