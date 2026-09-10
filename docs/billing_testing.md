# Testing Google Play Billing

The billing layer is `lib/Billing/billing_service.dart`, the paywall is
`lib/Billing/paywall_screen.dart`. Play Billing Library **8.0.0**, via
`in_app_purchase 3.3.0` + `in_app_purchase_android 0.5.0`.

## Products

These ids must match Play Console exactly. They are declared once, in
`BillingService`, and nothing else in the app hardcodes them.

| What | Product ID | Base plan | Type |
|---|---|---|---|
| Yearly subscription | `premium` | `yearly` | SUBS (auto-renewing) |
| Lifetime unlock | `lifetime` | — | INAPP (one-time, non-consumable) |

Prices are never hardcoded. Everything the paywall shows comes from
`ProductDetails.price`, which Play returns already formatted for the user's
billing country — both products are live in ~173 countries, so a literal
`₹199` would be wrong in 172 of them.

## Why billing cannot be tested from a local debug build

Play Billing talks to the Play Store app, and the Play Store only recognises a
build it can match to your Play Console listing — same `applicationId`
(`com.vidnexa.videoplayer`), same **upload key signature**, and a
`versionCode` that has actually been uploaded. A `flutter run` debug APK is
signed with the debug key, so:

- `queryProductDetails` returns both ids in `notFoundIDs`
- the paywall shows its "Store unavailable" state
- no billing flow can be launched

That is expected, not a bug. Everything below has to be done on a build
installed **from a Play track**.

## One-time setup

1. **License testers.** Play Console → *Settings* (left nav, gear icon, at the
   account level — not inside the app) → *License testing*. Add the Gmail
   addresses that will test, and set *License response* to `RESPOND_NORMALLY`.
   These accounts are charged nothing and their subscriptions renew on a
   [compressed schedule](https://developer.android.com/google/play/billing/test)
   — a yearly subscription renews roughly every 30 minutes, which is what
   makes renewal and expiry testable at all.

2. **Internal testing track.** Play Console → *Testing* → *Internal testing* →
   create a release, add the tester emails to the tester list, and copy the
   opt-in URL.

3. **Upload a build.** `versionCode` must be higher than anything previously
   uploaded — it is now **29** (`pubspec.yaml` `version: 1.0.29+29`), so bump
   it again for each new upload.

   ```
   flutter build appbundle --release
   ```

   Upload `build/app/outputs/bundle/release/app-release.aab`.

4. **On the device.** Sign in to the Play Store with a license-tester account,
   open the opt-in URL, accept, then install the app from Play. The account
   that installs must be the tester account — Play checks the *installing*
   account, not just the signed-in one.

## The checks that matter

Run these in order. Steps 4 and 5 are the ones that catch the failures that
cost real money.

1. **Prices load.** Open Profile → *Remove Ads*. Both rows show a real,
   currency-formatted price, Lifetime is pre-selected and badged *BEST VALUE*.
   If the prices are missing, check logcat for
   `BillingService: products not found on Play`.

2. **Terms text swaps.** Tap *Yearly* — the terms mention automatic renewal.
   Tap *Lifetime* — they say a single payment, nothing renews. The renewal
   wording must never appear under Lifetime.

3. **Buy lifetime.** Complete the purchase. Premium turns on, the tile switches
   to "You're Premium", and ads stop. Kill and relaunch: logcat should show
   `🛡️ Premium user — ad SDK not initialised.` and no App Open ad appears.

4. **Reinstall restores it.** Uninstall, reinstall from the Play track, launch.
   Premium comes back on its own (the launch-time `_verifyEntitlement` pass
   queries INAPP *and* SUBS). Then confirm *Restore Purchases* on the paywall
   also brings it back. **This is the check that protects lifetime buyers** —
   a restore that only asked Play about subscriptions would silently strip
   their unlock on every reinstall.

5. **Acknowledgement.** After a purchase, do not clear it for a few minutes and
   confirm it is still active — an unacknowledged purchase is auto-refunded by
   Google after 3 days. `BillingService` calls `completePurchase()` on every
   purchased/restored item where `pendingCompletePurchase` is true, and retries
   on the next launch if it failed. To see it, look for a purchase that stays
   owned across several relaunches.

6. **Pending payments.** Play Console license testing lets you pick a **slow
   test card** ("Test instrument, always approves (slow)"). Buy with it: the
   paywall must show *Payment pending* and premium must stay **off**. When it
   settles, premium turns on by itself.

7. **Cancelled purchase — regression test, do not skip.** Start a purchase and
   back out of the Play sheet. No error toast, nothing granted, and the button
   must return to an enabled **Continue** so the user can retry.

   This one shipped broken once. On cancel the plugin emits a synthetic
   `PurchaseDetails` whose `productID` is the **empty string** — filtering the
   stream by product id alone silently drops it, `isPurchaseInFlight` never
   clears, and the buy button spins forever until the app is killed. Verified
   on a device: the user could not retry the purchase at all. There is now an
   explicit empty-productID branch in `_onPurchasesUpdated` plus a 3-minute
   watchdog, but any future change to that stream handler needs this test.

8. **Subscription lapse.** With a license tester, a yearly sub renews every
   ~30 min and can be cancelled from *Manage subscription*. After it expires,
   the next launch must turn premium **off** — that path works because
   `_verifyEntitlement` uses `queryPastPurchases()`, which returns an
   empty list you can act on, rather than `restorePurchases()`, whose empty
   stream batch is indistinguishable from "no restore ran".

9. **Offline.** With premium active, turn off the network and relaunch. Premium
   stays on from the SharedPreferences cache (`billing_is_premium`) and no ads
   appear.

## Clearing state between runs

```
adb shell pm clear com.vidnexa.videoplayer
```

This wipes the cached entitlement. It does **not** revoke the Play purchase —
lifetime stays owned on that account forever. To test the un-purchased paywall
again, either use a different tester account, or refund/cancel the order in
Play Console → *Order management*.

## Things that must not change

- **Never call `consumeAsync` / `InAppPurchaseAndroidPlatformAddition.consumePurchase`
  on `lifetime`.** It is non-consumable. Consuming it returns the product to
  Play's "available to buy" state, wiping the user's entitlement and letting
  them be charged twice. Both products go through `buyNonConsumable()`.
- **Never grant premium on `PurchaseStatus.pending`.** UPI and net-banking are
  common in India and routinely go pending.
- **Never add a struck-through "was ₹X" price.** The products have never sold
  at a higher price, so an anchor price is deceptive pricing under Play policy
  and is a suspension risk.
