/// Translation table for the premium paywall (`lib/Billing/paywall_screen.dart`)
/// and the premium entry points that lead into it.
///
/// Same shape as [ProfileStrings] and the other tables in this folder: only
/// `en` and `hi` are translated, and any other locale code falls back to
/// English.
///
/// Note what is deliberately NOT in here: prices. Every amount the paywall
/// shows comes from `ProductDetails.price`, which Play returns already
/// formatted for the user's billing country. Putting "₹199" in a string table
/// would show the wrong currency to the ~172 other countries these products
/// are live in.
///
/// A few entries carry `{placeholder}` tokens (`{price}`, `{period}`) that the
/// caller substitutes with `String.replaceAll` after looking up the template.
class PaywallStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // ── Header ─────────────────────────────────────────────────────────
      'paywall_title': 'Vidnexa Premium',
      'paywall_subtitle': 'Unlock everything. No ads, ever.',
      'paywall_active_title': 'You\'re Premium',
      'paywall_active_subtitle': 'Thanks for supporting Vidnexa.',

      // ── Feature list ───────────────────────────────────────────────────
      'paywall_feature_no_ads_title': 'Ad-free playback',
      'paywall_feature_no_ads_sub':
          'No banners, no interstitials, no interruptions',
      'paywall_feature_all_title': 'All premium features',
      'paywall_feature_all_sub': 'Equalizer presets, 4K enhance and more',
      'paywall_feature_themes_title': 'Exclusive themes',
      'paywall_feature_themes_sub': 'Premium-only player skins and accents',
      'paywall_feature_early_title': 'Early access',
      'paywall_feature_early_sub': 'New features before everyone else',

      // ── Plans ──────────────────────────────────────────────────────────
      'paywall_plan_lifetime': 'Lifetime',
      'paywall_plan_lifetime_sub': 'One-time payment, no renewal',
      'paywall_plan_yearly': 'Yearly',
      'paywall_plan_yearly_sub': 'Billed once a year',
      'paywall_badge_best_value': 'BEST VALUE',
      'paywall_per_year': '/year',

      // ── Actions ────────────────────────────────────────────────────────
      'paywall_continue': 'Continue',
      'paywall_processing': 'Processing…',
      'paywall_restore': 'Restore Purchases',
      // Short form for the app bar, where the full label crowds the title.
      'paywall_restore_short': 'Restore',
      'paywall_manage_sub': 'Manage subscription',
      'paywall_retry': 'Try again',
      'paywall_close': 'Close',

      // ── Terms ──────────────────────────────────────────────────────────
      // Only the yearly variant may mention renewal. Showing "renews
      // automatically" under a one-time purchase is factually wrong and is a
      // reliable source of refund requests and 1-star reviews.
      'paywall_terms_yearly':
          'Your subscription renews automatically for {price} every year until '
          'cancelled. Cancel any time in Google Play, at least 24 hours before '
          'the renewal date.',
      'paywall_terms_lifetime':
          'A single payment of {price}. This is not a subscription — nothing '
          'renews and you will not be charged again.',

      // ── Status / errors ────────────────────────────────────────────────
      'paywall_pending_title': 'Payment pending',
      'paywall_pending_body':
          'Google Play is still confirming your payment. Premium unlocks '
          'automatically as soon as it goes through — you can close this screen.',
      'paywall_unavailable_title': 'Store unavailable',
      'paywall_unavailable_body':
          'Google Play could not be reached. Check your connection and try again.',
      'paywall_restore_none': 'No previous purchases found on this account.',
      'paywall_restore_ok': 'Purchases restored. Premium is active.',
      'paywall_thanks': 'Thank you! Premium is now active.',

      // ── Subscription-screen polish ─────────────────────────────────────
      // {price} here is a *derived* figure — the real yearly price divided by
      // twelve — not a separate Play product. It is shown as an approximation
      // so it can never read as a price the user can actually be charged.
      'paywall_per_month': '≈{price}/month',
      'paywall_pay_once': 'Pay once · Yours forever',
      'paywall_secure': 'Secure payment via Google Play',
      'paywall_cancel_anytime': 'Cancel anytime in Play Store',
      'paywall_continue_with': 'Continue · {price}',
      'paywall_most_popular': 'MOST POPULAR',

      // ── Premium redesign ───────────────────────────────────────────────
      'paywall_hero_title': 'Unlock Premium',
      'paywall_plan_active': 'Your plan',
      'paywall_lifetime_active': 'Lifetime · Never expires',
      'paywall_renews_on': 'Renews on {date}',
      'paywall_expires_on': 'Access until {date}',
      'paywall_cancelled_note': 'Cancelled — premium stays active until then.',
      'paywall_hero_sub': 'Get the ultimate experience with Premium',
      'paywall_cta': 'Continue with Premium',
      'paywall_plan_monthly': 'Monthly',
      'paywall_plan_monthly_sub': 'Billed every month',
      'paywall_per_month_short': '/mo',
      'paywall_cancel_anytime_short': 'Cancel anytime',
      'paywall_no_renewal_short': 'One-time payment',
      'paywall_secure_short': 'Secure payment',
      'paywall_terms_link': 'Terms of Service',
      'paywall_privacy_link': 'Privacy Policy',
      'paywall_benefits_title': 'Premium Benefits',
      'paywall_benefit_no_ads': 'Ad-Free Experience',
      'paywall_benefit_uhd': 'Ultra HD Playback',
      'paywall_benefit_controls': 'Advanced Video Controls',
      'paywall_benefit_background': 'Background Playback',
      'paywall_benefit_all': 'All Premium Features',
      'paywall_benefit_updates': 'Future Premium Updates',
      'paywall_whats_included': "What's included",
    },

    'hi': {
      // ── Header ─────────────────────────────────────────────────────────
      'paywall_title': 'विदनेक्सा प्रीमियम',
      'paywall_subtitle': 'सब कुछ अनलॉक करें। कोई विज्ञापन नहीं, कभी नहीं।',
      'paywall_active_title': 'आप प्रीमियम हैं',
      'paywall_active_subtitle': 'विदनेक्सा का समर्थन करने के लिए धन्यवाद।',

      // ── Feature list ───────────────────────────────────────────────────
      'paywall_feature_no_ads_title': 'विज्ञापन-मुक्त प्लेबैक',
      'paywall_feature_no_ads_sub':
          'कोई बैनर नहीं, कोई इंटरस्टीशियल नहीं, कोई रुकावट नहीं',
      'paywall_feature_all_title': 'सभी प्रीमियम सुविधाएं',
      'paywall_feature_all_sub': 'इक्वलाइज़र प्रीसेट, 4K एन्हांस और भी बहुत कुछ',
      'paywall_feature_themes_title': 'विशेष थीम',
      'paywall_feature_themes_sub': 'केवल प्रीमियम प्लेयर स्किन और रंग',
      'paywall_feature_early_title': 'अर्ली एक्सेस',
      'paywall_feature_early_sub': 'नई सुविधाएं सबसे पहले आपके लिए',

      // ── Plans ──────────────────────────────────────────────────────────
      'paywall_plan_lifetime': 'लाइफटाइम',
      'paywall_plan_lifetime_sub': 'एक बार भुगतान, कोई नवीनीकरण नहीं',
      'paywall_plan_yearly': 'वार्षिक',
      'paywall_plan_yearly_sub': 'साल में एक बार बिल',
      'paywall_badge_best_value': 'सर्वोत्तम मूल्य',
      'paywall_per_year': '/वर्ष',

      // ── Actions ────────────────────────────────────────────────────────
      'paywall_continue': 'जारी रखें',
      'paywall_processing': 'प्रोसेस हो रहा है…',
      'paywall_restore': 'खरीदारी पुनर्स्थापित करें',
      'paywall_restore_short': 'पुनर्स्थापित करें',
      'paywall_manage_sub': 'सदस्यता प्रबंधित करें',
      'paywall_retry': 'पुनः प्रयास करें',
      'paywall_close': 'बंद करें',

      // ── Terms ──────────────────────────────────────────────────────────
      'paywall_terms_yearly':
          'आपकी सदस्यता रद्द किए जाने तक हर साल {price} पर स्वतः नवीनीकृत होती '
          'है। नवीनीकरण तिथि से कम से कम 24 घंटे पहले Google Play में कभी भी '
          'रद्द करें।',
      'paywall_terms_lifetime':
          '{price} का एक बार का भुगतान। यह सदस्यता नहीं है — कुछ भी नवीनीकृत '
          'नहीं होता और आपसे दोबारा शुल्क नहीं लिया जाएगा।',

      // ── Status / errors ────────────────────────────────────────────────
      'paywall_pending_title': 'भुगतान लंबित',
      'paywall_pending_body':
          'Google Play अभी भी आपके भुगतान की पुष्टि कर रहा है। भुगतान पूरा होते '
          'ही प्रीमियम अपने आप अनलॉक हो जाएगा — आप यह स्क्रीन बंद कर सकते हैं।',
      'paywall_unavailable_title': 'स्टोर उपलब्ध नहीं',
      'paywall_unavailable_body':
          'Google Play से कनेक्ट नहीं हो सका। अपना कनेक्शन जांचें और पुनः प्रयास करें।',
      'paywall_restore_none': 'इस खाते पर कोई पिछली खरीदारी नहीं मिली।',
      'paywall_restore_ok': 'खरीदारी पुनर्स्थापित हो गई। प्रीमियम सक्रिय है।',
      'paywall_thanks': 'धन्यवाद! प्रीमियम अब सक्रिय है।',

      // ── Subscription-screen polish ─────────────────────────────────────
      'paywall_per_month': '≈{price}/महीना',
      'paywall_pay_once': 'एक बार भुगतान · हमेशा के लिए आपका',
      'paywall_secure': 'Google Play से सुरक्षित भुगतान',
      'paywall_cancel_anytime': 'Play Store में कभी भी रद्द करें',
      'paywall_continue_with': 'जारी रखें · {price}',
      'paywall_most_popular': 'सबसे लोकप्रिय',

      // ── Premium redesign ───────────────────────────────────────────────
      'paywall_hero_title': 'प्रीमियम अनलॉक करें',
      'paywall_plan_active': 'आपका प्लान',
      'paywall_lifetime_active': 'लाइफटाइम · कभी समाप्त नहीं',
      'paywall_renews_on': '{date} को नवीनीकृत होगा',
      'paywall_expires_on': '{date} तक एक्सेस',
      'paywall_cancelled_note': 'रद्द किया गया — तब तक प्रीमियम सक्रिय रहेगा।',
      'paywall_hero_sub': 'प्रीमियम के साथ बेहतरीन अनुभव पाएं',
      'paywall_cta': 'प्रीमियम के साथ जारी रखें',
      'paywall_plan_monthly': 'मासिक',
      'paywall_plan_monthly_sub': 'हर महीने बिल',
      'paywall_per_month_short': '/माह',
      'paywall_cancel_anytime_short': 'कभी भी रद्द करें',
      'paywall_no_renewal_short': 'एक बार भुगतान',
      'paywall_secure_short': 'सुरक्षित भुगतान',
      'paywall_terms_link': 'सेवा की शर्तें',
      'paywall_privacy_link': 'गोपनीयता नीति',
      'paywall_benefits_title': 'प्रीमियम लाभ',
      'paywall_benefit_no_ads': 'विज्ञापन-मुक्त अनुभव',
      'paywall_benefit_uhd': 'अल्ट्रा HD प्लेबैक',
      'paywall_benefit_controls': 'एडवांस्ड वीडियो कंट्रोल',
      'paywall_benefit_background': 'बैकग्राउंड प्लेबैक',
      'paywall_benefit_all': 'सभी प्रीमियम सुविधाएं',
      'paywall_benefit_updates': 'भविष्य के प्रीमियम अपडेट',
      'paywall_whats_included': 'क्या-क्या मिलेगा',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
