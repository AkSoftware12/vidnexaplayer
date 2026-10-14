import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

/// Small chip that stays on screen while HDR is on: "HDR · 4:32".
///
/// The HDR an ad buys runs out after five minutes, and switching off with no
/// warning feels like a bug — so the time left is always visible, and the
/// chip turns red and pulses for the last [_warnAt]. Premium users have no
/// limit and get a plain "HDR" chip ([left] stays null).
///
/// Listens to [left] directly, so the once-a-second tick rebuilds only this
/// chip, never the player around it.
class HdrTimerChip extends StatelessWidget {
  const HdrTimerChip({super.key, required this.left});

  /// Time remaining, or null for an untimed (premium) HDR.
  final ValueListenable<Duration?> left;

  static const _warnAt = Duration(seconds: 30);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<Duration?>(
        valueListenable: left,
        builder: (context, remaining, _) {
          final warn = remaining != null && remaining <= _warnAt;
          final chip = AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.fromLTRB(8, 5, 11, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: warn
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFFF8A00)],
                    ),
              color: warn ? const Color(0xFFD32F2F) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  remaining == null ? Icons.hdr_on_rounded : Icons.timer_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  remaining == null ? 'HDR' : 'HDR · ${_format(remaining)}',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    // Digits keep their width, so the chip does not jitter
                    // as the seconds change.
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          );
          return warn ? _Pulse(child: chip) : chip;
        },
      ),
    );
  }

  static String _format(Duration d) {
    final seconds = d.inSeconds.clamp(0, 99 * 60);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

/// Gentle repeating scale for the last-seconds warning.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.08).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      alignment: Alignment.centerLeft,
      child: widget.child,
    );
  }
}

/// The badge that confirms HDR going on or off.
///
/// Replaces a full-screen blur with a spinner and "Processing…" — which hid
/// the very change the user had asked for, implied work that was not
/// happening (the filter applies instantly), and showed the wrong words: the
/// state had already flipped when it was drawn, so turning HDR on said
/// "Turning off". This one sits small in the middle, leaves the picture
/// visible so the change is seen as it happens, and states the result.
///
/// [visible] drives a fade/scale in and out; keep the widget mounted while it
/// fades so the exit animates too.
class HdrStatusBadge extends StatelessWidget {
  const HdrStatusBadge({
    super.key,
    required this.visible,
    required this.on,
    required this.title,
    required this.subtitle,
  });

  final bool visible;
  final bool on;
  final String title;
  final String subtitle;


  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: visible ? 1 : 0.86,
            duration: const Duration(milliseconds: 320),
            curve: visible ? Curves.easeOutBack : Curves.easeIn,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 20, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: on
                    ? const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFFFF8A00)],
                      )
                    : null,
                color: on ? null : Colors.black.withValues(alpha: 0.72),
                border: Border.all(
                  color: Colors.white.withValues(alpha: on ? 0.35 : 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (on ? const Color(0xFFE91E63) : Colors.black)
                        .withValues(alpha: 0.45),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: on ? 0.22 : 0.10),
                    ),
                    child: Icon(
                      on ? Icons.hdr_on_rounded : Icons.hdr_off_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Capped so the longer expiry notice wraps instead of
                  // overflowing a narrow phone.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A band of light that sweeps once across the video when a filter is
/// picked, so the change is seen happening rather than just appearing.
///
/// Plays each time [trigger] changes (the player bumps a counter). Draws
/// nothing at rest and never takes touches.
class FilterSweep extends StatefulWidget {
  const FilterSweep({super.key, required this.trigger});

  final int trigger;

  @override
  State<FilterSweep> createState() => _FilterSweepState();
}

class _FilterSweepState extends State<FilterSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void didUpdateWidget(covariant FilterSweep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != oldWidget.trigger) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          if (_controller.isDismissed || _controller.isCompleted) {
            return const SizedBox.expand();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _SweepPainter(t),
          );
        },
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  _SweepPainter(this.t);

  /// 0 → 1 across the sweep.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final band = size.width * 0.35;
    // Travels from fully off the left edge to fully off the right.
    final x = -band + (size.width + band * 2) * t;
    final rect = Rect.fromLTWH(x - band, 0, band * 2, size.height);
    // Fades in and out over the run, so it never pops.
    final strength = (1 - (2 * t - 1).abs()).clamp(0.0, 1.0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-1, -0.25),
          end: const Alignment(1, 0.25),
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.32 * strength),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0.2, 0.5, 0.8],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _SweepPainter old) => old.t != t;
}
