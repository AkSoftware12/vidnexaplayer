import 'translations/vi.dart';
import 'translations/tr.dart';
import 'translations/ru.dart';
import 'translations/bn.dart';
import 'translations/ar.dart';
import 'translations/id.dart';
import 'translations/pt.dart';
import 'translations/es.dart';
/// Translation table for the Profile tab and the pre-Home screens that lead
/// into it: Splash, Onboarding, Permission and the Lock/Vault screen.
///
/// Follows the exact same shape as `AppStrings` (see app_strings.dart) —
/// only `en` and `hi` are actually translated; any other locale code falls
/// back to English until real translations are added for it. Kept as a
/// separate namespace/file from `AppStrings` so work on other screens can
/// proceed in parallel without touching this file.
///
/// A few entries contain `{placeholder}` tokens (e.g. `{new}`, `{current}`,
/// `{secs}`) for values that are inherently dynamic (version numbers,
/// countdown seconds, error text, file paths) — callers substitute those
/// with `String.replaceAll` after looking up the translated template.
class ProfileStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // ── Profile tab (Home/Me/me.dart) ──────────────────────────────────
      'profile_edit_title': 'Edit Profile',
      'profile_camera': 'Camera',
      'profile_gallery': 'Gallery',
      'profile_display_name': 'Display Name',
      'profile_save_changes': 'Save Changes',

      'profile_quick_actions': 'Quick Actions',
      'profile_settings_more': 'Settings & More',

      'profile_guest_user': 'Guest User',
      'profile_premium_member': 'PREMIUM MEMBER',

      'profile_files': 'Files',
      'profile_music': 'Music',

      'profile_private': 'Private',
      'profile_vault': 'Vault',

      'profile_section_features': '✦  Features',
      'profile_section_preferences': '✦  Preferences',
      'profile_section_premium': '✦  Premium',
      'profile_section_support': '✦  Support',

      'profile_stream_title': 'Stream',
      'profile_stream_sub': 'Play a video from a link',
      'profile_badge_new': 'NEW',
      'profile_status_saver_title': 'Status Saver',
      // No third-party brand name: Play's impersonation / IP policy treats a
      // trademark in the app's own UI copy as implied affiliation.
      'profile_status_saver_sub': 'Save statuses your contacts share with you',
      'profile_badge_hot': 'HOT',
      'profile_themes_title': 'Themes',
      'profile_themes_sub': 'Customize your app look',
      'profile_notifications_title': 'Notifications',
      'profile_notifications_sub': 'Stay updated, never miss out',
      'profile_toolbar_color_title': 'Toolbar Color',
      'profile_toolbar_color_sub': 'Personalize your theme',
      'profile_language_title': 'Language',
      'profile_language_sub': 'Change app language',
      'profile_text_size_title': 'Text size',
      'profile_text_size_small': 'Small',
      'profile_text_size_default': 'Default',
      'profile_text_size_large': 'Large',
      'profile_text_size_larger': 'Larger',
      'profile_privacy_title': 'Privacy Policy',
      'profile_privacy_sub': 'Privacy & security',
      'profile_ad_privacy_title': 'Ad privacy options',
      'profile_ad_privacy_sub': 'Change your ad consent choice',
      'profile_help_support_title': 'Help & Support',
      'profile_help_support_sub': 'Get assistance anytime',
      'profile_feedback_title': 'Feedback',
      'profile_feedback_sub': 'Share your thoughts with us',
      'profile_share_app_title': 'Share App',
      'profile_share_app_sub': 'Invite your friends',
      'profile_screen_cast_title': 'Screen Cast',
      'profile_screen_cast_sub': 'Mirror this phone to your TV',
      'profile_screen_cast_failed':
          "This phone doesn't have a cast screen. Look for Cast or Screen "
          'mirroring in your Settings or quick tiles.',

      'profile_night_mode_title': 'Night Mode',
      'profile_night_mode_dark': 'Dark theme active',
      'profile_night_mode_light': 'Light theme active',

      'profile_remove_ads_title': 'Remove Ads',
      'profile_badge_pro': 'PRO',
      'profile_remove_ads_sub': 'Enjoy an ad-free experience',
      'profile_upgrade': 'Upgrade',

      'profile_rate_us_title': 'Rate Us',

      'profile_email': 'Email',
      'profile_frequently_asked': 'Frequently Asked',
      'profile_faq_q1': "My videos or music don't show up",
      'profile_faq_a1':
          'Allow access to photos, videos and music when the app asks. If you '
          'denied it, open Android Settings → Apps → Vidnexa → Permissions, '
          'allow it, then reopen the app.',
      'profile_faq_q2': 'How do I remove ads?',
      'profile_faq_a2':
          'Profile → Remove Ads → choose a plan. Already paid? Open the same '
          'screen and tap Restore Purchases while signed in to the same Google '
          'account.',
      'profile_faq_q3': 'How do I cancel my subscription?',
      'profile_faq_a3':
          'Play Store → your profile icon → Payments & subscriptions → '
          'Subscriptions → Vidnexa → Cancel. Premium stays active until the '
          'end of the period you paid for.',
      'profile_faq_q4': 'Forgot your vault PIN?',
      'profile_faq_a4':
          'The PIN is stored only on your phone as a secure hash, so we cannot '
          'see or reset it. If fingerprint unlock is on, use your fingerprint. '
          "Otherwise the vault can't be opened — clearing the app's data "
          'removes the PIN but also permanently deletes the vault files.',
      'profile_faq_q5': 'Does music keep playing when I leave the app?',
      'profile_faq_a5':
          'Yes. Songs from the Music tab keep playing in the background. Use '
          'the notification or lock screen controls to pause or skip.',
      'profile_still_need_help': 'Still need help?',
      'profile_support_reply': 'Email us — we usually reply\nwithin 2 working days.',
      'profile_contact': 'Contact',

      // ── Splash (SplashScreen/splash_screen.dart) ───────────────────────
      'splash_could_not_open_store': 'Could not open the store',
      'splash_new_update_available': '🚀 New Update Available!',
      'splash_update_body':
          'A new version of Vidnexa is available! Version {new} is now available - you have {current}',
      'splash_update_prompt': ' Would you like to update it now?',
      'splash_whats_new': "What's New in Version {version}",
      'splash_update_now': 'Update Now',

      // ── Onboarding (OnboardScreen/onboarding_screen.dart) ──────────────
      'onboard_all_features': 'All Features',
      'onboard_skip': 'Skip',
      'onboard_data_safe': 'Your files stay on your phone.',
      'onboard_get_started': 'Get Started',
      'onboard_next': 'Next',

      // ── Permission (Permission/permission_page.dart) ───────────────────
      'perm_media_access_snackbar':
          'Media access is needed to show your videos. You can grant it later from Settings.',
      'perm_permission_needed_title': 'Permission needed',
      'perm_permission_needed_body':
          'Media access was permanently denied. Enable it in App settings to see your videos.',
      'perm_not_now': 'Not now',
      'perm_open_settings': 'Open settings',
      'perm_grant_permissions_title': 'Grant Permissions',
      'perm_grant_permissions_sub':
          'Allow access to the videos, music and photos on your device so the app can list and play them.',
      'perm_all_video_formats_title': 'All Video Formats',
      'perm_all_video_formats_sub': 'Support for MP4, AVI, MKV & more',
      'perm_music_photos_title': 'Music & Photos',
      'perm_music_photos_sub': 'Play your songs and browse your gallery',
      'perm_grant_all_button': 'Continue',
      'perm_skip_for_now': 'Skip for now',

      // ── Lock / Vault (LockScreen/LockScreen/lock_screen.dart) ──────────
      'lock_pin_set_success': 'PIN set successfully',
      'lock_too_many_attempts': 'Too many attempts. Try again in {secs}s.',
      'lock_unlock_vault_title': 'Unlock Vault',
      'lock_unlock_vault_sub': 'Enter your PIN to access secured files.',
      'lock_cancel': 'Cancel',
      'lock_too_many_wrong':
          'Too many wrong attempts. Locked for 1 minute.',
      'lock_wrong_pin': 'Wrong PIN',
      'lock_vault_title': 'Vault',
      'lock_add': 'Add',
      'lock_locked_badge': 'Locked',
      'lock_no_files_title': 'No files in vault',
      'lock_restore': 'Unhide',
      'lock_bio_reason': 'Unlock your vault',
      'lock_bio_turn_on': 'Turn on fingerprint unlock',
      'lock_bio_turn_off': 'Turn off fingerprint unlock',
      'lock_bio_on': 'Fingerprint unlock is on. Your PIN still works.',
      'lock_bio_off': 'Fingerprint unlock is off',

      // ── Vault redesign ──
      'lock_create_pin': 'Create a vault PIN',
      'lock_create_pin_sub': 'Use 4–6 digits. You will need it to open the vault.',
      'lock_confirm_pin': 'Confirm your PIN',
      'lock_confirm_pin_sub': 'Enter the same PIN again.',
      'lock_pin_mismatch': "The PINs didn't match. Start again.",
      'lock_use_fingerprint': 'Use fingerprint',
      'lock_filter_all': 'All',
      'lock_filter_photos': 'Photos',
      'lock_filter_videos': 'Videos',
      'lock_filter_docs': 'Documents',
      'lock_items_count': '{count} hidden',
      'lock_add_media': 'Photos & videos',
      'lock_add_media_sub': 'Pick from your gallery',
      'lock_add_docs': 'Documents',
      'lock_add_docs_sub': 'PDFs, Office files and more',
      'lock_hiding': 'Hiding {done} of {total}…',
      'lock_hidden_ok': '{count} hidden',
      'lock_hidden_partial':
          '{count} hidden. {kept} were not, because the original could not be removed.',
      'lock_hidden_none':
          'Nothing was hidden — the originals could not be removed.',
      'lock_restored_ok':
          '{count} unhidden. Photos and videos are back in the gallery, other '
          'files in Download/Vidnexa.',
      'lock_wrong_pin_left': 'Wrong PIN. {left} tries left.',
      'lock_unlock_button': 'Unlock',
      'lock_new_pin': 'Set a new PIN',
      'lock_pin_changed': 'PIN changed',
      'lock_change_pin': 'Change PIN',
      'lock_uninstall_warning':
          'Hidden files are kept inside this app. Unhide them before you '
          'uninstall the app or clear its data — otherwise they are lost.',
      'lock_restore_partial': '{count} unhidden, {failed} could not be.',
      'lock_hide_confirm_title': 'Hide {count}?',
      'lock_hide_confirm_body':
          'They move into your vault and disappear from the gallery. Nothing is '
          'deleted for good — Unhide puts them back.\n\nAndroid will now ask to '
          '"delete" them from the gallery. Tap Allow: that is how they get '
          'hidden.',
      'lock_hide_docs_confirm_body':
          'They move into your vault and disappear from your files. Nothing is '
          'deleted for good — Unhide puts them back.',
      'lock_hide': 'Hide',
      'lock_selected': '{count} selected',
      'lock_picker_title': 'Select to hide',
      'lock_picker_hide': 'Hide ({count})',
      'lock_picker_no_access': 'Allow access to photos and videos to hide them.',
      'lock_picker_empty': 'No photos or videos on this phone.',
      'lock_open_failed': 'No app on this phone can open this file.',
      'lock_empty_body': 'Tap Add to hide photos, videos, PDFs and more.',
    },
    'es': esProfile,
    'pt': ptProfile,
    'id': idProfile,
    'ar': arProfile,
    'bn': bnProfile,
    'ru': ruProfile,
    'tr': trProfile,
    'vi': viProfile,
    'hi': {
      // ── Profile tab (Home/Me/me.dart) ──────────────────────────────────
      'profile_edit_title': 'प्रोफ़ाइल संपादित करें',
      'profile_camera': 'कैमरा',
      'profile_gallery': 'गैलरी',
      'profile_display_name': 'प्रदर्शन नाम',
      'profile_save_changes': 'परिवर्तन सहेजें',

      'profile_quick_actions': 'त्वरित कार्रवाई',
      'profile_settings_more': 'सेटिंग्स और अधिक',

      'profile_guest_user': 'अतिथि उपयोगकर्ता',
      'profile_premium_member': 'प्रीमियम सदस्य',

      'profile_files': 'फ़ाइलें',
      'profile_music': 'संगीत',

      'profile_private': 'निजी',
      'profile_vault': 'वॉल्ट',

      'profile_section_features': '✦  सुविधाएं',
      'profile_section_preferences': '✦  प्राथमिकताएं',
      'profile_section_premium': '✦  प्रीमियम',
      'profile_section_support': '✦  सहायता',

      'profile_stream_title': 'स्ट्रीम',
      'profile_stream_sub': 'लिंक से वीडियो चलाएं',
      'profile_badge_new': 'नया',
      'profile_status_saver_title': 'स्टेटस सेवर',
      'profile_status_saver_sub': 'आपके कॉन्टैक्ट्स के शेयर किए गए स्टेटस सेव करें',
      'profile_badge_hot': 'हॉट',
      'profile_themes_title': 'थीम',
      'profile_themes_sub': 'अपने ऐप का रूप अनुकूलित करें',
      'profile_notifications_title': 'सूचनाएं',
      'profile_notifications_sub': 'अपडेट रहें, कुछ भी न चूकें',
      'profile_toolbar_color_title': 'टूलबार रंग',
      'profile_toolbar_color_sub': 'अपनी थीम को निजीकृत करें',
      'profile_language_title': 'भाषा',
      'profile_language_sub': 'ऐप की भाषा बदलें',
      'profile_text_size_title': 'टेक्स्ट का आकार',
      'profile_text_size_small': 'छोटा',
      'profile_text_size_default': 'सामान्य',
      'profile_text_size_large': 'बड़ा',
      'profile_text_size_larger': 'और बड़ा',
      'profile_privacy_title': 'गोपनीयता नीति',
      'profile_privacy_sub': 'गोपनीयता और सुरक्षा',
      'profile_ad_privacy_title': 'विज्ञापन गोपनीयता विकल्प',
      'profile_ad_privacy_sub': 'विज्ञापन सहमति बदलें',
      'profile_help_support_title': 'सहायता और समर्थन',
      'profile_help_support_sub': 'कभी भी सहायता प्राप्त करें',
      'profile_feedback_title': 'प्रतिक्रिया',
      'profile_feedback_sub': 'अपने विचार हमारे साथ साझा करें',
      'profile_share_app_title': 'ऐप शेयर करें',
      'profile_share_app_sub': 'अपने दोस्तों को आमंत्रित करें',
      'profile_screen_cast_title': 'स्क्रीन कास्ट',
      'profile_screen_cast_sub': 'इस फ़ोन को अपने TV पर दिखाएँ',
      'profile_screen_cast_failed':
          'इस फ़ोन में कास्ट स्क्रीन नहीं है। सेटिंग्स या क्विक टाइल्स में '
          'Cast या Screen mirroring ढूँढें।',

      'profile_night_mode_title': 'नाइट मोड',
      'profile_night_mode_dark': 'डार्क थीम सक्रिय',
      'profile_night_mode_light': 'लाइट थीम सक्रिय',

      'profile_remove_ads_title': 'विज्ञापन हटाएं',
      'profile_badge_pro': 'प्रो',
      'profile_remove_ads_sub': 'विज्ञापन-मुक्त अनुभव का आनंद लें',
      'profile_upgrade': 'अपग्रेड करें',

      'profile_rate_us_title': 'हमें रेट करें',

      'profile_email': 'ईमेल',
      'profile_frequently_asked': 'अक्सर पूछे जाने वाले प्रश्न',
      'profile_faq_q1': 'मेरे वीडियो या गाने नहीं दिख रहे',
      'profile_faq_a1':
          'ऐप के पूछने पर फ़ोटो, वीडियो और म्यूज़िक का एक्सेस दें। अगर आपने मना '
          'कर दिया था, तो Android Settings → Apps → Vidnexa → Permissions में '
          'जाकर अनुमति दें और ऐप दोबारा खोलें।',
      'profile_faq_q2': 'विज्ञापन कैसे हटाएं?',
      'profile_faq_a2':
          'प्रोफ़ाइल → Remove Ads → कोई प्लान चुनें। पहले ही भुगतान कर चुके हैं? '
          'उसी स्क्रीन पर उसी Google खाते से Restore Purchases दबाएं।',
      'profile_faq_q3': 'अपनी सदस्यता कैसे रद्द करें?',
      'profile_faq_a3':
          'Play Store → अपना प्रोफ़ाइल आइकन → Payments & subscriptions → '
          'Subscriptions → Vidnexa → Cancel। भुगतान की गई अवधि खत्म होने तक '
          'प्रीमियम चालू रहेगा।',
      'profile_faq_q4': 'वॉल्ट PIN भूल गए?',
      'profile_faq_a4':
          'PIN सिर्फ़ आपके फ़ोन पर सुरक्षित हैश के रूप में रखा जाता है, इसलिए हम '
          'इसे देख या रीसेट नहीं कर सकते। फ़िंगरप्रिंट अनलॉक चालू है तो उससे खोलें। '
          'वरना वॉल्ट नहीं खुल सकता — ऐप का डेटा साफ़ करने से PIN हट जाता है, पर '
          'वॉल्ट की फ़ाइलें भी हमेशा के लिए डिलीट हो जाती हैं।',
      'profile_faq_q5': 'क्या ऐप से बाहर जाने पर गाने चलते रहते हैं?',
      'profile_faq_a5':
          'हाँ। Music टैब के गाने बैकग्राउंड में चलते रहते हैं। रोकने या अगला '
          'गाना चलाने के लिए नोटिफ़िकेशन या लॉक स्क्रीन कंट्रोल इस्तेमाल करें।',
      'profile_still_need_help': 'फिर भी सहायता चाहिए?',
      'profile_support_reply': 'हमें ईमेल करें — हम आमतौर पर\n2 कार्यदिवसों में जवाब देते हैं।',
      'profile_contact': 'संपर्क करें',

      // ── Splash (SplashScreen/splash_screen.dart) ───────────────────────
      'splash_could_not_open_store': 'स्टोर नहीं खोला जा सका',
      'splash_new_update_available': '🚀 नया अपडेट उपलब्ध है!',
      'splash_update_body':
          'Vidnexa का नया संस्करण उपलब्ध है! संस्करण {new} अब उपलब्ध है - आपके पास {current} है',
      'splash_update_prompt': ' क्या आप अभी इसे अपडेट करना चाहेंगे?',
      'splash_whats_new': 'संस्करण {version} में नया क्या है',
      'splash_update_now': 'अभी अपडेट करें',

      // ── Onboarding (OnboardScreen/onboarding_screen.dart) ──────────────
      'onboard_all_features': 'सभी सुविधाएं',
      'onboard_skip': 'छोड़ें',
      'onboard_data_safe': 'आपकी फ़ाइलें आपके फ़ोन पर ही रहती हैं।',
      'onboard_get_started': 'शुरू करें',
      'onboard_next': 'अगला',

      // ── Permission (Permission/permission_page.dart) ───────────────────
      'perm_media_access_snackbar':
          'आपके वीडियो दिखाने के लिए मीडिया एक्सेस आवश्यक है। आप इसे बाद में सेटिंग्स से दे सकते हैं।',
      'perm_permission_needed_title': 'अनुमति आवश्यक है',
      'perm_permission_needed_body':
          'मीडिया एक्सेस स्थायी रूप से अस्वीकृत कर दी गई थी। अपने वीडियो देखने के लिए इसे ऐप सेटिंग्स में सक्षम करें।',
      'perm_not_now': 'अभी नहीं',
      'perm_open_settings': 'सेटिंग्स खोलें',
      'perm_grant_permissions_title': 'अनुमतियां दें',
      'perm_grant_permissions_sub':
          'ऐप आपके वीडियो, गाने और फ़ोटो दिखा और चला सके, इसके लिए उनका एक्सेस दें।',
      'perm_all_video_formats_title': 'सभी वीडियो प्रारूप',
      'perm_all_video_formats_sub': 'MP4, AVI, MKV और अधिक का समर्थन',
      'perm_music_photos_title': 'म्यूज़िक और फ़ोटो',
      'perm_music_photos_sub': 'अपने गाने चलाएं और गैलरी देखें',
      'perm_grant_all_button': 'जारी रखें',
      'perm_skip_for_now': 'अभी के लिए छोड़ें',

      // ── Lock / Vault (LockScreen/LockScreen/lock_screen.dart) ──────────
      'lock_pin_set_success': 'पिन सफलतापूर्वक सेट हो गया',
      'lock_too_many_attempts': 'बहुत अधिक प्रयास। {secs} सेकंड में पुनः प्रयास करें।',
      'lock_unlock_vault_title': 'वॉल्ट अनलॉक करें',
      'lock_unlock_vault_sub': 'सुरक्षित फ़ाइलों तक पहुंचने के लिए अपना पिन दर्ज करें।',
      'lock_cancel': 'रद्द करें',
      'lock_too_many_wrong': 'बहुत अधिक गलत प्रयास। 1 मिनट के लिए लॉक कर दिया गया।',
      'lock_wrong_pin': 'गलत पिन',
      'lock_vault_title': 'वॉल्ट',
      'lock_add': 'जोड़ें',
      'lock_locked_badge': 'लॉक्ड',
      'lock_no_files_title': 'वॉल्ट में कोई फ़ाइल नहीं है',
      'lock_restore': 'अनहाइड करें',
      'lock_bio_reason': 'अपना वॉल्ट अनलॉक करें',
      'lock_bio_turn_on': 'फ़िंगरप्रिंट अनलॉक चालू करें',
      'lock_bio_turn_off': 'फ़िंगरप्रिंट अनलॉक बंद करें',
      'lock_bio_on': 'फ़िंगरप्रिंट अनलॉक चालू है। आपका PIN भी काम करेगा।',
      'lock_bio_off': 'फ़िंगरप्रिंट अनलॉक बंद है',

      // ── Vault redesign ──
      'lock_create_pin': 'वॉल्ट PIN बनाएँ',
      'lock_create_pin_sub': '4–6 अंक रखें। वॉल्ट खोलने के लिए यही चाहिए होगा।',
      'lock_confirm_pin': 'PIN दोबारा डालें',
      'lock_confirm_pin_sub': 'वही PIN फिर से डालें।',
      'lock_pin_mismatch': 'दोनों PIN अलग थे। फिर से शुरू करें।',
      'lock_use_fingerprint': 'फ़िंगरप्रिंट से खोलें',
      'lock_filter_all': 'सब',
      'lock_filter_photos': 'फ़ोटो',
      'lock_filter_videos': 'वीडियो',
      'lock_filter_docs': 'डॉक्यूमेंट',
      'lock_items_count': '{count} छिपी हुई',
      'lock_add_media': 'फ़ोटो और वीडियो',
      'lock_add_media_sub': 'गैलरी से चुनें',
      'lock_add_docs': 'डॉक्यूमेंट',
      'lock_add_docs_sub': 'PDF, Office फ़ाइलें और भी',
      'lock_hiding': '{total} में से {done} छिपा रहे हैं…',
      'lock_hidden_ok': '{count} छिप गईं',
      'lock_hidden_partial':
          '{count} छिप गईं। {kept} नहीं छिपीं, क्योंकि ओरिजिनल हटाई नहीं जा सकी।',
      'lock_hidden_none': 'कुछ नहीं छिपा — ओरिजिनल फ़ाइलें हटाई नहीं जा सकीं।',
      'lock_restored_ok':
          '{count} अनहाइड हुईं। फ़ोटो और वीडियो गैलरी में वापस आ गए, बाकी फ़ाइलें '
          'Download/Vidnexa में।',
      'lock_wrong_pin_left': 'गलत PIN। {left} कोशिशें बाकी।',
      'lock_unlock_button': 'अनलॉक',
      'lock_new_pin': 'नया PIN बनाएँ',
      'lock_pin_changed': 'PIN बदल गया',
      'lock_change_pin': 'PIN बदलें',
      'lock_uninstall_warning':
          'छिपी हुई फ़ाइलें इसी ऐप के अंदर रखी जाती हैं। ऐप अनइंस्टॉल करने या '
          'उसका डेटा साफ़ करने से पहले इन्हें अनहाइड कर लें — वरना ये खो जाएँगी।',
      'lock_restore_partial': '{count} अनहाइड हुईं, {failed} नहीं हो सकीं।',
      'lock_hide_confirm_title': '{count} छिपाएँ?',
      'lock_hide_confirm_body':
          'ये आपके वॉल्ट में चली जाएँगी और गैलरी से छिप जाएँगी। कुछ भी हमेशा के '
          'लिए डिलीट नहीं होता — अनहाइड करने पर वापस आ जाती हैं।\n\nअब Android '
          'गैलरी से "डिलीट" करने की अनुमति पूछेगा। Allow दबाएँ — इसी से ये छिपती हैं।',
      'lock_hide_docs_confirm_body':
          'ये आपके वॉल्ट में चली जाएँगी और फ़ाइलों से छिप जाएँगी। कुछ भी हमेशा के '
          'लिए डिलीट नहीं होता — अनहाइड करने पर वापस आ जाती हैं।',
      'lock_hide': 'छिपाएँ',
      'lock_selected': '{count} चुनी गईं',
      'lock_picker_title': 'छिपाने के लिए चुनें',
      'lock_picker_hide': 'छिपाएँ ({count})',
      'lock_picker_no_access': 'छिपाने के लिए फ़ोटो और वीडियो का एक्सेस दें।',
      'lock_picker_empty': 'इस फ़ोन पर कोई फ़ोटो या वीडियो नहीं है।',
      'lock_open_failed': 'इस फ़ाइल को खोलने वाला कोई ऐप नहीं है।',
      'lock_empty_body': 'फ़ोटो, वीडियो, PDF और भी छिपाने के लिए Add दबाएँ।',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
