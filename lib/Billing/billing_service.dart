import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// The app's single Google Play Billing layer.
///
/// A [ChangeNotifier] singleton rather than a per-subtree provider: the ad
/// manager and `main()` both have to read the entitlement from outside the
/// widget tree (`AppOpenAdManager` is not a widget, and the ad SDK is
/// initialised before `runApp`'s tree exists), so a value that only lives in an
/// `InheritedWidget` would be unreachable from exactly the two call sites that
/// matter most. It is still registered in main.dart's `MultiProvider` via
/// `.value` so the paywall can `context.watch` it like any other provider —
/// the same shape `AudioEffectsService` already uses.
///
/// Runs on Play Billing Library 8.0.0, which is what `in_app_purchase_android`
/// 0.5.0 bundles. Google requires v8 or later for new apps and updates from
/// 31 Aug 2026.
class BillingService extends ChangeNotifier {
  BillingService._();

  static final BillingService instance = BillingService._();

  // ───────────────────────────────────────────────────────────────────────
  //  Product identifiers — these MUST match Play Console exactly.
  // ───────────────────────────────────────────────────────────────────────

  /// The auto-renewing subscription product.
  static const String kSubscriptionId = 'premium';

  /// The base plan inside [kSubscriptionId] that this app sells.
  ///
  /// A subscription product can carry several base plans (monthly, yearly, …)
  /// and each base plan several offers. `queryProductDetails` flattens all of
  /// them into one [GooglePlayProductDetails] *per offer*, every one of them
  /// still reporting `id == 'premium'` — so filtering by product id alone is
  /// not enough to know which plan the user is about to be charged for.
  static const String kYearlyBasePlanId = 'yearly';

  /// An optional second base plan on [kSubscriptionId].
  ///
  /// The paywall renders a Monthly card only when Play actually returns this
  /// base plan. It does not exist in Play Console today, so the card stays
  /// hidden — the alternative, a card with a made-up price and a buy button
  /// that fails, is worse than no card. Create a `monthly` base plan under the
  /// `premium` subscription and it appears with no code change.
  static const String kMonthlyBasePlanId = 'monthly';

  /// The one-time (non-consumable) unlock.
  static const String kLifetimeId = 'lifetime';

  static const Set<String> _productIds = <String>{kSubscriptionId, kLifetimeId};

  /// Cached entitlement, so premium survives a cold start with no network.
  /// Authoritative only until [_verifyEntitlement] has answered.
  static const String _kPrefsPremium = 'billing_is_premium';

  // ───────────────────────────────────────────────────────────────────────
  //  State
  // ───────────────────────────────────────────────────────────────────────

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  /// Backstop that releases [_purchaseInFlight] if Play never reports back.
  ///
  /// The stream is supposed to close every flow it opens, and after the
  /// empty-productID fix below it does. This exists because the cost of the
  /// two outcomes is wildly asymmetric: a spurious re-enable costs a user one
  /// harmless extra tap, while a wedged flag disables the buy button for the
  /// rest of the session and loses the sale outright.
  Timer? _flightWatchdog;

  bool _initialised = false;
  bool _isPremium = false;
  bool _storeAvailable = false;
  bool _loadingProducts = false;
  bool _purchaseInFlight = false;
  bool _hasPendingPurchase = false;
  String? _lastError;

  ProductDetails? _yearly;

  /// The standing base-plan price, set only when [_yearly] is a discount offer.
  /// Null the rest of the time, which is what stops the paywall from ever
  /// striking through a price that is not real.
  ProductDetails? _yearlyBaseline;

  ProductDetails? _monthly;
  ProductDetails? _lifetime;

  /// True when the yearly subscription is active **or** lifetime was bought.
  ///
  /// This is the only flag the rest of the app should read. Ads, gated
  /// features and the paywall all key off it.
  bool get isPremium => _isPremium;

  /// Whether Play Billing answered at all. False on a device with no Play
  /// Store, or while offline on the very first launch.
  bool get isStoreAvailable => _storeAvailable;

  /// True while [ProductDetails] are being fetched, so the paywall can show
  /// skeletons instead of empty price slots.
  bool get isLoadingProducts => _loadingProducts;

  /// True from the moment a billing flow is launched until Play reports back.
  bool get isPurchaseInFlight => _purchaseInFlight;

  /// True when Play has accepted a purchase but has not settled it yet — the
  /// normal path for UPI, net-banking and cash-based payments in India, which
  /// can take minutes to days. Premium is deliberately NOT granted here.
  bool get hasPendingPurchase => _hasPendingPurchase;

  /// Last user-facing failure, cleared as soon as the next attempt starts.
  String? get lastError => _lastError;

  /// The `yearly` base plan of the `premium` subscription, or null if Play has
  /// not answered yet.
  ProductDetails? get yearly => _yearly;

  /// The `monthly` base plan, or null when Play Console has no such plan.
  ProductDetails? get monthly => _monthly;

  /// The `lifetime` one-time product, or null if Play has not answered yet.
  ProductDetails? get lifetime => _lifetime;

  /// Localised, currency-correct price straight from Play — e.g. `₹199.00` in
  /// India, `$2.99` in the US. Never hardcode these: both products are live in
  /// ~173 countries and a hardcoded rupee figure is wrong in 172 of them.
  String? get yearlyPrice => _yearly?.price;

  /// See [yearlyPrice]. Null when there is no monthly base plan.
  String? get monthlyPrice => _monthly?.price;

  /// The standing price to strike through, or null when the user is simply
  /// paying the standing price and there is nothing to compare against.
  String? get yearlyOriginalPrice => _yearlyBaseline?.price;

  /// How much the active offer takes off the standing yearly price.
  ///
  /// Computed from `rawPrice` — the exact amounts Play charges — so the figure
  /// on the badge is arithmetic, not marketing. Null unless a real discount
  /// offer is live.
  int? get yearlyDiscountPercent {
    final ProductDetails? was = _yearlyBaseline;
    final ProductDetails? now = _yearly;
    if (was == null || now == null) return null;
    if (was.rawPrice <= 0 || now.rawPrice >= was.rawPrice) return null;
    return (((was.rawPrice - now.rawPrice) / was.rawPrice) * 100).round();
  }

  /// See [yearlyPrice].
  String? get lifetimePrice => _lifetime?.price;

  // ───────────────────────────────────────────────────────────────────────
  //  What the active entitlement actually is
  // ───────────────────────────────────────────────────────────────────────

  bool _ownsLifetime = false;
  DateTime? _subscriptionPurchasedAt;
  bool _subscriptionAutoRenewing = false;

  /// True when premium came from the one-time unlock, which never expires.
  bool get ownsLifetime => _ownsLifetime;

  /// Whether Play will bill the subscription again at the end of the period.
  /// False once the user cancels, even while the period is still running.
  bool get subscriptionAutoRenewing => _subscriptionAutoRenewing;

  /// When the current subscription period ends.
  ///
  /// **Derived, not authoritative.** Play's client Billing Library does not
  /// expose an expiry date at all — `PurchaseWrapper` carries only
  /// `purchaseTime` and `isAutoRenewing`. The real expiry lives behind the
  /// Google Play Developer API (`purchases.subscriptionsv2.get`), which needs a
  /// server; this app has none.
  ///
  /// So this is `purchaseTime + 1 year`. That tracks reality closely because
  /// Play issues a fresh purchase token on every renewal and `purchaseTime`
  /// moves with it, but it will read a day or so off around a renewal, and it
  /// cannot know about a grace period, an account hold or a refund. Present it
  /// as "renews on", never as a guarantee — and if an exact date is ever
  /// required, that needs the server-side API.
  ///
  /// Null for a lifetime owner (nothing expires) and for a free user.
  DateTime? get subscriptionPeriodEnd {
    final DateTime? start = _subscriptionPurchasedAt;
    if (start == null) return null;
    return DateTime(start.year + 1, start.month, start.day);
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Start-up
  // ───────────────────────────────────────────────────────────────────────

  /// Reads the cached entitlement and nothing else.
  ///
  /// Split out from [init] because `main()` has to know whether to initialise
  /// the ad SDK *at all*, and that decision cannot wait on a Play Billing
  /// round-trip — the whole point of caching is that it answers in the time a
  /// SharedPreferences read takes. [init] then re-verifies against Play in the
  /// background and corrects the flag if the subscription has lapsed.
  Future<void> loadCachedEntitlement() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool(_kPrefsPremium) ?? false;
      if (cached != _isPremium) {
        _isPremium = cached;
        notifyListeners();
      }
    } catch (error) {
      // Storage failure falls back to "not premium", which shows ads to a
      // paying user for one session. The opposite default would hand premium
      // to everyone whose prefs failed to open, so this is the safe direction.
      debugPrint('BillingService: cache read failed: $error');
    }
  }

  /// Connects to Play, loads the products and re-verifies the entitlement.
  ///
  /// Safe to call more than once; only the first call does anything.
  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // iOS is out of scope here — the paywall and the products are Play-only.
    // Guarding keeps a future iOS build from throwing on the Android-specific
    // platform addition used by [_verifyEntitlement].
    if (!Platform.isAndroid) return;

    // Subscribe BEFORE anything can produce an event. Play replays purchases
    // that completed while the app was dead (a UPI payment that settled
    // overnight, a purchase made on another device) as soon as the connection
    // is up, and an unsubscribed stream drops them on the floor — the user
    // pays and never gets premium.
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchasesUpdated,
      onError: (Object error) {
        debugPrint('BillingService: purchase stream error: $error');
      },
    );

    try {
      _storeAvailable = await _iap.isAvailable();
    } catch (error) {
      debugPrint('BillingService: isAvailable failed: $error');
      _storeAvailable = false;
    }

    if (!_storeAvailable) {
      // No Play Store, or offline. Keep whatever the cache said — a paying
      // user on a plane still gets their ad-free playback.
      notifyListeners();
      return;
    }

    await Future.wait(<Future<void>>[
      loadProducts(),
      _verifyEntitlement(),
    ]);
  }

  @override
  void dispose() {
    _purchaseSub?.cancel();
    _purchaseSub = null;
    _flightWatchdog?.cancel();
    _flightWatchdog = null;
    super.dispose();
  }

  /// Marks the billing flow as finished, however it finished.
  ///
  /// Every exit path goes through here so the watchdog is always cancelled
  /// with the flag — a stray timer that fires later would re-enable the button
  /// mid-purchase.
  void _endFlight() {
    _purchaseInFlight = false;
    _flightWatchdog?.cancel();
    _flightWatchdog = null;
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Products
  // ───────────────────────────────────────────────────────────────────────

  /// Fetches both products in one call.
  ///
  /// `queryProductDetails` asks Play for each id as INAPP *and* as SUBS and
  /// merges the answers, so one call covers `lifetime` (one-time) and
  /// `premium` (subscription) together — the ids that do not exist under a
  /// given type simply come back in `notFoundIDs`.
  Future<void> loadProducts() async {
    _loadingProducts = true;
    notifyListeners();

    try {
      final response = await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        _lastError = response.error!.message;
      }

      // Every id is queried as both types, so each one is always "not found"
      // as the type it isn't. Only a *complete* miss is worth reporting.
      final missing = response.notFoundIDs
          .where((String id) => !response.productDetails
              .any((ProductDetails p) => p.id == id))
          .toList();
      if (missing.isNotEmpty) {
        debugPrint(
          'BillingService: products not found on Play: ${missing.join(', ')}. '
          'Check the ids are Active and the app is installed from a Play track.',
        );
      }

      _lifetime = _pickLifetime(response.productDetails);
      // A discount offer, when Play returns one, is what the user is actually
      // charged; the plain base plan then becomes the "was" price.
      final yearlyOffers =
          _basePlanOffers(response.productDetails, kYearlyBasePlanId);
      _yearly = yearlyOffers.promo ?? yearlyOffers.plain;
      _yearlyBaseline = yearlyOffers.promo == null ? null : yearlyOffers.plain;

      _monthly =
          _basePlanOffers(response.productDetails, kMonthlyBasePlanId).plain;

      _logRawOffers(response.productDetails);
    } catch (error) {
      debugPrint('BillingService: queryProductDetails failed: $error');
      _lastError = 'Could not reach Google Play. Please try again.';
    } finally {
      _loadingProducts = false;
      notifyListeners();
    }
  }

  /// Dumps every offer Play returned, exactly as received.
  ///
  /// Exists to settle "the paywall is showing the wrong price" without
  /// guesswork. Nothing in this class rounds, converts or reformats a price —
  /// the UI prints `ProductDetails.price` verbatim — so if the amount here
  /// does not match Play Console, the discrepancy is on the Play side (the
  /// console value itself, a price still propagating, or the account's billing
  /// country) and no code change can fix it.
  ///
  /// `rawPrice` is included because it comes from `priceAmountMicros`, the
  /// exact integer Play charges — it tells 199 apart from 199.4 rounded for
  /// display.
  void _logRawOffers(List<ProductDetails> all) {
    if (!kDebugMode) return;

    debugPrint('BillingService: Play returned ${all.length} offer(s):');
    for (final ProductDetails p in all) {
      final buffer = StringBuffer('  • ${p.id}  price="${p.price}"  '
          'raw=${p.rawPrice}  currency=${p.currencyCode}');
      if (p is GooglePlayProductDetails) {
        final int? index = p.subscriptionIndex;
        final offers = p.productDetails.subscriptionOfferDetails;
        if (index != null && offers != null && index < offers.length) {
          final SubscriptionOfferDetailsWrapper offer = offers[index];
          buffer.write('  basePlanId=${offer.basePlanId}'
              '  offerId=${offer.offerId ?? "-"}'
              '  phases=${offer.pricingPhases.length}');
        }
      }
      debugPrint(buffer.toString());
    }
  }

  ProductDetails? _pickLifetime(List<ProductDetails> all) {
    for (final ProductDetails product in all) {
      if (product.id == kLifetimeId) return product;
    }
    return null;
  }

  /// Finds the [ProductDetails] that represents the `yearly` base plan.
  ///
  /// Two filters, both needed:
  ///  * `basePlanId == 'yearly'` — a subscription with several base plans
  ///    yields one entry per plan, all sharing `id == 'premium'`.
  ///  * `offerId == null` — within that base plan, Play also returns any
  ///    promotional offers the user is eligible for (free trial, intro price).
  ///    Those quote the *offer's* first pricing phase, which can be ₹0. The
  ///    regular base plan is the one with a null offer id, and quoting it is
  ///    the honest direction to be wrong in: a user who turns out to be
  ///    trial-eligible is charged less than the paywall said, never more.
  ///
  /// Falls back to the first offer on the base plan if there is no plain one,
  /// so a console-side offer change can never leave the paywall with no price.
  /// Both of Play's prices for one base plan.
  ///
  /// `plain` is the base plan itself (`offerId == null`) — the standing price.
  /// `promo` is a discount offer on that base plan that this user is eligible
  /// for, if Play returned one; `queryProductDetails` only ever includes offers
  /// the account actually qualifies for, so its presence is the eligibility
  /// check.
  ///
  /// Keeping them apart is what makes an honest struck-through price possible:
  /// the strikethrough is the real standing price and the large number is the
  /// real discounted one, both straight from Play. A hardcoded "was ₹1,999" the
  /// product never sold at is deceptive pricing under Play policy.
  ({GooglePlayProductDetails? plain, GooglePlayProductDetails? promo})
      _basePlanOffers(List<ProductDetails> all, String basePlanId) {
    GooglePlayProductDetails? plain;
    GooglePlayProductDetails? promo;

    for (final ProductDetails product in all) {
      if (product is! GooglePlayProductDetails) continue;
      if (product.id != kSubscriptionId) continue;

      final int? index = product.subscriptionIndex;
      if (index == null) continue;

      final List<SubscriptionOfferDetailsWrapper>? offers =
          product.productDetails.subscriptionOfferDetails;
      if (offers == null || index >= offers.length) continue;

      final SubscriptionOfferDetailsWrapper offer = offers[index];
      if (offer.basePlanId != basePlanId) continue;

      if (offer.offerId == null) {
        plain ??= product;
      } else {
        promo ??= product;
      }
    }

    return (plain: plain, promo: promo);
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Buying
  // ───────────────────────────────────────────────────────────────────────

  /// Launches the Play billing flow for the yearly subscription.
  ///
  /// The offer token is not passed explicitly: `buyNonConsumable` reads it off
  /// the [GooglePlayProductDetails] we hand it, and [_pickYearlyBasePlan] has
  /// already selected the object carrying the `yearly` token. A subscription
  /// purchase launched without a token fails outright.
  Future<bool> purchaseYearly() => _launch(_yearly);

  /// Launches the Play billing flow for the monthly base plan, when one exists.
  Future<bool> purchaseMonthly() => _launch(_monthly);

  /// Launches the Play billing flow for the lifetime unlock.
  ///
  /// [InAppPurchase.buyNonConsumable], never `buyConsumable`. Lifetime is a
  /// permanent entitlement: consuming it would return the product to Play's
  /// "available to buy" state, wiping the user's unlock and letting them be
  /// charged a second time for what they already own.
  Future<bool> purchaseLifetime() => _launch(_lifetime);

  Future<bool> _launch(ProductDetails? product) async {
    if (product == null) {
      _lastError = 'This option is not available right now.';
      notifyListeners();
      return false;
    }
    if (_purchaseInFlight) return false;

    _lastError = null;
    _purchaseInFlight = true;

    // The Play sheet covers the app while it is open, so re-enabling the
    // button underneath it is harmless; leaving it disabled forever is not.
    _flightWatchdog?.cancel();
    _flightWatchdog = Timer(const Duration(minutes: 3), () {
      if (!_purchaseInFlight) return;
      debugPrint('BillingService: no result from Play — releasing buy button.');
      _endFlight();
      notifyListeners();
    });

    notifyListeners();

    try {
      // Both products go through buyNonConsumable — see [purchaseLifetime].
      final bool started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        _endFlight();
        _lastError = 'Google Play could not start the purchase.';
        notifyListeners();
      }
      return started;
    } catch (error) {
      debugPrint('BillingService: buyNonConsumable failed: $error');
      _endFlight();
      _lastError = 'Purchase could not be started. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Restore / verify
  // ───────────────────────────────────────────────────────────────────────

  /// Re-queries Play for everything this account owns and rewrites the flag.
  ///
  /// Backs both the "Restore Purchases" button and the silent check on every
  /// launch. [_verifyEntitlement] checks **both** product types, so a user who
  /// bought lifetime, reinstalled, and never had a subscription still gets
  /// their unlock back.
  Future<void> restore() async {
    _lastError = null;
    await _verifyEntitlement();
  }

  /// The authoritative entitlement check.
  ///
  /// Uses `queryPastPurchases` rather than `InAppPurchase.restorePurchases`
  /// because it *returns* the snapshot instead of pushing it through
  /// `purchaseStream`. That difference matters for the negative case: a
  /// lapsed subscriber owns nothing, so a stream-based restore emits an empty
  /// batch that is indistinguishable from "no restore ran", and a stale
  /// cached `true` would never be cleared. An awaited list of length zero is
  /// unambiguous.
  ///
  /// It queries INAPP and SUBS in parallel internally, which is what makes it
  /// correct for this app: checking only SUBS would strip lifetime buyers of
  /// their unlock the moment they reinstall.
  Future<void> _verifyEntitlement() async {
    if (!Platform.isAndroid) return;

    try {
      final addition = _iap
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final response = await addition.queryPastPurchases();

      if (response.error != null) {
        // Could not reach Play — keep the cached value rather than revoking
        // premium from a paying user because their train went into a tunnel.
        debugPrint(
          'BillingService: queryPastPurchases error: ${response.error!.message}',
        );
        _lastError = 'Could not reach Google Play. Please try again.';
        notifyListeners();
        return;
      }

      var entitled = false;
      var pending = false;
      var ownsLifetime = false;
      DateTime? subTime;
      var subRenewing = false;

      for (final GooglePlayPurchaseDetails purchase in response.pastPurchases) {
        if (purchase.productID != kSubscriptionId &&
            purchase.productID != kLifetimeId) {
          continue;
        }

        // PENDING is not ownership. Play lists a UPI payment awaiting
        // settlement here, and granting on it hands out premium for a payment
        // that may never arrive.
        if (purchase.billingClientPurchase.purchaseState ==
            PurchaseStateWrapper.pending) {
          pending = true;
          continue;
        }
        if (purchase.billingClientPurchase.purchaseState !=
            PurchaseStateWrapper.purchased) {
          continue;
        }

        entitled = true;

        // Remember which kind of entitlement this is, and when it was bought,
        // so the paywall can tell a subscriber their renewal date apart from a
        // lifetime owner who has none.
        if (purchase.productID == kLifetimeId) {
          ownsLifetime = true;
        } else {
          subTime = DateTime.fromMillisecondsSinceEpoch(
            purchase.billingClientPurchase.purchaseTime,
          );
          subRenewing = purchase.billingClientPurchase.isAutoRenewing;
        }

        // A purchase restored from a previous install can still be
        // unacknowledged — the app may have been killed before it settled the
        // first time. Google auto-refunds anything left unacknowledged for
        // three days, so every pass has to re-check.
        if (purchase.pendingCompletePurchase) {
          await _complete(purchase);
        }
      }

      _hasPendingPurchase = pending;
      _ownsLifetime = ownsLifetime;
      _subscriptionPurchasedAt = subTime;
      _subscriptionAutoRenewing = subRenewing;
      await _setPremium(entitled);
    } catch (error) {
      debugPrint('BillingService: verify failed: $error');
      _lastError = 'Could not check your purchases. Please try again.';
      notifyListeners();
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Purchase stream
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _onPurchasesUpdated(List<PurchaseDetails> purchases) async {
    var granted = false;
    var pending = false;

    for (final PurchaseDetails purchase in purchases) {
      // A cancelled or failed flow arrives as a synthetic entry with an EMPTY
      // productID: Play returned a response code but no purchase for the
      // plugin to attach it to, so it manufactures one (see
      // `_getPurchaseDetailsFromResult` in in_app_purchase_android).
      //
      // It carries no entitlement, but it is the only signal that the billing
      // flow ended, so it must still release the in-flight flag. Filtering it
      // out by product id — which is what an id check alone does — left the
      // buy button spinning for the rest of the session after the user backed
      // out of the Play sheet, with no way to retry short of killing the app.
      // Verified on device: dismissing the sheet produced exactly this event.
      //
      // Nothing is acknowledged here: `pendingCompletePurchase` defaults to
      // false on the synthetic entry, and there is no real token to settle.
      if (purchase.productID.isEmpty) {
        _endFlight();
        if (purchase.status == PurchaseStatus.error) {
          _lastError = purchase.error?.message ?? 'The purchase failed.';
        }
        continue;
      }

      if (purchase.productID != kSubscriptionId &&
          purchase.productID != kLifetimeId) {
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Deliberately no `completePurchase` here: acknowledging a purchase
          // Play has not settled is invalid, and no entitlement is granted
          // until it flips to `purchased`. The stream fires again on its own
          // when that happens.
          pending = true;
          _endFlight();

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          granted = true;
          _endFlight();
          // MUST happen within three days or Google refunds the purchase
          // automatically. This is the Dart equivalent of
          // `BillingClient.acknowledgePurchase`, and it applies to the
          // subscription and the lifetime unlock alike. It does NOT consume —
          // `completePurchase` only consumes products bought via
          // `buyConsumable`, which this app never calls.
          if (purchase.pendingCompletePurchase) {
            await _complete(purchase);
          }

        case PurchaseStatus.error:
          _endFlight();
          _lastError = purchase.error?.message ?? 'The purchase failed.';
          if (purchase.pendingCompletePurchase) {
            await _complete(purchase);
          }

        case PurchaseStatus.canceled:
          // User backed out of the Play sheet. Not an error worth showing.
          _endFlight();
          if (purchase.pendingCompletePurchase) {
            await _complete(purchase);
          }
      }
    }

    _hasPendingPurchase = pending;

    if (granted) {
      await _setPremium(true);
    } else {
      notifyListeners();
    }
  }

  Future<void> _complete(PurchaseDetails purchase) async {
    try {
      await _iap.completePurchase(purchase);
    } catch (error) {
      // Left unacknowledged, Play will refund this in three days. Retried on
      // the next launch by [_verifyEntitlement], which re-checks
      // `pendingCompletePurchase` on everything the account owns.
      debugPrint('BillingService: completePurchase failed: $error');
    }
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Entitlement plumbing
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _setPremium(bool value) async {
    final bool changed = _isPremium != value;
    _isPremium = value;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefsPremium, value);
    } catch (error) {
      debugPrint('BillingService: cache write failed: $error');
    }

    // Notify even when the flag did not change: `lastError`,
    // `hasPendingPurchase` and `isPurchaseInFlight` reach this point too and
    // the paywall renders all three.
    if (changed) {
      debugPrint('BillingService: premium -> $value');
    }
    notifyListeners();
  }

  /// Opens the subscription's page in the Play Store so the user can cancel or
  /// change payment method. Required by Google for any app selling subs.
  ///
  /// Deep-links straight to the `premium` subscription; without the `sku` the
  /// user lands on the full list of every subscription they own.
  Future<bool> openManageSubscriptions({String? packageName}) async {
    final String pkg = packageName ?? 'com.vidnexa.videoplayer';
    final Uri uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions'
      '?sku=$kSubscriptionId&package=$pkg',
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('BillingService: manage subscriptions failed: $error');
      return false;
    }
  }
}
