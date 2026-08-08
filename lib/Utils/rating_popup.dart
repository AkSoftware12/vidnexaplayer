import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoplayer/Utils/color.dart';

/// In-app rating prompt.
///
/// Timing state (launch count, cooldown, snooze, "don't ask again") is
/// persisted in SharedPreferences, so the gate actually works across launches.
///
/// Behaviour:
///  * shows after [minLaunches] opens
///  * opens with [defaultRating] stars already selected
///  * a dismissal ("Later" / swipe) snoozes for [snoozeDays]
///  * a submitted rating starts a [coolDownDays] cooldown
///  * 4–5 stars sends the user to the Play Store and stops asking afterwards
///  * 1–3 stars opens a private feedback sheet instead
class RatingPopup {
  RatingPopup._();

  // ---- Config ----
  static const String appName = 'Vidnexa';
  static const int minLaunches = 5;
  static const int coolDownDays = 15;
  static const int snoozeDays = 3;
  static const int positiveThreshold = 4;
  static const int defaultRating = 5;
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer';

  /// Hook this up to your analytics / support inbox.
  static Future<void> Function(int rating, String message)? onFeedback;

  // ---- Persisted keys ----
  static const String _kLaunchCount = 'rating_launch_count';
  static const String _kNeverAsk = 'rating_never_ask';
  static const String _kLastShownMs = 'rating_last_shown_ms';
  static const String _kSnoozeUntilMs = 'rating_snooze_until_ms';

  static bool _shownThisSession = false;

  /// Call once per app open (from the splash screen).
  static Future<void> onAppOpen(
      BuildContext context, {
        bool force = false,
      }) async {
    if (_shownThisSession && !force) return;

    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final launchCount = (prefs.getInt(_kLaunchCount) ?? 0) + 1;
    await prefs.setInt(_kLaunchCount, launchCount);

    if (!force) {
      if (prefs.getBool(_kNeverAsk) ?? false) return;
      if (nowMs < (prefs.getInt(_kSnoozeUntilMs) ?? 0)) return;

      final lastShownMs = prefs.getInt(_kLastShownMs) ?? 0;
      final cooldownOver = lastShownMs == 0 ||
          nowMs - lastShownMs >=
              const Duration(days: coolDownDays).inMilliseconds;

      if (launchCount < minLaunches || !cooldownOver) return;
    }

    if (!context.mounted) return;
    _shownThisSession = true;

    final result = await showModalBottomSheet<_RatingResult>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      // Springy entry instead of the default linear-ish slide.
      transitionAnimationController: null,
      builder: (_) => const _RatingSheet(),
    );

    if (result == null) {
      await prefs.setInt(
        _kSnoozeUntilMs,
        nowMs + const Duration(days: snoozeDays).inMilliseconds,
      );
      return;
    }

    await prefs.setInt(_kLastShownMs, nowMs);
    await prefs.setInt(_kLaunchCount, 0);
    await prefs.setInt(_kSnoozeUntilMs, 0);

    final done = result.neverAskAgain || result.rating >= positiveThreshold;
    await prefs.setBool(_kNeverAsk, done);

    if (!context.mounted) return;

    if (result.rating >= positiveThreshold) {
      await _openStore(context);
    } else {
      await _showFeedbackSheet(context, result.rating);
    }
  }

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

  static Future<void> _showFeedbackSheet(BuildContext context, int rating) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => _FeedbackSheet(rating: rating),
    );
  }

  static Future<void> forceShow(BuildContext context) =>
      onAppOpen(context, force: true);

  /// Wipes every stored flag — handy while testing.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_kLaunchCount),
      prefs.remove(_kNeverAsk),
      prefs.remove(_kLastShownMs),
      prefs.remove(_kSnoozeUntilMs),
    ]);
    _shownThisSession = false;
  }
}

class _RatingResult {
  const _RatingResult({required this.rating, required this.neverAskAgain});

  final int rating;
  final bool neverAskAgain;
}

/// Palette derived from `ColorSelect.maineColor`, so changing the brand colour
/// re-themes both sheets.
class _Skin {
  static Color get brand => ColorSelect.maineColor;

  static const Color amber = Color(0xFFFFC043);
  static const Color amberDeep = Color(0xFFF59E0B);
  static const Color onDark = Colors.white;
  static Color get onDarkSub => Colors.white.withValues(alpha: 0.72);
  static Color get onDarkFaint => Colors.white.withValues(alpha: 0.28);

  static List<Color> get gradient {
    final hsl = HSLColor.fromColor(brand);
    return [
      hsl
          .withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0))
          .withSaturation((hsl.saturation + 0.10).clamp(0.0, 1.0))
          .toColor(),
      hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor(),
    ];
  }
}

/// Coloured sheet shell. The gradient slowly drifts and a highlight blob
/// breathes behind the content, so the sheet never looks like a static image.
class _SheetShell extends StatefulWidget {
  const _SheetShell({required this.child});

  final Widget child;

  @override
  State<_SheetShell> createState() => _SheetShellState();
}

class _SheetShellState extends State<_SheetShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final colors = _Skin.gradient;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: AnimatedBuilder(
        animation: _drift,
        builder: (context, child) {
          final t = Curves.easeInOut.transform(_drift.value);
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-1 + (t * 0.6), -1),
                end: Alignment(1, 1 - (t * 0.5)),
                colors: colors,
              ),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: colors.last.withValues(alpha: 0.45),
                  blurRadius: 34,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // Breathing highlight blob.
            Positioned(
              top: -60,
              right: -40,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.15).animate(
                  CurvedAnimation(parent: _drift, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    const SizedBox(height: 18),
                    widget.child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Radiating sparkles, fired when the user lands on 5 stars.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress, required this.seed})
      : super(repaint: null);

  final double progress; // 0 -> 1
  final int seed;

  static const int _count = 14;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rnd = math.Random(seed);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (int i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * math.pi + rnd.nextDouble() * 0.4;
      final distance = (size.width * 0.42) * eased * (0.7 + rnd.nextDouble() * 0.6);
      final offset = center + Offset(math.cos(angle), math.sin(angle)) * distance;

      final paint = Paint()
        ..color = (i.isEven ? _Skin.amber : Colors.white)
            .withValues(alpha: fade * 0.9);

      final r = (2.0 + rnd.nextDouble() * 2.5) * (0.4 + fade);
      canvas.drawCircle(offset, r, paint);
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) =>
      old.progress != progress || old.seed != seed;
}

/// Rating prompt presented as a bottom sheet.
class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet>
    with TickerProviderStateMixin {
  static const int _starCount = 5;

  int _rating = RatingPopup.defaultRating;
  bool _neverAsk = false;
  int _burstSeed = 0;

  late final AnimationController _entrance;
  late final AnimationController _pulse;   // badge halo, loops forever
  late final AnimationController _burst;   // sparkles on 5 stars
  late final AnimationController _shimmer; // CTA light sweep
  late final AnimationController _wiggle;  // star shake on a low rating

  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _badgePop;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.14),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutCubic));
    _badgePop = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.10, 1.0, curve: Curves.elasticOut),
    );

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _wiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _entrance.forward();
    // Celebrate the pre-selected 5 stars right after the sheet settles.
    Future.delayed(const Duration(milliseconds: 480), () {
      if (mounted && _rating == _starCount) _fireBurst();
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _pulse.dispose();
    _burst.dispose();
    _shimmer.dispose();
    _wiggle.dispose();
    super.dispose();
  }

  void _fireBurst() {
    setState(() => _burstSeed = DateTime.now().microsecondsSinceEpoch);
    _burst.forward(from: 0);
  }

  void _setRating(int value) {
    if (value == _rating) return;
    HapticFeedback.selectionClick();
    setState(() => _rating = value);

    if (value == _starCount) {
      _fireBurst();
    } else if (value <= 2) {
      _wiggle.forward(from: 0);
    }
  }

  String get _hint {
    switch (_rating) {
      case 0:
        return 'Tap or slide across the stars';
      case 1:
      case 2:
        return 'Ouch — tell us what went wrong';
      case 3:
        return 'Thanks! How can we do better?';
      case 4:
        return 'Great! Glad you like it';
      default:
        return 'Awesome! Tap a star to change it';
    }
  }

  IconData get _faceIcon {
    if (_rating <= 2) return Icons.sentiment_dissatisfied_rounded;
    if (_rating == 3) return Icons.sentiment_neutral_rounded;
    if (_rating == 4) return Icons.sentiment_satisfied_alt_rounded;
    return Icons.star_rounded;
  }

  /// Badge: pulsing halo ring + a face that morphs with the rating, with a
  /// sparkle burst layered on top.
  Widget _buildBadge() {
    return ScaleTransition(
      scale: _badgePop,
      child: SizedBox(
        width: 150,
        height: 92,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Expanding halo ring, restarts every loop.
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) {
                final v = _pulse.value;
                return Container(
                  width: 68 + (v * 40),
                  height: 68 + (v * 40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: (1 - v) * 0.35),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _burst,
              builder: (context, _) => CustomPaint(
                size: const Size(150, 92),
                painter: _SparklePainter(
                  progress: _burst.value,
                  seed: _burstSeed,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
                  child: RotationTransition(
                    turns: Tween<double>(begin: -0.12, end: 0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                ),
                child: Icon(
                  _faceIcon,
                  key: ValueKey<IconData>(_faceIcon),
                  color: _Skin.amber,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Stars: tap + drag, staggered entrance, pop on fill, and a small shake
  /// when the user picks 1–2.
  Widget _buildStars() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / _starCount;

        void updateFrom(double dx) {
          final index = (dx / slot).floor().clamp(0, _starCount - 1) + 1;
          _setRating(index);
        }

        return Semantics(
          label: 'Rating',
          value: '$_rating out of $_starCount stars',
          slider: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => updateFrom(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => updateFrom(d.localPosition.dx),
            child: AnimatedBuilder(
              animation: _wiggle,
              builder: (context, child) {
                final shake =
                    math.sin(_wiggle.value * math.pi * 4) * (1 - _wiggle.value) * 7;
                return Transform.translate(
                  offset: Offset(shake, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_starCount, (i) {
                  final index = i + 1;
                  final filled = index <= _rating;
                  final start = 0.20 + (i * 0.09);

                  return Expanded(
                    child: FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entrance,
                        curve: Interval(start, (start + 0.4).clamp(0.0, 1.0)),
                      ),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: _entrance,
                          curve: Interval(
                            start,
                            (start + 0.4).clamp(0.0, 1.0),
                            curve: Curves.easeOutBack,
                          ),
                        )),
                        // Scale + tilt gives the fill a satisfying "snap".
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 1, end: filled ? 1.18 : 1),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) => Transform.rotate(
                            angle: filled ? (scale - 1) * 0.35 : 0,
                            child: Transform.scale(scale: scale, child: child),
                          ),
                          child: Icon(
                            filled
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 42,
                            color: filled ? _Skin.amber : _Skin.onDarkFaint,
                            shadows: filled
                                ? [
                              BoxShadow(
                                color: _Skin.amberDeep
                                    .withValues(alpha: 0.55),
                                blurRadius: 14,
                              ),
                            ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  /// White CTA with a light sweep travelling across it.
  Widget _buildCta(bool positive) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(
                context,
                _RatingResult(rating: _rating, neverAskAgain: _neverAsk),
              );
            },
            icon: Icon(
              positive ? Icons.open_in_new_rounded : Icons.send_rounded,
              size: 18,
              color: _Skin.brand,
            ),
            label: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SizeTransition(
                  axis: Axis.horizontal,
                  sizeFactor: anim,
                  child: child,
                ),
              ),
              child: Text(
                positive ? 'Rate on Play Store' : 'Submit',
                key: ValueKey<bool>(positive),
                style: TextStyle(
                  color: _Skin.brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _Skin.brand,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) {
                  return FractionallySizedBox(
                    widthFactor: 0.35,
                    alignment: Alignment(-1.6 + (_shimmer.value * 3.2), 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _Skin.brand.withValues(alpha: 0),
                            _Skin.brand.withValues(alpha: 0.14),
                            _Skin.brand.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final positive = _rating >= RatingPopup.positiveThreshold;

    return _SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBadge(),
          const SizedBox(height: 10),
          FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Rate ${RatingPopup.appName}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _Skin.onDark,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Enjoying the app? A rating really helps us ❤️',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _Skin.onDarkSub, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  _buildStars(),
                  const SizedBox(height: 6),

                  // Hint slides up as it swaps, so the change is noticeable.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      _hint,
                      key: ValueKey<String>(_hint),
                      style: TextStyle(color: _Skin.onDarkSub, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 10),

                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _neverAsk = !_neverAsk),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _neverAsk,
                            onChanged: (v) =>
                                setState(() => _neverAsk = v ?? false),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 1.4,
                            ),
                            activeColor: Colors.white,
                            checkColor: _Skin.brand,
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Don't ask again",
                              style: TextStyle(
                                color: _Skin.onDarkSub,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor:
                            Colors.white.withValues(alpha: 0.14),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                            ),
                          ),
                          child: Text(
                            'Later',
                            style: TextStyle(
                              color: _Skin.onDarkSub,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 3, child: _buildCta(positive)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Feedback sheet for low ratings — same coloured skin, staggered entrance,
/// and it disposes its controller properly.
class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.rating});

  final int rating;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await RatingPopup.onFeedback?.call(widget.rating, _controller.text.trim());
    } catch (_) {
      // Never block the user on a failed report.
    }
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thanks for the feedback!')),
    );
  }

  OutlineInputBorder _border(double alpha, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: Colors.white.withValues(alpha: alpha),
        width: width,
      ),
    );
  }

  /// Each child rises into place slightly after the previous one.
  Widget _stagger(int index, Widget child) {
    final start = (index * 0.12).clamp(0.0, 0.7);
    final curve = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, (start + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(curve),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _stagger(
            0,
            Row(
              children: [
                const Icon(Icons.favorite_rounded, color: _Skin.amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'What can we fix?',
                  style: TextStyle(
                    color: _Skin.onDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _stagger(
            1,
            Text(
              'This goes straight to the team — it is not posted publicly.',
              style: TextStyle(color: _Skin.onDarkSub, fontSize: 12),
            ),
          ),
          const SizedBox(height: 14),
          _stagger(
            2,
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 500,
              autofocus: true,
              cursorColor: Colors.white,
              style: const TextStyle(color: _Skin.onDark, fontSize: 14),
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Playback issues, missing formats, crashes…',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.12),
                counterStyle: TextStyle(color: _Skin.onDarkSub, fontSize: 11),
                border: _border(0.24),
                enabledBorder: _border(0.24),
                focusedBorder: _border(0.85, 1.4),
              ),
            ),
          ),
          const SizedBox(height: 4),
          _stagger(
            3,
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.24),
                        ),
                      ),
                    ),
                    child: Text(
                      'Not now',
                      style: TextStyle(
                        color: _Skin.onDarkSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _sending ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _Skin.brand,
                      disabledBackgroundColor:
                      Colors.white.withValues(alpha: 0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _sending
                          ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _Skin.brand,
                        ),
                      )
                          : Text(
                        'Send feedback',
                        style: TextStyle(
                          color: _Skin.brand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}