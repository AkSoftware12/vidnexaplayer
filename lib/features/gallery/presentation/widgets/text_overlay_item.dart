import 'package:material_ui/material_ui.dart';

import '../../domain/entities/text_overlay.dart';

/// Renders one text layer, and — when [interactive] — lets it be dragged,
/// pinched and rotated.
///
/// The same widget draws the on-screen layer and the one captured for export;
/// [interactive] is false during capture so no selection chrome ends up in the
/// saved file.
class TextOverlayItem extends StatelessWidget {
  const TextOverlayItem({
    super.key,
    required this.overlay,
    required this.canvasSize,
    this.interactive = false,
    this.selected = false,
    this.onTap,
    this.onChanged,
  });

  final TextOverlay overlay;
  final Size canvasSize;
  final bool interactive;
  final bool selected;
  final VoidCallback? onTap;
  final ValueChanged<TextOverlay>? onChanged;

  @override
  Widget build(BuildContext context) {
    final child = _Painted(overlay: overlay, selected: selected && interactive);

    return Positioned(
      left: overlay.dx * canvasSize.width,
      top: overlay.dy * canvasSize.height,
      child: FractionalTranslation(
        // The stored point is the centre of the text, not its top-left, so a
        // layer keeps its place when the text length changes.
        translation: const Offset(-0.5, -0.5),
        child: Transform.rotate(
          angle: overlay.rotation,
          child: Transform.scale(
            scale: overlay.scale,
            child: interactive
                ? _Gestures(
                    overlay: overlay,
                    canvasSize: canvasSize,
                    onTap: onTap,
                    onChanged: onChanged,
                    child: child,
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class _Gestures extends StatefulWidget {
  const _Gestures({
    required this.overlay,
    required this.canvasSize,
    required this.child,
    this.onTap,
    this.onChanged,
  });

  final TextOverlay overlay;
  final Size canvasSize;
  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<TextOverlay>? onChanged;

  @override
  State<_Gestures> createState() => _GesturesState();
}

class _GesturesState extends State<_Gestures> {
  late double _startScale;
  late double _startRotation;
  late Offset _startFocal;
  late double _startDx;
  late double _startDy;

  @override
  Widget build(BuildContext context) {
    // One `onScale*` family handles drag, pinch and twist together —
    // `ScaleGestureRecognizer` reports all three, and a single-finger drag
    // arrives as a scale of 1 with a moving focal point. Separate pan and
    // scale recognisers on the same widget would fight in the arena.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onScaleStart: (details) {
        _startScale = widget.overlay.scale;
        _startRotation = widget.overlay.rotation;
        _startFocal = details.focalPoint;
        _startDx = widget.overlay.dx;
        _startDy = widget.overlay.dy;
        widget.onTap?.call();
      },
      onScaleUpdate: (details) {
        final delta = details.focalPoint - _startFocal;
        widget.onChanged?.call(
          widget.overlay.copyWith(
            // Clamped a little beyond the edges so text can deliberately bleed
            // off the frame, but never so far it becomes unreachable.
            dx: (_startDx + delta.dx / widget.canvasSize.width)
                .clamp(-0.1, 1.1),
            dy: (_startDy + delta.dy / widget.canvasSize.height)
                .clamp(-0.1, 1.1),
            scale: (_startScale * details.scale).clamp(0.3, 6.0),
            rotation: _startRotation + details.rotation,
          ),
        );
      },
      child: widget.child,
    );
  }
}

class _Painted extends StatelessWidget {
  const _Painted({required this.overlay, required this.selected});

  final TextOverlay overlay;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final fill = Color(overlay.colorValue).withValues(alpha: overlay.opacity);
    final strokeColor = Color(overlay.strokeColorValue);

    Widget text(TextStyle style) => Text(
          overlay.text,
          textAlign: TextAlign.center,
          style: style,
        );

    final base = _style(fill);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: selected
          ? BoxDecoration(
              border: Border.all(color: Colors.white70, width: 1),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Stack(
        children: [
          // Outline is a second copy painted underneath with a stroked paint —
          // Flutter has no single "text stroke" property, and this is the
          // standard way to get one that still shapes complex scripts.
          if (overlay.strokeWidth > 0)
            text(
              base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = overlay.strokeWidth
                  ..strokeJoin = StrokeJoin.round
                  ..color = strokeColor.withValues(alpha: overlay.opacity),
              ),
            ),
          text(base),
        ],
      ),
    );
  }

  TextStyle _style(Color fill) {
    final shadows = overlay.hasShadow
        ? const [Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2))]
        : const <Shadow>[];

    final base = TextStyle(
      fontSize: overlay.fontSize,
      color: fill,
      height: 1.15,
      shadows: shadows,
    );

    // Every OverlayFont is bundled now, so the family name resolves straight
    // out of the APK. The `GoogleFonts.getFont` branch that used to sit here
    // hit the network on first use and threw a SocketException from inside
    // build() — see the note on [OverlayFont]. A face that somehow isn't
    // registered falls back to the platform default instead of crashing.
    return base.copyWith(fontFamily: overlay.font.family);
  }
}
