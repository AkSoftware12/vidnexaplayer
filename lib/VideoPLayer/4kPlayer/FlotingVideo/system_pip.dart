import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Android's system picture-in-picture, driven by the floating player.
///
/// The floating player is a Flutter overlay, so on its own it vanishes the
/// moment the app is left. While it is showing, [setEnabled] tells the
/// activity to drop into a PiP window instead (see PipController.kt), and
/// [inPip] flips so the overlay can fill that window with just the video.
class SystemPip {
  SystemPip._() {
    _channel.setMethodCallHandler(_onCall);
  }
  static final SystemPip instance = SystemPip._();

  static const MethodChannel _channel =
      MethodChannel('com.vidnexa.videoplayer/pip');

  /// True while the activity is in Android's PiP window.
  final ValueNotifier<bool> inPip = ValueNotifier<bool>(false);

  /// Called when the user closes the PiP window with its ✕ (rather than
  /// expanding it back into the app).
  VoidCallback? onDismissed;

  /// Arms or disarms PiP-on-leave. [width]/[height] give the window's shape —
  /// the video's own size when known.
  Future<void> setEnabled(bool enabled, {int width = 16, int height = 9}) async {
    try {
      await _channel.invokeMethod<bool>('setEnabled', {
        'enabled': enabled,
        'width': width,
        'height': height,
      });
    } catch (_) {
      // No PiP on this platform/device: the floating player still works
      // inside the app, exactly as before.
    }
  }

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'pipChanged':
        inPip.value = call.arguments == true;
      case 'pipDismissed':
        // Native tells closing apart from expanding (onStop vs onResume) —
        // guessing from Flutter's lifecycle after a delay paused the video
        // on the way back into the app too.
        onDismissed?.call();
    }
  }
}
