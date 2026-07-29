import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoplayer/Utils/color.dart';

/// In-app rating prompt.
///
/// Everything it needs to decide *when* to ask is now persisted. Previously the
/// launch counter, cooldown and "don't ask again" flag lived in plain static
/// fields that reset on every launch, so `_launchCount >= minLaunches` was never
/// true and the dialog literally never appeared.
class RatingPopup {
  RatingPopup._();

  // ---- Config ----
  static const int minLaunches = 5;
  static const int coolDownDays = 15;
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer';

  // ---- Persisted keys ----
  static const String _kLaunchCount = 'rating_launch_count';
  static const String _kNeverAsk = 'rating_never_ask';
  static const String _kLastShownMs = 'rating_last_shown_ms';

  /// Guards against two prompts racing in the same session.
  static bool _shownThisSession = false;

  /// Call once per app open (from the splash screen).
  static Future<void> onAppOpen(BuildContext context, {bool force = false}) async {
    if (_shownThisSession && !force) return;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }

    if (!force && (prefs.getBool(_kNeverAsk) ?? false)) return;

    final launchCount = (prefs.getInt(_kLaunchCount) ?? 0) + 1;
    await prefs.setInt(_kLaunchCount, launchCount);

    final lastShownMs = prefs.getInt(_kLastShownMs) ?? 0;
    final cooldownOk = lastShownMs == 0 ||
        DateTime.now()
                .difference(DateTime.fromMillisecondsSinceEpoch(lastShownMs))
                .inDays >=
            coolDownDays;

    final shouldShow = force || (launchCount >= minLaunches && cooldownOk);
    if (!shouldShow) return;

    if (!context.mounted) return;
    _shownThisSession = true;

    final result = await showModalBottomSheet<_RatingResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const _RatingSheet(),
    );

    // Dismissed without choosing — ask again next time, don't burn the cooldown.
    if (result == null) return;

    await prefs.setInt(_kLastShownMs, DateTime.now().millisecondsSinceEpoch);
    await prefs.setBool(_kNeverAsk, result.neverAskAgain);
    // Reset the counter so the cooldown alone governs the next prompt.
    await prefs.setInt(_kLaunchCount, 0);

    if (!context.mounted) return;

    if (result.rating >= 4) {
      await _openStore(context);
    } else {
      await _showFeedbackDialog(context);
    }
  }

  /// Opens the Play Store listing directly.
  ///
  /// The old version claimed this was impossible "without url_launcher" and made
  /// the user copy-paste a link — `url_launcher` has always been a dependency.
  static Future<void> _openStore(BuildContext context) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(playStoreUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the Play Store')),
      );
    }
  }

  static Future<void> _showFeedbackDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => const _FeedbackDialog(),
    );
  }

  /// For a debug/test button.
  static Future<void> forceShow(BuildContext context) =>
      onAppOpen(context, force: true);
}

class _RatingResult {
  const _RatingResult({required this.rating, required this.neverAskAgain});

  final int rating;
  final bool neverAskAgain;
}

/// Rating prompt presented as a bottom sheet (slides up from the bottom of the
/// home screen).
class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  bool _neverAsk = false;

  // Brand + neutral palette for the white sheet.
  static const Color _ink = Color(0xFF111827); // near-black text
  static const Color _sub = Color(0xFF6B7280); // muted grey text
  static final Color _brand = ColorSelect.maineColor; // purple accent
  static const Color _amber = Color(0xFFF59E0B);

  // Entrance animation: badge pops, content fades + rises.
  late final AnimationController _entrance;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _badgePop;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _badgePop = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.15, 1.0, curve: Curves.elasticOut),
    );
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// A short helper caption that reacts to the chosen star count.
  String get _hint {
    switch (_rating) {
      case 0:
        return 'Tap a star to rate';
      case 1:
      case 2:
        return 'Ouch — tell us what went wrong';
      case 3:
        return 'Thanks! How can we do better?';
      case 4:
        return 'Great! Glad you like it';
      default:
        return 'Awesome! You’re the best 🎉';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Respect the on-screen keyboard / gesture inset so buttons stay reachable.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 30,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              const SizedBox(height: 18),

              // Badge (springy pop-in)
              ScaleTransition(
                scale: _badgePop,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _brand.withValues(alpha: 0.10),
                    border: Border.all(color: _brand.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: _amber,
                    size: 36,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Everything below fades + rises together.
              FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Rate Vidnexa',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Enjoying the app? A rating really helps us ❤️',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _sub, fontSize: 13),
                      ),
                      const SizedBox(height: 18),

                      // ⭐ Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final index = i + 1;
                          final filled = index <= _rating;
                          return IconButton(
                            onPressed: () => setState(() => _rating = index),
                            tooltip: '$index star${index == 1 ? '' : 's'}',
                            icon: AnimatedScale(
                              scale: filled ? 1.18 : 1.0,
                              duration: const Duration(milliseconds: 160),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 40,
                                color: filled
                                    ? _amber
                                    : const Color(0xFFCBD5E1),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _hint,
                        style: const TextStyle(color: _sub, fontSize: 12),
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Checkbox(
                            value: _neverAsk,
                            onChanged: (v) =>
                                setState(() => _neverAsk = v ?? false),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            activeColor: _brand,
                            checkColor: Colors.white,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const Expanded(
                            child: Text(
                              "Don't ask again",
                              style: TextStyle(color: _sub, fontSize: 12),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                              ),
                              child: const Text(
                                'Later',
                                style: TextStyle(
                                  color: _sub,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _rating == 0
                                  ? null
                                  : () => Navigator.pop(
                                        context,
                                        _RatingResult(
                                          rating: _rating,
                                          neverAskAgain: _neverAsk,
                                        ),
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                disabledBackgroundColor:
                                    const Color(0xFFCBD5E1),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: Text(
                                _rating >= 4 ? 'Continue' : 'Submit',
                                style: const TextStyle(
                                  color: Colors.white,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Feedback sheet for low ratings.
///
/// Made a StatefulWidget purely so its [TextEditingController] gets disposed —
/// the old version created one inside a builder and leaked it every time.
class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog();

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Feedback'),
      content: TextField(
        controller: _controller,
        maxLines: 4,
        decoration: const InputDecoration(
          hintText: 'What could we improve? (optional)',
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
            // TODO: forward `_controller.text` to a feedback endpoint.
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thanks for the feedback!')),
            );
          },
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
