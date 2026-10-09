import 'package:material_ui/material_ui.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'floting_video.dart';
import 'system_pip.dart';

/// Wraps the whole app (from `MaterialApp.builder`) so that, in Android's PiP
/// window, only the floating video is shown — full-window, on black.
///
/// The app itself stays mounted (navigation, players and state all survive),
/// but it is laid out at its last full-screen size and not painted. Laying it
/// out at the tiny PiP size instead would overflow nearly every screen and
/// report each overflow to Crashlytics.
///
/// The tree shape never changes between modes — only parameters do — so
/// entering or leaving PiP never rebuilds the app from scratch.
class PipHost extends StatefulWidget {
  const PipHost({super.key, required this.child});

  final Widget child;

  @override
  State<PipHost> createState() => _PipHostState();
}

class _PipHostState extends State<PipHost> {
  Size? _fullSize;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SystemPip.instance.inPip,
      builder: (context, inPip, _) {
        final media = MediaQuery.of(context);
        if (!inPip) _fullSize = media.size;

        final VideoController? controller =
            inPip ? FloatingVideoManager.controller : null;
        final Size? hold = controller != null ? _fullSize : null;

        return Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: hold != null,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: hold?.width,
                maxWidth: hold?.width,
                minHeight: hold?.height,
                maxHeight: hold?.height,
                child: MediaQuery(
                  data: hold == null ? media : media.copyWith(size: hold),
                  child: widget.child,
                ),
              ),
            ),
            if (controller != null)
              ColoredBox(
                color: Colors.black,
                child: Video(controller: controller, controls: null),
              ),
          ],
        );
      },
    );
  }
}
