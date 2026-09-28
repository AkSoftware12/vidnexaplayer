import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoActivityIndicator;
import 'package:material_ui/material_ui.dart';

import 'color.dart';

/// A slowly rotating activity indicator in the app's accent colour.
///
/// Lifted out of `lib/Photo/image_album.dart` so the WhatsApp status saver can
/// keep using it after the gallery module replaced that file.
class AnimatedProgressIndicator extends StatefulWidget {
  const AnimatedProgressIndicator({super.key, this.radius = 25});

  final double radius;

  @override
  State<AnimatedProgressIndicator> createState() =>
      _AnimatedProgressIndicatorState();
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: CupertinoActivityIndicator(
        radius: widget.radius,
        color: ColorSelect.maineColor,
        animating: true,
      ),
    );
  }
}
