import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ✅ Pure Flutter Custom Rating Popup
/// - No native code
/// - No rating package
/// - Play Store open automatically possible nahi (without url_launcher/native)
class RatingPopup {
  RatingPopup._();

  // ---- Config ----
  static const int minLaunches = 5;      // 5 opens ke baad
  static const int coolDownDays = 15;    // 15 din baad dobara
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer';

  // ---- Simple memory (app close -> reset) ----
  static int _launchCount = 0;
  static bool _neverAskAgain = false;
  static DateTime? _lastShown;

  /// ✅ Call this on Splash/Home open
  static void onAppOpen(BuildContext context, {bool force = false}) {
    if (_neverAskAgain && !force) return;

    _launchCount++;

    final now = DateTime.now();
    final canShowByCooldown =
        _lastShown == null || now.difference(_lastShown!).inDays >= coolDownDays;

    final shouldShow = force || (_launchCount >= minLaunches && canShowByCooldown);
    if (!shouldShow) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await showDialog<_RatingResult>(
        context: context,
        barrierDismissible: true,
        builder: (_) => const _RatingDialog(),
      );

      if (result == null) return;

      _lastShown = DateTime.now();
      _neverAskAgain = result.neverAskAgain;

      if (!context.mounted) return;

      if (result.rating >= 4) {
        // ✅ Without url_launcher/native we can't open store automatically.
        // We show a dialog with link + copy.
        _showStoreLinkDialog(context);
      } else {
        _showFeedbackDialog(context);
      }
    });
  }

  static void _showStoreLinkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Thanks for rating ⭐'),
        content: SelectableText(
          'Play Store link:\n$playStoreUrl\n\n(Ye link copy karke browser me paste kar do)',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Copy to clipboard (Flutter built-in)
              await Clipboard.setData(const ClipboardData(text: playStoreUrl));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied ✅')),
                );
              }
            },
            child: const Text('Copy Link'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static void _showFeedbackDialog(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Feedback'),
        content: TextField(
          controller: c,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Kya improve karein? (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final feedback = c.text.trim();
              // TODO: yaha apni API call / save logic laga sakte ho
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    feedback.isEmpty
                        ? 'Thanks! ✅'
                        : 'Thanks! Feedback saved (API add kar lo) ✅',
                  ),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  /// ✅ Test button se force show
  static void forceShow(BuildContext context) {
    onAppOpen(context, force: true);
  }
}

class _RatingResult {
  final int rating;
  final bool neverAskAgain;
  const _RatingResult({required this.rating, required this.neverAskAgain});
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  bool _neverAsk = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF0A1AFF), Color(0xFF010071)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Rate Vidnexa ⭐',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aapko app kaisi lagi? Rating dekar support karein ❤️',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 14),

            // ⭐ Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final index = i + 1;
                final filled = index <= _rating;
                return IconButton(
                  onPressed: () => setState(() => _rating = index),
                  icon: Icon(
                    filled ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 34,
                    color: filled ? Colors.amber : Colors.white70,
                  ),
                );
              }),
            ),

            const SizedBox(height: 6),

            // never ask
            Row(
              children: [
                Checkbox(
                  value: _neverAsk,
                  onChanged: (v) => setState(() => _neverAsk = v ?? false),
                  side: const BorderSide(color: Colors.white70),
                  activeColor: Colors.white,
                  checkColor: const Color(0xFF010071),
                ),
                const Expanded(
                  child: Text(
                    "Don't ask again",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Later',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _rating == 0
                        ? null
                        : () {
                      Navigator.pop(
                        context,
                        _RatingResult(
                          rating: _rating,
                          neverAskAgain: _neverAsk,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      _rating >= 4 ? 'Continue' : 'Submit',
                      style: const TextStyle(
                        color: Color(0xFF010071),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
