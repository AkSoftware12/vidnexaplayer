import 'package:flutter/material.dart';
import 'package:videoplayer/Utils/color.dart';

class PlaybackSpeedDialog {
  static Future<void> show(
    BuildContext context, {
    required double currentSpeed,
    required Function(double) onSpeedChange,
  }) {
    double newSpeed = currentSpeed;
    double originalSpeed = currentSpeed;

    final List<double> options = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0];

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) {
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
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding:  EdgeInsets.only(left: 8.0),
                            child: const Text(
                              "Adjust Speed",
                              style: TextStyle(color: Colors.white, fontSize: 18),
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Minus Button
                              GestureDetector(
                                onTap: () {
                                  newSpeed = (newSpeed - 0.1).clamp(0.1, 3.0);
                                  onSpeedChange(newSpeed);
                                  setDialogState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Speed Text
                              Text(
                                "${newSpeed.toStringAsFixed(1)}x",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(width: 16),

                              // Plus Button
                              GestureDetector(
                                onTap: () {
                                  newSpeed = (newSpeed + 0.1).clamp(0.1, 3.0);
                                  onSpeedChange(newSpeed);
                                  setDialogState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white),
                                ),
                              ),
                            ],
                          ),

                          IconButton(
                            onPressed: () {
                              onSpeedChange(originalSpeed);
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.close, color: Colors.red),
                          ),
                        ],
                      ),

                      // Speed Display
                      // Speed Display with + and - buttons

                      const SizedBox(height: 20),
                      // --- Speed List Tiles ---
                      SizedBox(
                        height: 30,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: options.length,
                          itemBuilder: (context, index) {
                            double speed = options[index];
                            bool isSelected = speed == newSpeed;

                            return GestureDetector(
                              onTap: () {
                                newSpeed = speed;
                                onSpeedChange(speed);
                                setDialogState(() {});
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected ? ColorSelect.maineColor2 : Colors.white10,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? ColorSelect.maineColor2 : Colors.white24,
                                  ),
                                ),
                                child: Center(
                                  child: Row(
                                    children: [
                                      Text(
                                        "${speed.toStringAsFixed(1)}x",
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white70,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 6),
                                          child: Icon(Icons.check_circle, color: Colors.white, size: 18),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Next Speed button (Cycle logic)

                      Slider(
                        value: newSpeed,
                        min: 0.1,
                        max: 3.0,
                        divisions: 25,
                        activeColor: Colors.red,
                        inactiveColor: Colors.white24,
                        onChanged: (v) {
                          newSpeed = v;
                          onSpeedChange(v);
                          setDialogState(() {});
                        },
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // RESET BUTTON
                          GestureDetector(
                            onTap: () {
                              newSpeed = 1.0;
                              onSpeedChange(1.0);
                              setDialogState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ],
                              ),
                              child: const Text(
                                "Reset",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // CANCEL BUTTON
                          GestureDetector(
                            onTap: () {
                              onSpeedChange(originalSpeed);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.6),
                                  width: 1.5,
                                ),
                              ),
                              child: const Text(
                                "Cancel",
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
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
