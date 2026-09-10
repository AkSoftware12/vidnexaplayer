import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../NotifyListeners/LanguageProvider/language_provider.dart';
import '../NotifyListeners/LanguageProvider/paywall_strings.dart';
import 'billing_service.dart';

/// The premium paywall.
///
/// Deliberately a **fixed dark violet surface**, not theme-aware like the rest
/// of the app: a paywall is a moment, not a screen you live in, and committing
/// to one rich palette is what lets it read as expensive. It is the only screen
/// in the app that opts out of [AppPalette].
///
/// **Every charged amount comes from `ProductDetails`.** Play returns it already
/// formatted for the user's billing country; a hardcoded `₹249` would be wrong
/// in the other ~172 countries these products sell in.
///
/// ## The struck-through "compare at" price
///
/// The crossed-out figure beside each price is **not** a price Play ever
/// charged. It is a marketing anchor the app owner asked for
/// ([_kCompareAtMultiplier]), derived from the real price so it stays in the
/// right currency instead of showing "$1499" to a US buyer.
///
/// This is a deliberate product decision, made after the alternative was
/// offered: Play Console supports real discount offers, and
/// `BillingService.yearlyOriginalPrice` / `yearlyDiscountPercent` already read
/// them, so setting a genuine base price plus an offer would produce the same
/// visual from real data. Until that exists, note that showing a price the
/// product was never sold at is deceptive pricing under Google Play's policy
/// and carries suspension risk. Prefer the real-offer path when it is available.
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  /// Pushes the paywall, named so the analytics observer can report it.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PaywallScreen(),
        settings: const RouteSettings(name: 'PaywallScreen'),
      ),
    );
  }

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

// ─────────────────────────────────────────────────────────────────────────────
//  Palette
// ─────────────────────────────────────────────────────────────────────────────

class _P {
  _P._();

  static const Color bg = Color(0xFF0A0616);
  static const Color bgMid = Color(0xFF150B2B);

  static const Color violet = Color(0xFF8B5CF6);
  static const Color blue = Color(0xFF3B82F6);
  static const Color pink = Color(0xFFEC4899);

  /// The app's brand gold, reused here as the accent on top of the violet.
  ///
  /// Same values as the gold PRO buttons in the drawer and the home app bar,
  /// so the paywall reads as the destination those buttons promise rather than
  /// an unrelated screen. Violet carries the surface, gold carries everything
  /// the user is meant to look at: the crown, the badge, the selected plan and
  /// the CTA.
  static const Color gold = Color(0xFFFFB800);
  static const Color goldDeep = Color(0xFFFF8C00);

  static const LinearGradient goldGrad = LinearGradient(
    colors: [gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color textHi = Color(0xFFF8FAFC);
  static const Color textMid = Color(0xFFC7C3D4);
  static const Color textLo = Color(0xFF8B849F);

  /// Frosted panel fill. Kept low so the ambient glows read through it.
  static Color get glass => Colors.white.withValues(alpha: 0.055);
  static Color get glassBorder => Colors.white.withValues(alpha: 0.11);

  /// Gold, not violet, for the CTA. Against a violet field gold is the higher
  /// contrast of the two, and it matches the PRO buttons the user tapped to
  /// get here.
  static const LinearGradient cta = LinearGradient(
    colors: [Color(0xFFFFC53D), gold, goldDeep],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static TextStyle t(
    double size, {
    FontWeight w = FontWeight.w500,
    Color color = textMid,
    double spacing = 0,
    double height = 1.25,
  }) =>
      TextStyle(
        fontFamily: 'Outfit',
        fontSize: size,
        fontWeight: w,
        color: color,
        letterSpacing: spacing,
        height: height,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Plan view-model
// ─────────────────────────────────────────────────────────────────────────────

/// What the real price is multiplied by to produce the struck-through figure.
///
/// Chosen so India lands on the numbers the owner asked for: ₹199 → ₹1,499 and
/// ₹249 → ₹1,899, both snapped to a `…99` ending by [_compareAtAmount]. Every
/// other currency scales by the same factor rather than showing a rupee amount.
///
/// See the class doc on [PaywallScreen] before changing or relying on this.
const double _kCompareAtMultiplier = 7.53;

enum _PlanKind { monthly, yearly, lifetime }

/// Everything a [_PlanCard] needs, resolved from a real [ProductDetails].
///
/// Built only for products Play actually returned, so a plan that does not
/// exist in Play Console simply never becomes a card — no placeholder price, no
/// buy button that fails.
class _PlanVm {
  const _PlanVm({
    required this.kind,
    required this.product,
    required this.title,
    required this.period,
    required this.blurb,
    this.badge,
    this.savingPercent,
    this.originalPrice,
    this.footnote,
  });

  final _PlanKind kind;
  final ProductDetails product;
  final String title;
  final String period;
  final String blurb;
  final String? badge;

  /// Percentage off the standing price, from [BillingService.yearlyDiscountPercent].
  /// Null unless Play reports a live discount offer — never a fabricated number.
  final int? savingPercent;

  /// The standing price to strike through, from Play. Null when the user is
  /// paying the standing price and there is nothing to strike.
  final String? originalPrice;

  /// Secondary line under the price, e.g. the yearly plan's monthly equivalent.
  final String? footnote;

  bool get isSubscription => kind != _PlanKind.lifetime;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  final BillingService _billing = BillingService.instance;

  /// One controller drives every continuous animation on the page — the drifting
  /// background, the halo behind the crown, the badge shimmer and the CTA
  /// shine. Separate controllers for each would schedule four independent
  /// tickers for what is visually one slow pulse.
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  /// Lifetime by default: it is the better deal for the user, the higher-value
  /// one for the app, and it is the card listed first.
  _PlanKind _selected = _PlanKind.lifetime;
  bool _restoring = false;
  late bool _wasPremium = _billing.isPremium;

  @override
  void initState() {
    super.initState();
    _billing.addListener(_onBillingChanged);
    if (_billing.yearly == null && _billing.lifetime == null) {
      _billing.loadProducts();
    }
  }

  @override
  void dispose() {
    _billing.removeListener(_onBillingChanged);
    _ambient.dispose();
    super.dispose();
  }

  void _onBillingChanged() {
    if (!mounted) return;
    setState(() {});
    final bool premium = _billing.isPremium;
    if (premium && !_wasPremium) {
      _toast(PaywallStrings.t(_lang, 'paywall_thanks'));
    }
    _wasPremium = premium;
  }

  /// `read`, not `watch`: also reached from [_onBillingChanged], which runs
  /// outside `build`. [build] registers the locale dependency separately.
  String get _lang => context.read<LocaleProvider>().locale.languageCode;

  String _t(String key) => PaywallStrings.t(_lang, key);

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: _P.t(13, color: _P.textHi)),
          backgroundColor: const Color(0xFF241541),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ── Plans ───────────────────────────────────────────────────────────────

  /// The plans Play actually returned — **Lifetime first**, then Yearly.
  ///
  /// Lifetime leads because it is the pre-selected option: the badge, the tick
  /// and the CTA price should all point at the same card without the user
  /// having to look around for which one is chosen.
  List<_PlanVm> get _plans {
    final List<_PlanVm> out = <_PlanVm>[];

    final ProductDetails? lifetime = _billing.lifetime;
    final ProductDetails? yearly = _billing.yearly;

    if (lifetime != null) {
      out.add(_PlanVm(
        kind: _PlanKind.lifetime,
        product: lifetime,
        title: _t('paywall_plan_lifetime'),
        period: '',
        blurb: _t('paywall_pay_once'),
        badge: _t('paywall_badge_best_value'),
        originalPrice: _compareAtPrice(lifetime),
        savingPercent: _compareAtPercent(lifetime),
      ));
    }

    if (yearly != null) {
      out.add(_PlanVm(
        kind: _PlanKind.yearly,
        product: yearly,
        title: _t('paywall_plan_yearly'),
        period: _t('paywall_per_year'),
        blurb: _t('paywall_plan_yearly_sub'),
        // A real Play discount offer wins when one exists; otherwise the
        // configured compare-at anchor is used. See the class doc.
        originalPrice:
            _billing.yearlyOriginalPrice ?? _compareAtPrice(yearly),
        savingPercent:
            _billing.yearlyDiscountPercent ?? _compareAtPercent(yearly),
        footnote: _perMonth(yearly),
      ));
    }

    return out;
  }

  _PlanVm? get _selectedPlan {
    final list = _plans;
    if (list.isEmpty) return null;
    for (final p in list) {
      if (p.kind == _selected) return p;
    }
    return list.first;
  }

  /// A yearly price divided by twelve, formatted like the real price.
  ///
  /// Symbol *and its placement* are read off `price` itself — `₹199.00` is a
  /// prefix currency, `199,00 €` a suffix one, and guessing wrong looks broken
  /// outside India. Null when the shape can't be read: showing nothing beats
  /// showing a mangled amount.
  String? _perMonth(ProductDetails p) {
    if (p.rawPrice <= 0) return null;
    final String? money = _formatLike(p, (p.rawPrice / 12).toStringAsFixed(2));
    if (money == null) return null;
    return _t('paywall_per_month').replaceAll('{price}', money);
  }

  /// Formats [amount] with the same currency symbol and placement as [p].
  ///
  /// The symbol *and which side it sits on* are read off `p.price` itself —
  /// `₹199.00` is a prefix currency, `199,00 €` a suffix one, and guessing
  /// wrong looks broken outside India. Null when the shape can't be read:
  /// showing nothing beats showing a mangled amount.
  String? _formatLike(ProductDetails p, String amount) {
    final String formatted = p.price.trim();
    final RegExpMatch? m = RegExp(r'[\d.,\s]*\d').firstMatch(formatted);
    if (m == null) return null;

    final String prefix = formatted.substring(0, m.start).trim();
    final String suffix = formatted.substring(m.end).trim();

    if (prefix.isNotEmpty) return '$prefix$amount';
    if (suffix.isNotEmpty) return '$amount$suffix';
    return null;
  }

  /// The marketing anchor: the real price scaled up and snapped to a `…99`
  /// ending, which is what makes ₹199 read as ₹1,499 rather than ₹1,498.47.
  ///
  /// NOT a Play price — see the class doc on [PaywallScreen].
  double _compareAtAmount(ProductDetails p) {
    final double raw = p.rawPrice * _kCompareAtMultiplier;
    return ((raw / 100).ceil() * 100) - 1;
  }

  String? _compareAtPrice(ProductDetails p) {
    if (p.rawPrice <= 0) return null;
    return _formatLike(p, _compareAtAmount(p).toStringAsFixed(0));
  }

  int? _compareAtPercent(ProductDetails p) {
    if (p.rawPrice <= 0) return null;
    final double was = _compareAtAmount(p);
    if (was <= p.rawPrice) return null;
    return (((was - p.rawPrice) / was) * 100).round();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _buy() async {
    switch (_selectedPlan?.kind) {
      case _PlanKind.lifetime:
        await _billing.purchaseLifetime();
      case _PlanKind.yearly:
        await _billing.purchaseYearly();
      case _PlanKind.monthly:
        await _billing.purchaseMonthly();
      case null:
        return;
    }
    final String? error = _billing.lastError;
    if (error != null) _toast(error);
  }

  Future<void> _restore() async {
    setState(() => _restoring = true);
    await _billing.restore();
    if (!mounted) return;
    setState(() => _restoring = false);

    if (_billing.lastError != null) {
      _toast(_billing.lastError!);
    } else if (!_billing.isPremium) {
      _toast(_t('paywall_restore_none'));
    } else {
      _toast(_t('paywall_restore_ok'));
    }
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // A missing browser is not worth an error dialog on a paywall.
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final bool premium = _billing.isPremium;

    return Scaffold(
      backgroundColor: _P.bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _P.textMid, size: 24),
          tooltip: _t('paywall_close'),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _Ambient(t: _ambient)),
          SafeArea(
            top: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Tablets get the plans side by side; phones stack them. The
                // threshold is the width at which three cards still leave room
                // for a readable price, not a device category.
                final bool wide = constraints.maxWidth >= 620;
                final double hPad = wide ? 32 : 20;

                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          // Status bar only, not the full app-bar height.
                          //
                          // The bar holds one left-aligned close button and
                          // nothing else, and the crown is centred — they
                          // never overlap horizontally, so reserving a whole
                          // toolbar below it was just dead space at the top of
                          // the page. The first full-width element (the title)
                          // still lands below the button.
                          MediaQuery.paddingOf(context).top + 6,
                          hPad,
                          12,
                        ),
                        children: [
                          _Header(t: _ambient, lang: _lang),
                          const SizedBox(height: 16),
                          if (premium)
                            _activeState()
                          else ...[
                            // Benefits above the plans: sell the value first,
                            // then ask for the money.
                            _BenefitsSection(lang: _lang),
                            const SizedBox(height: 16),
                            _planSection(wide),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    if (!premium && _plans.isNotEmpty) _bottomBar(hPad),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Sections ────────────────────────────────────────────────────────────

  Widget _planSection(bool wide) {
    if (_billing.isLoadingProducts && _plans.isEmpty) {
      return const _PlanSkeletons();
    }
    if (_plans.isEmpty) return _storeUnavailable();

    final List<Widget> cards = [
      for (final plan in _plans)
        _PlanCard(
          plan: plan,
          selected: _selected == plan.kind,
          wide: wide,
          t: _ambient,
          onTap: () => setState(() => _selected = plan.kind),
        ),
    ];

    return Column(
      children: [
        if (_billing.hasPendingPurchase) ...[
          _pendingNotice(),
          const SizedBox(height: 16),
        ],
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          )
        else
          Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                cards[i],
              ],
            ],
          ),
      ],
    );
  }

  Widget _activeState() {
    return Column(
      children: [
        _planStatusCard(),
        const SizedBox(height: 16),
        _BenefitsSection(lang: _lang),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _billing.openManageSubscriptions(),
          icon: const Icon(Icons.open_in_new_rounded,
              size: 16, color: _P.textMid),
          label: Text(
            _t('paywall_manage_sub'),
            style: _P.t(13, w: FontWeight.w600, color: _P.textMid),
          ),
        ),
      ],
    );
  }

  /// What the user currently owns, and when it ends.
  ///
  /// The date is derived (see [BillingService.subscriptionPeriodEnd]) and is
  /// worded as "renews on" / "access until" rather than as a guaranteed expiry,
  /// because the client has no authoritative expiry to quote.
  Widget _planStatusCard() {
    final bool lifetime = _billing.ownsLifetime;
    final DateTime? ends = _billing.subscriptionPeriodEnd;
    final bool renewing = _billing.subscriptionAutoRenewing;

    final String detail;
    if (lifetime) {
      detail = _t('paywall_lifetime_active');
    } else if (ends != null) {
      detail = _t(renewing ? 'paywall_renews_on' : 'paywall_expires_on')
          .replaceAll('{date}', _formatDate(ends));
    } else {
      // Premium is on but Play has not been re-queried yet (offline launch on
      // the cached flag). Better to say nothing than to invent a date.
      detail = '';
    }

    return _Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      borderColor: _P.gold.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: _P.goldGrad,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_rounded,
                color: Colors.white, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('paywall_plan_active'),
                  style: _P.t(11, w: FontWeight.w600, color: _P.textLo),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: _P.t(14, w: FontWeight.w800, color: _P.gold),
                  ),
                ],
                // Only when the user has cancelled: says plainly that access
                // continues to the date above rather than ending now.
                if (!lifetime && ends != null && !renewing) ...[
                  const SizedBox(height: 4),
                  Text(
                    _t('paywall_cancelled_note'),
                    style: _P.t(11, color: _P.textMid),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Date in the user's own locale — `9 Sept 2027` in en, `९ सित॰ २०२७` in hi.
  String _formatDate(DateTime d) =>
      DateFormat.yMMMd(_lang).format(d.toLocal());

  // ── Bottom bar ──────────────────────────────────────────────────────────

  Widget _bottomBar(double hPad) {
    final _PlanVm? plan = _selectedPlan;

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 8),
      decoration: BoxDecoration(
        // Fades up into the page instead of butting against it with a line.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_P.bg.withValues(alpha: 0), _P.bg, _P.bg],
          stops: const [0, 0.35, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CtaButton(
            t: _ambient,
            label: _t('paywall_cta'),
            price: plan?.product.price,
            busy: _billing.isPurchaseInFlight,
            onTap: plan == null ? null : _buy,
          ),
          const SizedBox(height: 10),

          // Renewal wording only where it is true. "Cancel anytime" under a
          // one-time purchase is nonsense and generates refund requests.
          Text(
            plan == null || plan.isSubscription
                ? '${_t('paywall_cancel_anytime_short')} • ${_t('paywall_secure_short')}'
                : '${_t('paywall_no_renewal_short')} • ${_t('paywall_secure_short')}',
            textAlign: TextAlign.center,
            style: _P.t(11, color: _P.textLo),
          ),
          const SizedBox(height: 6),
          _legalRow(),
        ],
      ),
    );
  }

  Widget _legalRow() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _linkButton(
          _restoring ? '…' : _t('paywall_restore'),
          _restoring ? null : _restore,
          strong: true,
        ),
        _dot(),
        _linkButton(
          _t('paywall_terms_link'),
          () => _open('https://play.google.com/about/play-terms/'),
        ),
        _dot(),
        _linkButton(
          _t('paywall_privacy_link'),
          () => _open(
            'https://www.freeprivacypolicy.com/live/'
            '3a47e749-0364-44f5-8cc3-559f2cd90336',
          ),
        ),
      ],
    );
  }

  Widget _dot() => Text('  •  ', style: _P.t(10, color: _P.textLo));

  Widget _linkButton(String label, VoidCallback? onTap, {bool strong = false}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          label,
          style: _P.t(
            11,
            w: strong ? FontWeight.w700 : FontWeight.w500,
            color: strong ? _P.textMid : _P.textLo,
          ),
        ),
      ),
    );
  }

  // ── States ──────────────────────────────────────────────────────────────

  Widget _pendingNotice() {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.all(14),
      borderColor: _P.violet.withValues(alpha: 0.4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: _P.violet, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('paywall_pending_title'),
                  style: _P.t(13, w: FontWeight.w700, color: _P.textHi),
                ),
                const SizedBox(height: 3),
                Text(
                  _t('paywall_pending_body'),
                  style: _P.t(11, color: _P.textMid),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _storeUnavailable() {
    return _Glass(
      radius: 20,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: _P.textLo, size: 34),
          const SizedBox(height: 12),
          Text(
            _t('paywall_unavailable_title'),
            style: _P.t(15, w: FontWeight.w700, color: _P.textHi),
          ),
          const SizedBox(height: 6),
          Text(
            _t('paywall_unavailable_body'),
            textAlign: TextAlign.center,
            style: _P.t(12, color: _P.textMid),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _billing.isLoadingProducts
                ? null
                : () async {
                    await _billing.loadProducts();
                    await _billing.restore();
                  },
            child: Text(
              _t('paywall_retry'),
              style: _P.t(13, w: FontWeight.w700, color: _P.gold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ambient background
// ─────────────────────────────────────────────────────────────────────────────

/// Slow-drifting colour blobs behind everything.
///
/// Radial gradients, not `ImageFilter.blur`: a blur layer behind a scrolling
/// list repaints every frame and is the easiest way to make a page janky on a
/// mid-range phone. A [RadialGradient] with a transparent outer stop gives the
/// same falloff for one shader, and the whole layer is under [RepaintBoundary]
/// so its animation never repaints the content above it.
class _Ambient extends StatelessWidget {
  const _Ambient({required this.t});

  final Animation<double> t;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: t,
          builder: (context, _) {
            final double a = t.value * 2 * math.pi;
            return Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [_P.bgMid, _P.bg, _P.bg],
                        stops: [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
                _blob(
                  dx: -70 + math.sin(a) * 18,
                  dy: -110 + math.cos(a) * 14,
                  size: 340,
                  color: _P.violet,
                  alpha: 0.34,
                ),
                _blob(
                  dx: 210 + math.cos(a * 0.8) * 20,
                  dy: 60 + math.sin(a * 0.8) * 16,
                  size: 300,
                  color: _P.blue,
                  alpha: 0.22,
                ),
                _blob(
                  dx: -40 + math.sin(a * 0.6) * 14,
                  dy: 460 + math.cos(a * 0.6) * 18,
                  size: 300,
                  color: _P.pink,
                  alpha: 0.15,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _blob({
    required double dx,
    required double dy,
    required double size,
    required Color color,
    required double alpha,
  }) {
    return Positioned(
      left: dx,
      top: dy,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.t, required this.lang});

  final Animation<double> t;
  final String lang;

  @override
  Widget build(BuildContext context) {
    // Same frosted panel as the benefits card, so the page reads as two
    // matching surfaces on the violet field rather than one floating block of
    // text and one card.
    return _Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
      children: [
        // Halo + crown. The halo pulses off the shared ambient controller
        // rather than its own ticker.
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: t,
            builder: (context, child) {
              final double pulse =
                  0.5 + 0.5 * math.sin(t.value * 2 * math.pi);
              return Container(
                width: 92,
                height: 92,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _P.gold.withValues(alpha: 0.30 + 0.18 * pulse),
                      _P.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: child,
              );
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: _P.goldGrad,
                boxShadow: [
                  BoxShadow(
                    color: _P.gold.withValues(alpha: 0.45),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(Icons.workspace_premium_rounded,
                  color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          PaywallStrings.t(lang, 'paywall_hero_title'),
          textAlign: TextAlign.center,
          style: _P.t(24, w: FontWeight.w800, color: _P.textHi, height: 1.1),
        ),
        const SizedBox(height: 5),
        Text(
          PaywallStrings.t(lang, 'paywall_hero_sub'),
          textAlign: TextAlign.center,
          style: _P.t(12.5, color: _P.textMid, height: 1.35),
        ),
      ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Plan card
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.wide,
    required this.t,
    required this.onTap,
  });

  final _PlanVm plan;
  final bool selected;
  final bool wide;
  final Animation<double> t;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        // Small on purpose: a card that jumps draws attention to the animation
        // rather than to the choice being made.
        scale: selected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      _P.gold.withValues(alpha: 0.20),
                      _P.violet.withValues(alpha: 0.20),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : _P.glass,
            border: Border.all(
              color: selected
                  ? _P.gold.withValues(alpha: 0.90)
                  : _P.glassBorder,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: _P.gold.withValues(alpha: 0.30),
                      blurRadius: 26,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: wide ? _wideBody() : _rowBody(),
        ),
      ),
    );
  }

  // Phones: radio + name/blurb on the left, price on the right.
  Widget _rowBody() {
    return Row(
      children: [
        _radio(),
        const SizedBox(width: 13),
        Expanded(child: _titleBlock()),
        const SizedBox(width: 10),
        _priceBlock(CrossAxisAlignment.end),
      ],
    );
  }

  // Tablets: stacked, since three cards share the row.
  Widget _wideBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _radio(),
            const SizedBox(width: 10),
            Expanded(child: _badgeOrSpace()),
          ],
        ),
        const SizedBox(height: 14),
        _titleBlock(hideBadge: true),
        const SizedBox(height: 14),
        _priceBlock(CrossAxisAlignment.start),
      ],
    );
  }

  Widget _badgeOrSpace() => plan.badge == null
      ? const SizedBox.shrink()
      : Align(
          alignment: Alignment.centerRight,
          child: _ShimmerBadge(t: t, label: plan.badge!),
        );

  Widget _radio() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _P.gold : Colors.transparent,
        border: Border.all(
          color: selected ? _P.gold : Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }

  Widget _titleBlock({bool hideBadge = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                plan.title,
                style: _P.t(16, w: FontWeight.w800, color: _P.textHi),
              ),
            ),
            if (!hideBadge && plan.badge != null) ...[
              const SizedBox(width: 8),
              _ShimmerBadge(t: t, label: plan.badge!),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(plan.blurb, style: _P.t(12, color: _P.textMid)),

        // Only rendered when a real comparison exists — see [_PlanVm].
        if (plan.savingPercent != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              '${plan.savingPercent}% OFF',
              style: _P.t(10,
                  w: FontWeight.w800,
                  color: const Color(0xFF34D399),
                  spacing: 0.6),
            ),
          ),
        ],
      ],
    );
  }

  Widget _priceBlock(CrossAxisAlignment align) {
    final bool discounted = plan.originalPrice != null;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The struck-through standing price, only when Play actually reports a
        // live discount offer. See [_PlanVm.originalPrice].
        if (discounted)
          Text(
            plan.originalPrice!,
            style: _P.t(12, color: _P.textLo).copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: _P.textLo,
              decorationThickness: 1.6,
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Gold on the amount the user pays, so the eye lands on it before
            // the period or the footnote.
            Text(
              plan.product.price,
              style: _P.t(
                selected ? 23 : 21,
                w: FontWeight.w800,
                color: selected ? _P.gold : _P.textHi,
              ),
            ),
            if (plan.period.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(plan.period, style: _P.t(11, color: _P.textLo)),
              ),
          ],
        ),
        if (plan.footnote != null) ...[
          const SizedBox(height: 2),
          Text(plan.footnote!, style: _P.t(11, color: _P.textLo)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Benefits
// ─────────────────────────────────────────────────────────────────────────────

class _BenefitsSection extends StatelessWidget {
  const _BenefitsSection({required this.lang});

  final String lang;

  static const List<(IconData, String)> _items = [
    (Icons.block_rounded, 'paywall_benefit_no_ads'),
    (Icons.four_k_rounded, 'paywall_benefit_uhd'),
    (Icons.tune_rounded, 'paywall_benefit_controls'),
    (Icons.headphones_rounded, 'paywall_benefit_background'),
    (Icons.auto_awesome_rounded, 'paywall_benefit_all'),
    (Icons.rocket_launch_rounded, 'paywall_benefit_updates'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            PaywallStrings.t(lang, 'paywall_benefits_title'),
            style: _P.t(15, w: FontWeight.w800, color: _P.textHi),
          ),
        ),
        // One benefit per row, each label on a single line.
        //
        // Six full-width rows cost roughly 130dp more than the paired layout,
        // so the hero and the section gaps above were tightened to pay for it —
        // otherwise the Yearly card slides back under the pinned CTA and the
        // user can only see one of the two plans they are choosing between.
        _Glass(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              for (int i = 0; i < _items.length; i++)
                _BenefitTile(
                  icon: _items[i].$1,
                  label: PaywallStrings.t(lang, _items[i].$2),
                  index: i,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One benefit row, with a staggered fade+slide entrance.
///
/// Uses a one-shot [TweenAnimationBuilder] rather than a controller per row:
/// six controllers would mean six tickers alive for a 300 ms entrance.
class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.label,
    required this.index,
  });

  final IconData icon;
  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 360 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                gradient: LinearGradient(
                  colors: [
                    _P.gold.withValues(alpha: 0.26),
                    _P.goldDeep.withValues(alpha: 0.14),
                  ],
                ),
              ),
              child: Icon(icon, size: 15, color: _P.gold),
            ),
            const SizedBox(width: 11),
            // One line, always: an ellipsis is better than a benefit that
            // silently wraps and pushes the plan cards down the page.
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _P.t(13, w: FontWeight.w600, color: _P.textHi),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.check_rounded, size: 16, color: _P.gold),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared pieces
// ─────────────────────────────────────────────────────────────────────────────

/// Frosted panel. A plain translucent fill plus a hairline border — no
/// BackdropFilter, for the repaint reason described on [_Ambient].
class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    required this.radius,
    required this.padding,
    this.borderColor,
  });

  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _P.glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? _P.glassBorder),
      ),
      child: child,
    );
  }
}

/// "BEST VALUE" pill with a light sweep across it.
class _ShimmerBadge extends StatelessWidget {
  const _ShimmerBadge({required this.t, required this.label});

  final Animation<double> t;
  final String label;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: t,
        builder: (context, child) {
          // Sweep runs across, then rests — a continuous sweep reads as a
          // loading indicator rather than a highlight.
          final double p = (t.value * 2).clamp(0.0, 1.0);
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0),
              ],
              stops: [
                (p - 0.25).clamp(0.0, 1.0),
                p.clamp(0.0, 1.0),
                (p + 0.25).clamp(0.0, 1.0),
              ],
            ).createShader(rect),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: _P.goldGrad,
          ),
          child: Text(
            label,
            style: _P.t(9.5,
                w: FontWeight.w800, color: Colors.white, spacing: 0.7),
          ),
        ),
      ),
    );
  }
}

/// Full-width gradient CTA with a shine sweep and a press-scale.
class _CtaButton extends StatefulWidget {
  const _CtaButton({
    required this.t,
    required this.label,
    required this.price,
    required this.busy,
    required this.onTap,
  });

  final Animation<double> t;
  final String label;
  final String? price;
  final bool busy;
  final VoidCallback? onTap;

  @override
  State<_CtaButton> createState() => _CtaButtonState();
}

class _CtaButtonState extends State<_CtaButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    // "Busy" and "disabled" are deliberately separate.
    //
    // Folding them together dimmed the whole button to 50% and dropped its
    // glow the moment it was pressed, so the button appeared to fade out just
    // as the progress started — it read as the button disappearing rather than
    // working. Busy keeps the button at full strength and only swaps its
    // contents; only a genuinely unavailable product dims it.
    final bool hasProduct = widget.onTap != null;
    final bool tappable = hasProduct && !widget.busy;

    return GestureDetector(
      onTapDown: tappable ? (_) => setState(() => _down = true) : null,
      onTapUp: tappable ? (_) => setState(() => _down = false) : null,
      onTapCancel: tappable ? () => setState(() => _down = false) : null,
      onTap: tappable ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Opacity(
          opacity: hasProduct ? 1 : 0.5,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              gradient: _P.cta,
              borderRadius: BorderRadius.circular(18),
              boxShadow: hasProduct
                  ? [
                      BoxShadow(
                        color: _P.gold.withValues(alpha: 0.40),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Idle shine only — it would fight the progress bar.
                if (tappable)
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: widget.t,
                      builder: (context, _) {
                        final double p = widget.t.value;
                        return FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: 1,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.white.withValues(alpha: 0),
                                ],
                                stops: [
                                  (p - 0.18).clamp(0.0, 1.0),
                                  p.clamp(0.0, 1.0),
                                  (p + 0.18).clamp(0.0, 1.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // Busy state fills the whole button, not a small spinner
                // floating in the middle of it: the button is what the user
                // just pressed, so the button is what should look busy.
                // Busy: a spinner in place of the label, on a button that
                // stays fully gold and fully lit. The label and price go away;
                // the button itself does not.
                if (widget.busy)
                  const SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      // Dark on gold — a white spinner is barely visible here.
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF2A1A00)),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.price == null
                          ? widget.label
                          : '${widget.label}  ·  ${widget.price}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // Near-black, not white: white on gold fails contrast.
                      style: _P.t(16,
                          w: FontWeight.w800,
                          color: const Color(0xFF2A1A00)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Placeholder cards while Play is still answering.
class _PlanSkeletons extends StatelessWidget {
  const _PlanSkeletons();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < 2; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          Container(
            height: 86,
            decoration: BoxDecoration(
              color: _P.glass,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _P.glassBorder),
            ),
          ),
        ],
      ],
    );
  }
}
