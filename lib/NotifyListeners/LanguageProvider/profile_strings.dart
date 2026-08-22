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

      'profile_storage_overview': 'Storage Overview',
      'profile_quick_actions': 'Quick Actions',
      'profile_settings_more': 'Settings & More',

      'profile_guest_user': 'Guest User',
      'profile_premium_member': 'PREMIUM MEMBER',

      'profile_files': 'Files',
      'profile_videos': 'Videos',
      'profile_music': 'Music',
      'profile_images': 'Images',

      'profile_folders': 'Folders',
      'profile_downloads': 'Downloads',
      'profile_private': 'Private',
      'profile_vault': 'Vault',
      'profile_add_new': 'Add New',
      'profile_playlist': 'Playlist',

      'profile_section_features': '✦  Features',
      'profile_section_preferences': '✦  Preferences',
      'profile_section_premium': '✦  Premium',
      'profile_section_support': '✦  Support',

      'profile_stream_title': 'Stream',
      'profile_stream_sub': 'Play online videos & IPTV',
      'profile_badge_new': 'NEW',
      'profile_status_saver_title': 'Status Saver',
      'profile_status_saver_sub': 'Save WhatsApp & Instagram status',
      'profile_badge_hot': 'HOT',
      'profile_themes_title': 'Themes',
      'profile_themes_sub': 'Customize your app look',
      'profile_notifications_title': 'Notifications',
      'profile_notifications_sub': 'Stay updated, never miss out',
      'profile_toolbar_color_title': 'Toolbar Color',
      'profile_toolbar_color_sub': 'Personalize your theme',
      'profile_language_title': 'Language',
      'profile_language_sub': 'Change app language',
      'profile_privacy_title': 'Privacy Policy',
      'profile_privacy_sub': 'Privacy & security',
      'profile_help_support_title': 'Help & Support',
      'profile_help_support_sub': 'Get assistance anytime',
      'profile_feedback_title': 'Feedback',
      'profile_feedback_sub': 'Share your thoughts with us',
      'profile_share_app_title': 'Share App',
      'profile_share_app_sub': 'Invite your friends',

      'profile_night_mode_title': 'Night Mode',
      'profile_night_mode_dark': 'Dark theme active',
      'profile_night_mode_light': 'Light theme active',

      'profile_remove_ads_title': 'Remove Ads',
      'profile_badge_pro': 'PRO',
      'profile_remove_ads_sub': 'Enjoy an ad-free experience',
      'profile_upgrade': 'Upgrade',

      'profile_rate_us_title': 'Rate Us',

      'profile_search_help': 'Search help articles...',
      'profile_live_chat': 'Live Chat',
      'profile_call_us': 'Call Us',
      'profile_email': 'Email',
      'profile_frequently_asked': 'Frequently Asked',
      'profile_faq_q1': 'How do I reset my password?',
      'profile_faq_a1':
          'Go to Login screen → tap "Forgot Password" → enter your email and follow the instructions sent to you.',
      'profile_faq_q2': 'How to update my profile details?',
      'profile_faq_a2':
          'Navigate to Profile → Edit Profile → update the required fields and tap Save.',
      'profile_faq_q3': 'Where can I see my fee receipts?',
      'profile_faq_a3':
          'Go to Fees section → tap on any paid fee → download or view the receipt from there.',
      'profile_faq_q4': 'How do I join a video class?',
      'profile_faq_a4':
          'Open the Timetable → select the ongoing class card → tap Join Class button.',
      'profile_still_need_help': 'Still need help?',
      'profile_support_247': 'Our support team is\navailable 24/7 for you.',
      'profile_contact': 'Contact',

      // ── Splash (SplashScreen/splash_screen.dart) ───────────────────────
      'splash_could_not_open_store': 'Could not open the store',
      'splash_new_update_available': '🚀 New Update Available!',
      'splash_update_body':
          'A new version of Upgrader is available! Version {new} is now available - you have {current}',
      'splash_update_prompt': ' Would you like to update it now?',
      'splash_whats_new': "What's New in Version {version}",
      'splash_update_now': 'Update Now',

      // ── Onboarding (OnboardScreen/onboarding_screen.dart) ──────────────
      'onboard_all_features': 'All Features',
      'onboard_skip': 'Skip',
      'onboard_data_safe': 'Your data is safe with us.',
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
          'Please grant access to all video files on your device for the best experience',
      'perm_all_video_formats_title': 'All Video Formats',
      'perm_all_video_formats_sub': 'Support for MP4, AVI, MKV & more',
      'perm_subtitle_files_title': 'Subtitle Files',
      'perm_subtitle_files_sub': 'SRT, ASS, VTT & embedded subs',
      'perm_grant_all_button': 'Grant All Permissions',
      'perm_skip_for_now': 'Skip for now',

      // ── Lock / Vault (LockScreen/LockScreen/lock_screen.dart) ──────────
      'lock_set_pin_title': 'Set Vault PIN',
      'lock_set_pin_sub': 'Create a 4–6 digit PIN to protect your files.',
      'lock_enter_pin_hint': 'Enter 4–6 digit PIN',
      'lock_min_digits': 'Minimum 4 digits required',
      'lock_max_digits': 'Maximum 6 digits allowed',
      'lock_save_pin': 'Save PIN',
      'lock_pin_set_success': 'PIN set successfully',
      'lock_too_many_attempts': 'Too many attempts. Try again in {secs}s.',
      'lock_unlock_vault_title': 'Unlock Vault',
      'lock_unlock_vault_sub': 'Enter your PIN to access secured files.',
      'lock_enter_pin_short': 'Enter PIN',
      'lock_pin_required': 'PIN required',
      'lock_wrong_pin_length': 'Wrong PIN length',
      'lock_unlock': 'Unlock',
      'lock_cancel': 'Cancel',
      'lock_too_many_wrong':
          'Too many wrong attempts. Locked for 1 minute.',
      'lock_wrong_pin': 'Wrong PIN',
      'lock_moved_to_vault': 'Moved to vault',
      'lock_copied_to_vault':
          'Copied to vault — the original could not be removed',
      'lock_could_not_add': 'Could not add to vault: {error}',
      'lock_restored_to': 'Restored to: {path}',
      'lock_restore_cancelled': 'Restore cancelled / failed',
      'lock_delete_file_title': 'Delete file?',
      'lock_delete_file_body': 'This will remove the file from vault.',
      'lock_delete': 'Delete',
      'lock_deleted_from_vault': 'Deleted from vault',
      'lock_vault_title': 'Vault',
      'lock_secured_unlocked': 'Secured files unlocked',
      'lock_locked_enter_pin': 'Locked • Enter PIN to access',
      'lock_add': 'Add',
      'lock_refresh': 'Refresh',
      'lock_locked_badge': 'Locked',
      'lock_vault_locked_title': 'Vault Locked',
      'lock_vault_locked_body':
          'Your files are protected with a PIN.\nUnlock to view and manage them.',
      'lock_unlock_vault_button': 'Unlock Vault',
      'lock_no_files_title': 'No files in vault',
      'lock_no_files_body':
          'Tap "Add File" to secure your photos, videos, PDFs, and more.',
      'lock_restore': 'Restore',
      'lock_delete_from_vault': 'Delete from Vault',
      'lock_add_file': 'Add File',
      'lock_syncing': 'Syncing…',
    },
    'hi': {
      // ── Profile tab (Home/Me/me.dart) ──────────────────────────────────
      'profile_edit_title': 'प्रोफ़ाइल संपादित करें',
      'profile_camera': 'कैमरा',
      'profile_gallery': 'गैलरी',
      'profile_display_name': 'प्रदर्शन नाम',
      'profile_save_changes': 'परिवर्तन सहेजें',

      'profile_storage_overview': 'स्टोरेज अवलोकन',
      'profile_quick_actions': 'त्वरित कार्रवाई',
      'profile_settings_more': 'सेटिंग्स और अधिक',

      'profile_guest_user': 'अतिथि उपयोगकर्ता',
      'profile_premium_member': 'प्रीमियम सदस्य',

      'profile_files': 'फ़ाइलें',
      'profile_videos': 'वीडियो',
      'profile_music': 'संगीत',
      'profile_images': 'फ़ोटो',

      'profile_folders': 'फ़ोल्डर',
      'profile_downloads': 'डाउनलोड',
      'profile_private': 'निजी',
      'profile_vault': 'वॉल्ट',
      'profile_add_new': 'नया जोड़ें',
      'profile_playlist': 'प्लेलिस्ट',

      'profile_section_features': '✦  सुविधाएं',
      'profile_section_preferences': '✦  प्राथमिकताएं',
      'profile_section_premium': '✦  प्रीमियम',
      'profile_section_support': '✦  सहायता',

      'profile_stream_title': 'स्ट्रीम',
      'profile_stream_sub': 'ऑनलाइन वीडियो और आईपीटीवी चलाएं',
      'profile_badge_new': 'नया',
      'profile_status_saver_title': 'स्टेटस सेवर',
      'profile_status_saver_sub': 'व्हाट्सएप और इंस्टाग्राम स्टेटस सेव करें',
      'profile_badge_hot': 'हॉट',
      'profile_themes_title': 'थीम',
      'profile_themes_sub': 'अपने ऐप का रूप अनुकूलित करें',
      'profile_notifications_title': 'सूचनाएं',
      'profile_notifications_sub': 'अपडेट रहें, कुछ भी न चूकें',
      'profile_toolbar_color_title': 'टूलबार रंग',
      'profile_toolbar_color_sub': 'अपनी थीम को निजीकृत करें',
      'profile_language_title': 'भाषा',
      'profile_language_sub': 'ऐप की भाषा बदलें',
      'profile_privacy_title': 'गोपनीयता नीति',
      'profile_privacy_sub': 'गोपनीयता और सुरक्षा',
      'profile_help_support_title': 'सहायता और समर्थन',
      'profile_help_support_sub': 'कभी भी सहायता प्राप्त करें',
      'profile_feedback_title': 'प्रतिक्रिया',
      'profile_feedback_sub': 'अपने विचार हमारे साथ साझा करें',
      'profile_share_app_title': 'ऐप शेयर करें',
      'profile_share_app_sub': 'अपने दोस्तों को आमंत्रित करें',

      'profile_night_mode_title': 'नाइट मोड',
      'profile_night_mode_dark': 'डार्क थीम सक्रिय',
      'profile_night_mode_light': 'लाइट थीम सक्रिय',

      'profile_remove_ads_title': 'विज्ञापन हटाएं',
      'profile_badge_pro': 'प्रो',
      'profile_remove_ads_sub': 'विज्ञापन-मुक्त अनुभव का आनंद लें',
      'profile_upgrade': 'अपग्रेड करें',

      'profile_rate_us_title': 'हमें रेट करें',

      'profile_search_help': 'सहायता लेख खोजें...',
      'profile_live_chat': 'लाइव चैट',
      'profile_call_us': 'हमें कॉल करें',
      'profile_email': 'ईमेल',
      'profile_frequently_asked': 'अक्सर पूछे जाने वाले प्रश्न',
      'profile_faq_q1': 'मैं अपना पासवर्ड कैसे रीसेट करूं?',
      'profile_faq_a1':
          'लॉगिन स्क्रीन पर जाएं → "पासवर्ड भूल गए" पर टैप करें → अपना ईमेल दर्ज करें और भेजे गए निर्देशों का पालन करें।',
      'profile_faq_q2': 'मैं अपनी प्रोफ़ाइल जानकारी कैसे अपडेट करूं?',
      'profile_faq_a2':
          'प्रोफ़ाइल पर जाएं → प्रोफ़ाइल संपादित करें → आवश्यक फ़ील्ड अपडेट करें और सेव पर टैप करें।',
      'profile_faq_q3': 'मैं अपनी फीस रसीदें कहां देख सकता हूं?',
      'profile_faq_a3':
          'फीस अनुभाग पर जाएं → किसी भी भुगतान की गई फीस पर टैप करें → वहां से रसीद डाउनलोड करें या देखें।',
      'profile_faq_q4': 'मैं वीडियो क्लास में कैसे शामिल हों?',
      'profile_faq_a4':
          'टाइमटेबल खोलें → चल रही क्लास कार्ड चुनें → जॉइन क्लास बटन पर टैप करें।',
      'profile_still_need_help': 'फिर भी सहायता चाहिए?',
      'profile_support_247': 'हमारी सहायता टीम\nआपके लिए 24/7 उपलब्ध है।',
      'profile_contact': 'संपर्क करें',

      // ── Splash (SplashScreen/splash_screen.dart) ───────────────────────
      'splash_could_not_open_store': 'स्टोर नहीं खोला जा सका',
      'splash_new_update_available': '🚀 नया अपडेट उपलब्ध है!',
      'splash_update_body':
          'अपग्रेडर का नया संस्करण उपलब्ध है! संस्करण {new} अब उपलब्ध है - आपके पास {current} है',
      'splash_update_prompt': ' क्या आप अभी इसे अपडेट करना चाहेंगे?',
      'splash_whats_new': 'संस्करण {version} में नया क्या है',
      'splash_update_now': 'अभी अपडेट करें',

      // ── Onboarding (OnboardScreen/onboarding_screen.dart) ──────────────
      'onboard_all_features': 'सभी सुविधाएं',
      'onboard_skip': 'छोड़ें',
      'onboard_data_safe': 'आपका डेटा हमारे साथ सुरक्षित है।',
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
          'सर्वश्रेष्ठ अनुभव के लिए कृपया अपने डिवाइस की सभी वीडियो फ़ाइलों तक पहुंच प्रदान करें',
      'perm_all_video_formats_title': 'सभी वीडियो प्रारूप',
      'perm_all_video_formats_sub': 'MP4, AVI, MKV और अधिक का समर्थन',
      'perm_subtitle_files_title': 'सबटाइटल फ़ाइलें',
      'perm_subtitle_files_sub': 'SRT, ASS, VTT और एम्बेडेड सबटाइटल',
      'perm_grant_all_button': 'सभी अनुमतियां दें',
      'perm_skip_for_now': 'अभी के लिए छोड़ें',

      // ── Lock / Vault (LockScreen/LockScreen/lock_screen.dart) ──────────
      'lock_set_pin_title': 'वॉल्ट पिन सेट करें',
      'lock_set_pin_sub': 'अपनी फ़ाइलों की सुरक्षा के लिए 4-6 अंकों का पिन बनाएं।',
      'lock_enter_pin_hint': '4-6 अंकों का पिन दर्ज करें',
      'lock_min_digits': 'न्यूनतम 4 अंक आवश्यक हैं',
      'lock_max_digits': 'अधिकतम 6 अंकों की अनुमति है',
      'lock_save_pin': 'पिन सहेजें',
      'lock_pin_set_success': 'पिन सफलतापूर्वक सेट हो गया',
      'lock_too_many_attempts': 'बहुत अधिक प्रयास। {secs} सेकंड में पुनः प्रयास करें।',
      'lock_unlock_vault_title': 'वॉल्ट अनलॉक करें',
      'lock_unlock_vault_sub': 'सुरक्षित फ़ाइलों तक पहुंचने के लिए अपना पिन दर्ज करें।',
      'lock_enter_pin_short': 'पिन दर्ज करें',
      'lock_pin_required': 'पिन आवश्यक है',
      'lock_wrong_pin_length': 'गलत पिन लंबाई',
      'lock_unlock': 'अनलॉक करें',
      'lock_cancel': 'रद्द करें',
      'lock_too_many_wrong': 'बहुत अधिक गलत प्रयास। 1 मिनट के लिए लॉक कर दिया गया।',
      'lock_wrong_pin': 'गलत पिन',
      'lock_moved_to_vault': 'वॉल्ट में ले जाया गया',
      'lock_copied_to_vault':
          'वॉल्ट में कॉपी किया गया — मूल फ़ाइल हटाई नहीं जा सकी',
      'lock_could_not_add': 'वॉल्ट में जोड़ा नहीं जा सका: {error}',
      'lock_restored_to': 'यहां पुनर्स्थापित किया गया: {path}',
      'lock_restore_cancelled': 'पुनर्स्थापना रद्द / विफल हुई',
      'lock_delete_file_title': 'फ़ाइल हटाएं?',
      'lock_delete_file_body': 'यह फ़ाइल को वॉल्ट से हटा देगा।',
      'lock_delete': 'हटाएं',
      'lock_deleted_from_vault': 'वॉल्ट से हटा दिया गया',
      'lock_vault_title': 'वॉल्ट',
      'lock_secured_unlocked': 'सुरक्षित फ़ाइलें अनलॉक की गईं',
      'lock_locked_enter_pin': 'लॉक्ड • एक्सेस के लिए पिन दर्ज करें',
      'lock_add': 'जोड़ें',
      'lock_refresh': 'रीफ़्रेश करें',
      'lock_locked_badge': 'लॉक्ड',
      'lock_vault_locked_title': 'वॉल्ट लॉक्ड',
      'lock_vault_locked_body':
          'आपकी फ़ाइलें पिन से सुरक्षित हैं।\nउन्हें देखने और प्रबंधित करने के लिए अनलॉक करें।',
      'lock_unlock_vault_button': 'वॉल्ट अनलॉक करें',
      'lock_no_files_title': 'वॉल्ट में कोई फ़ाइल नहीं है',
      'lock_no_files_body':
          'अपनी फ़ोटो, वीडियो, पीडीएफ़ और अन्य को सुरक्षित करने के लिए "फ़ाइल जोड़ें" पर टैप करें।',
      'lock_restore': 'पुनर्स्थापित करें',
      'lock_delete_from_vault': 'वॉल्ट से हटाएं',
      'lock_add_file': 'फ़ाइल जोड़ें',
      'lock_syncing': 'सिंक हो रहा है…',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
