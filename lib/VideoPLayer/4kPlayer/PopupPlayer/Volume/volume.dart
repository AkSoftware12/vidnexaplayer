import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../NotifyListeners/LanguageProvider/language_provider.dart';
import '../../../../NotifyListeners/LanguageProvider/video_strings.dart';

class VolumeDialog {
  /// Unified volume + boost control.
  ///
  /// The slider runs on a single 0.05..[maxBoost] scale where everything up to
  /// 1.0 is the DEVICE volume and anything above it is software gain applied by
  /// the player. Keeping both on one track is what makes the control feel like
  /// MX Player: the user just keeps dragging and the meaning changes at 100%.
  ///
  /// [currentBoost] / [onBoostChange] are in PERCENT (100 = normal, 300 = 3x).
  /// If [boostEnabled] is false the whole boost range is simply unavailable and
  /// the dialog behaves exactly like the old one.
  static Future<void> show(
      BuildContext context, {
        required double currentVolume, // 0..1 (device)
        required Function(double) onVolumeChange,
        double currentBoost = 100, // 100..maxBoost*100
        double maxBoostPercent = 300,
        bool boostEnabled = false,
        Function(double)? onBoostChange,
      }) {
    final bool canBoost = boostEnabled && onBoostChange != null;
    final double maxValue = canBoost ? maxBoostPercent / 100.0 : 1.0;

    final lang =
        Provider.of<LocaleProvider>(context, listen: false).locale.languageCode;
    String t(String key) => VideoStrings.t(lang, key);

    // Combined value: 0.05..1.0 = device, 1.0..maxValue = boost.
    // Start from whichever stage the player is currently in.
    double combined = currentBoost > 100.5 ? currentBoost / 100.0 : currentVolume;

    final double originalVolume = currentVolume;
    final double originalBoost = currentBoost;

    // --- ALWAYS SAFE VOLUME (never < 0.05, never > maxValue)
    double safe(double v) {
      if (v <= 0.05) return 0.05;
      if (v >= maxValue) return maxValue;
      return double.parse(v.toStringAsFixed(2)); // fix rounding
    }

    /// Splits the combined value back into the two things it drives.
    ///
    /// Device volume is pinned at 100% for the whole boost range — otherwise
    /// raising the boost would fight the hardware slider and the result would
    /// not be monotonic.
    void apply(double c) {
      final device = c >= 1.0 ? 1.0 : c;
      onVolumeChange(device);

      if (canBoost) {
        final boost = c <= 1.0 ? 100.0 : c * 100.0;
        onBoostChange(boost);
      }
    }

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      barrierLabel: "",
      pageBuilder: (context, anim1, anim2) {
        bool isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        double dialogWidth = isLandscape
            ? MediaQuery.of(context).size.width * 0.55 // landscape fix
            : MediaQuery.of(context).size.width * 0.95; // portrait default

        return Center(
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final bool boosting = combined > 1.0;
              final Color accent =
              boosting ? const Color(0xFFFF8A00) : Colors.red;

              return Material(
                color: Colors.transparent,
                child: Container(
                  width: dialogWidth,
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
                          Row(
                            children: [
                              Text(
                                boosting ? t('volume_boost_title') : t('volume_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (boosting) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  child: Text(
                                    t('volume_boost_badge'),
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.redAccent),
                            onPressed: () {
                              onVolumeChange(originalVolume);
                              if (canBoost) onBoostChange(originalBoost);
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
                              combined = safe(combined - 0.05);
                              apply(combined);
                              setDialogState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child:
                              const Icon(Icons.remove, color: Colors.white),
                            ),
                          ),

                          const SizedBox(width: 20),

                          Text(
                            "${(combined * 100).toInt()}%",
                            style: TextStyle(
                              color: boosting ? accent : Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(width: 20),

                          // Plus
                          GestureDetector(
                            onTap: () {
                              combined = safe(combined + 0.05);
                              apply(combined);
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
                        value: combined.clamp(0.05, maxValue),
                        min: 0.05,
                        max: maxValue,
                        // 0.05 steps across whatever range is available
                        divisions: ((maxValue - 0.05) / 0.05).round(),
                        activeColor: accent,
                        inactiveColor: Colors.white24,
                        onChanged: (value) {
                          combined = safe(value);
                          apply(combined);
                          setDialogState(() {});
                        },
                      ),

                      // ---------------- Hint / warning ----------------
                      if (canBoost)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            combined > 2.0
                                ? t('volume_hint_distort')
                                : boosting
                                ? t('volume_hint_max_gain')
                                : t('volume_hint_drag_boost'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: combined > 2.0
                                  ? Colors.orangeAccent
                                  : Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                        ),

                      const SizedBox(height: 10),

                      // ---------------- Reset / Cancel ----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () {
                              // Reset means "100%, no boost" — not max slider.
                              combined = 1.0;
                              apply(1.0);
                              setDialogState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                t('common_reset'),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 15),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          GestureDetector(
                            onTap: () {
                              onVolumeChange(originalVolume);
                              if (canBoost) onBoostChange(originalBoost);
                              Navigator.pop(context);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent,
                                  width: 1.3,
                                ),
                              ),
                              child: Text(
                                t('common_cancel'),
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 15),
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