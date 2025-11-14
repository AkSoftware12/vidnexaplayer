import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:media_kit/media_kit.dart';
import 'package:volume_controller/volume_controller.dart';

class VolumeGestureController {
  // External player
  final Player player;

  // Smooth values
  double systemVolume = 0.5;       // device volume (0–1)
  double playerVolume = 0.5;       // player volume (0–2, with boost)
  double boost = 1.0;              // 1.0 = normal, 2.0 = 200%

  // Overlay visibility
  bool showVolumeOverlay = false;
  Timer? _overlayTimer;

  // Vertical drag side
  bool isRightSide = false;

  // Volume controller (singleton from package)
  late VolumeController _volumeCtrl;

  // Callback to rebuild UI
  final VoidCallback refresh;

  VolumeGestureController({
    required this.player,
    required this.refresh,
  }) {
    _init();
  }

  Future<void> _init() async {
    // ✅ Correct way per package docs: VolumeController.instance
    _volumeCtrl = VolumeController.instance;
    _volumeCtrl.showSystemUI = false;

    // Get current system volume
    final v = await _volumeCtrl.getVolume();
    systemVolume = v;
    playerVolume = systemVolume;

    refresh();
  }

  // Call on vertical drag start from main widget
  void onVerticalDragStart(DragStartDetails details, BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;

    // Only right side controls volume
    isRightSide = dx > width * 0.65;
  }

  // Call on vertical drag update
  Future<void> onVerticalDragUpdate(DragUpdateDetails details) async {
    if (!isRightSide) return;

    final delta = -details.delta.dy / 400; // smooth factor

    // Update system volume 0–1
    systemVolume = (systemVolume + delta).clamp(0.0, 1.0);

    // Player volume with boost (0–2)
    playerVolume = (systemVolume * boost).clamp(0.0, 2.0);

    // Apply both
    await _volumeCtrl.setVolume(systemVolume);
    await player.setVolume(playerVolume);

    // Show overlay
    showVolumeOverlay = true;
    refresh();

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 800), () {
      showVolumeOverlay = false;
      refresh();
    });
  }

  void onVerticalDragEnd(DragEndDetails details) {
    isRightSide = false;
  }

  // Boost toggle: 100% → 150% → 200% → back to 100%
  void toggleBoost() {
    if (boost == 1.0) {
      boost = 1.5;
    } else if (boost == 1.5) {
      boost = 2.0;
    } else {
      boost = 1.0;
    }

    playerVolume = (systemVolume * boost).clamp(0.0, 2.0);
    player.setVolume(playerVolume);

    refresh();
  }

  // Volume Overlay UI (MX Player style vertical bar)
  Widget buildOverlay(BuildContext context) {
    if (!showVolumeOverlay) return const SizedBox.shrink();

    return Positioned(
      right: 20,
      top: MediaQuery.of(context).size.height * 0.18,
      child: Container(
        width: 30.sp,
        height: MediaQuery.of(context).size.height * 0.55,
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volume_up,
              color: Colors.greenAccent,
              size: 22.sp,
            ),
            SizedBox(height: 8),
            Expanded(
              child: RotatedBox(
                quarterTurns: -1,
                child: Slider(
                  value: playerVolume.clamp(0.0, 2.0),
                  min: 0,
                  max: 2.0,
                  onChanged: (v) async {
                    // Auto adjust boost based on slider position
                    if (systemVolume <= 0.0) {
                      systemVolume = 0.01; // avoid divide-by-zero
                    }
                    boost = (v / systemVolume).clamp(1.0, 2.0);
                    playerVolume = v;

                    // Compute back system volume in 0–1
                    final sys = (playerVolume / boost).clamp(0.0, 1.0);

                    await _volumeCtrl.setVolume(sys);
                    await player.setVolume(playerVolume);

                    systemVolume = sys;
                    refresh();
                  },
                  activeColor: Colors.greenAccent,
                  inactiveColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void dispose() {
    _overlayTimer?.cancel();
    // If you ever add a listener via _volumeCtrl.addListener(),
    // then you should call:
    // _volumeCtrl.removeListener();
  }
}
