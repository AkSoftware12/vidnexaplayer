import 'package:flutter/material.dart';

/// Scales its child up from 80% once, when it first appears.
///
/// Lifted out of `lib/Photo/image_album.dart`, which the gallery module
/// replaced, and renamed on the way: it used to be called `AnimatedScale`,
/// which collides with Flutter's own widget of that name. Every file that
/// wanted it had to import `material.dart` with `hide AnimatedScale`, and any
/// file that forgot would silently get the wrong widget.
class ScaleIn extends StatefulWidget {
  const ScaleIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.scale = 1.0,
  });

  final Widget child;
  final Duration duration;

  /// Final scale. The animation always starts at 80% of it.
  final double scale;

  @override
  State<ScaleIn> createState() => _ScaleInState();
}

class _ScaleInState extends State<ScaleIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: widget.duration,
    vsync: this,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 0.8,
    end: widget.scale,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
