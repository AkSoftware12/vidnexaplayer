import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// How long to keep a detached [Player] alive before releasing it.
///
/// Sized for media_kit's `widListener`, which is what this whole file exists
/// for: it makes five sequential `setProperty` MethodChannel round-trips and
/// then a `seek`. A second is far more than that needs even on a slow device,
/// and the player is already detached from the widget tree and paused by then,
/// so the only cost is holding one idle mpv context a moment longer.
const Duration _kDisposeGrace = Duration(seconds: 1);

/// Releases a media_kit [Player] without tripping media_kit's own
/// disposed-player assertion.
///
/// ## Why this is not just `player.dispose()`
///
/// Tearing down a video surface — popping the player route, removing the
/// floating-window overlay — destroys the Android platform view, which changes
/// `wid`. That fires media_kit's `AndroidVideoController.widListener`, and the
/// last thing that listener does is:
///
/// ```dart
/// final currentPosition = player.state.position;
/// await player.seek(currentPosition);
/// ```
///
/// (`media_kit_video/…/android_video_controller/real.dart`) — with no check
/// that the player is still alive. The listener is serialized behind a lock and
/// awaits several MethodChannel round-trips before it gets there, so it is
/// still in flight while our own `dispose()` runs on the same frame.
///
/// Disposing synchronously therefore lands that `seek` on a dead player and
/// throws `Assertion failed: "[Player] has been disposed"`. Nothing in the app
/// can catch it: it is thrown inside media_kit's own async zone, so it goes
/// straight to `FlutterError.onError` — which main.dart wires to
/// `recordFlutterFatalError`, putting it in Crashlytics as a **fatal** even
/// though the process survives.
///
/// Ordering cannot fix this from app code. media_kit registers the controller's
/// teardown via `player.platform.release.add(controller._dispose)`, so the
/// listener is only unregistered *during* `player.dispose()` — by which point
/// the queued listener has already captured its reference.
///
/// So the player is kept alive for [_kDisposeGrace] and released afterwards.
/// It is paused first, so the extra second is silent rather than a second of
/// audio playing on after the user closed the video.
///
/// Safe to call on an already-disposed player: both steps swallow their errors.
void disposePlayerSafely(Player player) {
  // Immediate, so closing the video stops the sound now. Without this the
  // grace period below would be audible.
  try {
    unawaited(player.pause().catchError((Object _) {}));
  } catch (_) {
    // Already disposed by whoever else held it.
  }

  Timer(_kDisposeGrace, () async {
    try {
      await player.dispose();
    } catch (error) {
      // Already gone, or mpv tore itself down first. Either way there is
      // nothing left to release.
      debugPrint('disposePlayerSafely: dispose failed: $error');
    }
  });
}
