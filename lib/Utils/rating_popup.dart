import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:videoplayer/Utils/color.dart';

import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/misc_strings.dart';

/// In-app rating prompt.
///
/// Timing state (launch count, cooldown, snooze, "don't ask again") is
/// persisted in SharedPreferences, so the gate actually works across launches.
///
/// Behaviour:
///  * shows after [minLaunches] opens
///  * a dismissal ("Later" / swipe) snoozes for [snoozeDays]
///  * a submitted rating starts a [coolDownDays] cooldown
///  * 4–5 stars sends the user to the Play Store and never asks again
///  * 1–3 stars opens a private feedback sheet instead
class RatingPopup {
  RatingPopup._();

  // ---- Config ----
  static const String appName = 'Please Rate Vidnexa Player';
  static const int minLaunches = 5;
  static const int coolDownDays = 15;
  static const int snoozeDays = 3;
  static const int positiveThreshold = 4;
  static const int defaultRating = 0; // 0 = nothing pre-selected
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.vidnexa.videoplayer';

  /// Hook this up to your analytics / support inbox.
  static Future<void> Function(int rating, String message)? onFeedback;

  // ---- Persisted keys ----
  static const String _kLaunchCount = 'rating_launch_count';
  static const String _kNeverAsk = 'rating_never_ask';
  static const String _kLastShownMs = 'rating_last_shown_ms';
  static const String _kSnoozeUntilMs = 'rating_snooze_until_ms';
  static const String _kRatedPositive = 'rating_rated_positive';

  static bool _shownThisSession = false;

  /// True once the user has submitted [positiveThreshold]+ stars. Permanent —
  /// not even [forceShow] gets past it.
  static Future<bool> hasRatedPositively() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kRatedPositive) ?? false;
    } catch (_) {
      return false;
    }
  }

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

    // Already rated positively -> never ask again, button included.
    if (prefs.getBool(_kRatedPositive) ?? false) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    final launchCount = (prefs.getInt(_kLaunchCount) ?? 0) + (force ? 0 : 1);
    if (!force) await prefs.setInt(_kLaunchCount, launchCount);

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
      barrierColor: Colors.black.withValues(alpha: 0.72),
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

    final positive = result.rating >= positiveThreshold;

    // Only ever flip these on — a later low rating must not undo them.
    if (positive) {
      await prefs.setBool(_kRatedPositive, true);
      await prefs.setBool(_kNeverAsk, true);
    } else if (result.neverAskAgain) {
      await prefs.setBool(_kNeverAsk, true);
    }

    if (!context.mounted) return;

    if (positive) {
      await openStore(context);
    } else {
      await _showFeedbackSheet(context, result.rating);
    }
  }

  /// Public so a settings entry can send an already-happy user straight to
  /// the store without re-running the rating sheet.
  static Future<void> openStore(BuildContext context) async {
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
      final lang = context.read<LocaleProvider>().locale.languageCode;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(MiscStrings.t(lang, 'rating_playstore_open_failed')),
        ),
      );
    }
  }

  static Future<void> _showFeedbackSheet(BuildContext context, int rating) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
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
      prefs.remove(_kRatedPositive),
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

  static const Color amber = Color(0xFFFFD466);
  static const Color amberDeep = Color(0xFFF59E0B);
  static const Color onDark = Colors.white;
  static Color get onDarkSub => Colors.white.withValues(alpha: 0.70);
  static Color get onDarkFaint => Colors.white.withValues(alpha: 0.26);

  /// Deep night-sky version of the brand colour — dark, saturated, low
  /// lightness so the white type and the amber stars both stay legible.
  static List<Color> get nightGradient {
    final hsl = HSLColor.fromColor(brand);
    return [
      hsl
          .withLightness((hsl.lightness * 0.55).clamp(0.14, 0.34))
          .withSaturation((hsl.saturation + 0.25).clamp(0.0, 1.0))
          .toColor(),
      hsl
          .withLightness((hsl.lightness * 0.28).clamp(0.06, 0.20))
          .withSaturation((hsl.saturation + 0.20).clamp(0.0, 1.0))
          .toColor(),
    ];
  }

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

// ---------------------------------------------------------------------------
// Painters
// ---------------------------------------------------------------------------

/// Interlaced 5-point star drawn as an outline (pentagram + outer polygon).
class _StarMarkPainter extends CustomPainter {
  _StarMarkPainter({required this.progress});

  /// 0 -> 1, used to draw the mark on and to fade the glow in.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 4;

    final pts = List<Offset>.generate(5, (i) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      return c + Offset(math.cos(a), math.sin(a)) * r;
    });

    // Pentagram: connect every second point.
    const order = [0, 2, 4, 1, 3];
    final star = Path()..moveTo(pts[order[0]].dx, pts[order[0]].dy);
    for (var i = 1; i < order.length; i++) {
      star.lineTo(pts[order[i]].dx, pts[order[i]].dy);
    }
    star.close();

    // Outer pentagon, kept faint so the star reads first.
    final pentagon = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      pentagon.lineTo(pts[i].dx, pts[i].dy);
    }
    pentagon.close();

    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = Colors.white.withValues(alpha: 0.30 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawPath(
      pentagon,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.22 * progress),
    );

    canvas.drawPath(
      star,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white.withValues(alpha: 0.92 * progress),
    );
  }

  @override
  bool shouldRepaint(_StarMarkPainter old) => old.progress != progress;
}

/// Slow sweeping halo behind the content — the light "swoosh" in the design.
class _AuraPainter extends CustomPainter {
  _AuraPainter({required this.turn, required this.intensity});

  final double turn; // 0 -> 1, one full rotation
  final double intensity; // 0 -> 1

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final c = Offset(size.width * 0.5, size.height * 0.46);
    final radius = size.width * 0.58;
    final rect = Rect.fromCircle(center: c, radius: radius);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(turn * 2 * math.pi);
    canvas.translate(-c.dx, -c.dy);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: 0),
          Colors.white.withValues(alpha: 0.10 * intensity),
          Colors.white.withValues(alpha: 0.34 * intensity),
          Colors.white.withValues(alpha: 0.06 * intensity),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.22, 0.44, 0.72, 1.0],
      ).createShader(rect)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);

    canvas.drawArc(rect, 0, math.pi * 1.55, false, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.turn != turn || old.intensity != intensity;
}

/// Radiating sparkles, fired when the user lands on 5 stars.
class _SparklePainter extends CustomPainter {
  _SparklePainter({required this.progress, required this.seed});

  final double progress; // 0 -> 1
  final int seed;

  static const int _count = 18;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final center = Offset(size.width / 2, size.height / 2);
    final rnd = math.Random(seed);
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0);

    for (var i = 0; i < _count; i++) {
      final angle = (i / _count) * 2 * math.pi + rnd.nextDouble() * 0.4;
      final distance =
          (size.width * 0.40) * eased * (0.7 + rnd.nextDouble() * 0.6);
      final offset =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;

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

// ---------------------------------------------------------------------------
// Rating sheet
// ---------------------------------------------------------------------------

/// Swipe-to-rate sheet: drag the thumb across the track to pick 1–5 stars,
/// the star arc below reacts, then confirm.
class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet>
    with TickerProviderStateMixin {
  static const int _starCount = 5;
  static const double _thumbSize = 46;
  static const double _trackPad = 6;

  int _rating = RatingPopup.defaultRating;
  bool _neverAsk = false;
  bool _touched = false;
  int _burstSeed = 0;

  late final AnimationController _entrance;
  late final AnimationController _aura; // sweeping halo, loops
  late final AnimationController _nudge; // "swipe me" hint on the thumb
  late final AnimationController _burst; // sparkles on 5 stars
  late final AnimationController _shimmer; // CTA light sweep

  late final Animation<double> _fade;
  late final Animation<double> _markDraw;

  @override
  void initState() {
    super.initState();

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _markDraw = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    );

    _aura = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _nudge = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _burst = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _aura.dispose();
    _nudge.dispose();
    _burst.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  void _fireBurst() {
    setState(() => _burstSeed = DateTime.now().microsecondsSinceEpoch);
    _burst.forward(from: 0);
  }

  void _setRating(int value) {
    if (!_touched) {
      _touched = true;
      _nudge.stop();
    }
    if (value == _rating) return;

    HapticFeedback.selectionClick();
    setState(() => _rating = value);
    if (value == _starCount) _fireBurst();
  }

  String _hint(String lang) {
    switch (_rating) {
      case 0:
        return MiscStrings.t(lang, 'rating_hint_0');
      case 1:
      case 2:
        return MiscStrings.t(lang, 'rating_hint_low');
      case 3:
        return MiscStrings.t(lang, 'rating_hint_mid');
      case 4:
        return MiscStrings.t(lang, 'rating_hint_good');
      default:
        return MiscStrings.t(lang, 'rating_hint_great');
    }
  }

  // -------------------------------------------------------------------------
  // Swipe track
  // -------------------------------------------------------------------------

  Widget _buildTrack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final span = constraints.maxWidth - (_trackPad * 2) - _thumbSize;

        void updateFrom(double localDx) {
          final dx = (localDx - _trackPad - (_thumbSize / 2)).clamp(0.0, span);
          _setRating((dx / span * _starCount).round().clamp(0, _starCount));
        }

        final progress = _rating / _starCount;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => updateFrom(d.localPosition.dx),
          onHorizontalDragStart: (d) => updateFrom(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => updateFrom(d.localPosition.dx),
          onHorizontalDragEnd: (_) => HapticFeedback.lightImpact(),
          child: Semantics(
            label: 'Rating',
            value: '$_rating out of $_starCount stars',
            slider: true,
            child: Container(
              height: _thumbSize + (_trackPad * 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Stack(
                children: [
                  // Filled portion behind the thumb.
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      width: _trackPad +
                          (_thumbSize / 2) +
                          (span * progress) +
                          (_thumbSize / 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(40),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.04),
                            _Skin.amber.withValues(alpha: 0.28 * progress),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Arrow at the far end, fades out as the thumb approaches.
                  Positioned(
                    right: 22,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 220),
                        opacity: (1 - progress).clamp(0.0, 1.0) * 0.9,
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white.withValues(alpha: 0.85),
                          size: 24,
                        ),
                      ),
                    ),
                  ),

                  // Thumb.
                  AnimatedBuilder(
                    animation: _nudge,
                    builder: (context, child) {
                      // Gentle right-ward nudge until the user touches it.
                      final n = _touched
                          ? 0.0
                          : math.sin(_nudge.value * math.pi * 2).clamp(0.0, 1.0) *
                          10;
                      return AnimatedPositioned(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutBack,
                        left: _trackPad + (span * progress) + n,
                        top: _trackPad,
                        child: child!,
                      );
                    },
                    child: Container(
                      width: _thumbSize,
                      height: _thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.94),
                        boxShadow: [
                          BoxShadow(
                            color: _Skin.amberDeep.withValues(alpha: 0.35),
                            blurRadius: 18,
                          ),
                        ],
                      ),
                      child: Icon(
                        _rating == 0
                            ? Icons.touch_app_rounded
                            : Icons.star_rounded,
                        color: _rating == 0 ? _Skin.brand : _Skin.amberDeep,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Star arc
  // -------------------------------------------------------------------------

  Widget _buildStarArc() {
    return SizedBox(
      height: 130,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / _starCount;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Sparkles centred on the arc.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _burst,
                    builder: (context, _) => CustomPaint(
                      painter: _SparklePainter(
                        progress: _burst.value,
                        seed: _burstSeed,
                      ),
                    ),
                  ),
                ),
              ),

              ...List.generate(_starCount, (i) {
                final index = i + 1;
                final t = (i - 2) / 2.0; // -1 .. 1
                final dip = 38.0 * (1 - (t * t)); // centre sits lowest
                final filled = index <= _rating;
                final active = index == _rating;

                // Staggered entrance, outer stars first.
                final start = (0.35 + (i * 0.07)).clamp(0.0, 0.85);
                final curve = CurvedAnimation(
                  parent: _entrance,
                  curve: Interval(
                    start,
                    (start + 0.3).clamp(0.0, 1.0),
                    curve: Curves.easeOutBack,
                  ),
                );

                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutBack,
                  left: slot * i,
                  width: slot,
                  top: 18 + dip - (active ? 10 : 0),
                  child: FadeTransition(
                    opacity: curve,
                    child: ScaleTransition(
                      scale: curve,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setRating(index),
                        child: Transform.rotate(
                          angle: t * 0.32,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 1,
                              end: active ? 1.34 : (filled ? 1.08 : 0.92),
                            ),
                            duration: const Duration(milliseconds: 320),
                            curve: Curves.elasticOut,
                            builder: (context, scale, child) =>
                                Transform.scale(scale: scale, child: child),
                            child: Icon(
                              Icons.star_rounded,
                              size: 44,
                              color: filled
                                  ? _Skin.amber
                                  : Colors.white.withValues(alpha: 0.30),
                              shadows: filled
                                  ? [
                                BoxShadow(
                                  color: _Skin.amberDeep
                                      .withValues(alpha: 0.60),
                                  blurRadius: 20,
                                ),
                              ]
                                  : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Confirm
  // -------------------------------------------------------------------------

  Widget _buildConfirm(String lang) {
    final positive = _rating >= RatingPopup.positiveThreshold;

    if (_rating == 0) {
      return SizedBox(
        height: 52,
        child: Center(
          child: AnimatedBuilder(
            animation: _nudge,
            builder: (context, child) => Opacity(
              opacity: 0.45 + (math.sin(_nudge.value * math.pi * 2) * 0.25),
              child: child,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  MiscStrings.t(lang, 'rating_pick_stars'),
                  style: TextStyle(color: _Skin.onDarkSub, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Icon(Icons.auto_awesome, size: 16, color: _Skin.onDarkSub),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
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
              child: Text(
                positive
                    ? MiscStrings.t(lang, 'rating_cta_playstore')
                    : MiscStrings.t(lang, 'rating_cta_feedback'),
                key: ValueKey<bool>(positive),
                style: TextStyle(
                  color: _Skin.brand,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: _Skin.brand,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              minimumSize: const Size.fromHeight(52),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _shimmer,
                builder: (context, _) => FractionallySizedBox(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleProvider>().locale.languageCode;
    final colors = _Skin.nightGradient;
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(34),
            ),
          ),
          child: Stack(
            children: [
              // Ambient halo.
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_aura, _entrance]),
                    builder: (context, _) => CustomPaint(
                      painter: _AuraPainter(
                        turn: _aura.value,
                        intensity: _entrance.value,
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.30),
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                      const SizedBox(height: 26),

                      // Star mark.
                      AnimatedBuilder(
                        animation: _markDraw,
                        builder: (context, _) => CustomPaint(
                          size: const Size(96, 96),
                          painter: _StarMarkPainter(progress: _markDraw.value),
                        ),
                      ),
                      const SizedBox(height: 22),

                      FadeTransition(
                        opacity: _fade,
                        child: Column(
                          children: [

                            Text(
                              '${MiscStrings.t(lang, 'rating_popup_title')}?',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _Skin.onDark,
                                fontSize: 27,
                                fontWeight: FontWeight.bold,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 2),


                            Padding(
                              padding: const EdgeInsets.only(left: 50.0,right: 50),
                              child: Text(
                                MiscStrings.t(lang, 'rating_popup_subtitle'),
                                style: TextStyle(
                                  color: _Skin.onDark.withValues(alpha: 0.92),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 2.4,

                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      _buildTrack(),
                      const SizedBox(height: 12),

                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.4),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _hint(lang),
                          key: ValueKey<String>(_hint(lang)),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _Skin.onDarkSub,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      _buildStarArc(),

                      _buildConfirm(lang),
                      const SizedBox(height: 4),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              MiscStrings.t(lang, 'rating_later'),
                              style: TextStyle(
                                color: _Skin.onDarkSub,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _neverAsk = !_neverAsk),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _neverAsk
                                        ? Icons.check_box_rounded
                                        : Icons.check_box_outline_blank_rounded,
                                    size: 18,
                                    color: _neverAsk
                                        ? Colors.white
                                        : _Skin.onDarkFaint,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    MiscStrings.t(lang, 'rating_never_ask'),
                                    style: TextStyle(
                                      color: _Skin.onDarkSub,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
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

// ---------------------------------------------------------------------------
// Feedback sheet
// ---------------------------------------------------------------------------

/// Coloured sheet shell used by the feedback sheet.
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
    final colors = _Skin.nightGradient;

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

/// Feedback sheet for low ratings.
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
    final lang = context.read<LocaleProvider>().locale.languageCode;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(MiscStrings.t(lang, 'feedback_sent_snackbar'))),
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
    final lang = context.watch<LocaleProvider>().locale.languageCode;
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
                Text(
                  MiscStrings.t(lang, 'feedback_title'),
                  style: const TextStyle(
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
              MiscStrings.t(lang, 'feedback_subtitle'),
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
                hintText: MiscStrings.t(lang, 'feedback_hint'),
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
                      MiscStrings.t(lang, 'feedback_not_now'),
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
                        MiscStrings.t(lang, 'rating_cta_feedback'),
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
