import 'package:flutter/material.dart';

import '../../../../Utils/color.dart';

/// Animated mic button — idle vs listening (pulsing ripple rings), built on
/// plain `AnimationController`/`Stack` so the feature doesn't need a new
/// animation package.
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.isListening, required this.onTap});

  final bool isListening;
  final VoidCallback onTap;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isListening ? Colors.redAccent : ColorSelect.maineColor;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 160,
        height: 160,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isListening) ..._ripples(color),
                child!,
              ],
            );
          },
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 20, spreadRadius: 4),
              ],
            ),
            child: Icon(
              widget.isListening ? Icons.mic : Icons.mic_none_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _ripples(Color color) {
    return List.generate(2, (i) {
      final t = (_controller.value + (i * 0.5)) % 1.0;
      final size = 84 + t * 70;
      return Opacity(
        opacity: ((1 - t) * 0.5).clamp(0.0, 0.5),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        ),
      );
    });
  }
}
