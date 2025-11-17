import 'package:flutter/material.dart';

class VolumeDialog {
  static Future<void> show(
      BuildContext context, {
        required double currentVolume,
        required Function(double) onVolumeChange,
      }) {
    double newVolume = currentVolume;
    double originalVolume = currentVolume;

    // --- ALWAYS SAFE VOLUME (Never < 0.05)
    double safe(double v) {
      if (v <= 0.05) return 0.05;
      if (v >= 1.0) return 1.0;
      return double.parse(v.toStringAsFixed(2));   // fix rounding
    }

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      barrierLabel: "",
      pageBuilder: (context, anim1, anim2) {
        bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

        double dialogWidth = isLandscape
            ? MediaQuery.of(context).size.width * 0.55   // landscape fix
            : MediaQuery.of(context).size.width * 0.95;  // portrait default
        return Center(
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Material(
                color: Colors.transparent,
                child: Container(
                  width:dialogWidth,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // ---------------- Header ----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Volume",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                            onPressed: () {
                              onVolumeChange(originalVolume);
                              Navigator.pop(context);
                            },
                          )
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ---------------- +/- Buttons ----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Minus
                          GestureDetector(
                            onTap: () {
                              newVolume = safe(newVolume - 0.05);
                              onVolumeChange(newVolume);
                              setDialogState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.remove, color: Colors.white),
                            ),
                          ),

                          const SizedBox(width: 20),

                          Text(
                            "${(newVolume * 100).toInt()}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Plus
                          GestureDetector(
                            onTap: () {
                              newVolume = safe(newVolume + 0.05);
                              onVolumeChange(newVolume);
                              setDialogState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add, color: Colors.white),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // ---------------- Slider ----------------
                      Slider(
                        value: newVolume,
                        min: 0.05,
                        max: 1.0,
                        divisions: 19,
                        activeColor: Colors.red,
                        inactiveColor: Colors.white24,
                        onChanged: (value) {
                          newVolume = safe(value);
                          onVolumeChange(newVolume);
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 10),

                      // ---------------- Reset / Cancel ----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              newVolume = 1.0;
                              onVolumeChange(1.0);
                              setDialogState(() {});
                            },
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: const Text(
                                "Reset",
                                style: TextStyle(color: Colors.white, fontSize: 15),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          GestureDetector(
                            onTap: () {
                              onVolumeChange(originalVolume);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent,
                                  width: 1.3,
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(color: Colors.redAccent, fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
