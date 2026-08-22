/// Tiny in-code translation table for the Bottom Navigation Bar and the
/// drawer (SettingsScreen) — the two surfaces the language picker currently
/// covers. Only `en` and `hi` are actually translated; any other locale code
/// falls back to English until real translations are added for it.
class AppStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      'nav_home': 'Home',
      'nav_music': 'Music',
      'nav_online': 'Online',
      'nav_profile': 'Profile',

      'drawer_main_features': 'Main Features',
      'drawer_dashboard': 'Dashboard',
      'drawer_dashboard_sub': 'Track Performance',
      'drawer_all_photos': 'All Photos',
      'drawer_all_photos_sub': 'Captured Bliss',
      'drawer_all_musics': 'All Musics',
      'drawer_all_musics_sub': 'Melodic Echoes',
      'drawer_vidstream': 'VidStream',
      'drawer_vidstream_sub': 'Instant Video, One Click Away',
      'drawer_file_manager': 'File Manager',
      'drawer_file_manager_sub': 'All Files, Anywhere, Anytime',
      'drawer_status_saver': 'Status Saver',
      'drawer_status_saver_sub': 'Save videos and images easily',

      'drawer_preferences': 'Preferences',
      'drawer_night_mode': 'Night Mode',
      'drawer_night_mode_sub': 'Comfortable viewing at night',
      'drawer_theme': 'Theme',
      'drawer_theme_sub': 'Choose app appearance',
      'drawer_language': 'Language',
      'drawer_language_sub': 'Change app language',

      'drawer_support_more': 'Support & More',
      'drawer_notifications': 'Notifications',
      'drawer_notifications_sub': 'Stay Updated, Never Miss Out',
      'drawer_privacy': 'Privacy',
      'drawer_privacy_sub': 'Privacy & security',
      'drawer_rate_us': 'Rate Us',
      'drawer_rate_us_sub': 'Rate app on Play Store',
      'drawer_help_support': 'Help & Support',
      'drawer_help_support_sub': 'Get help when you need it',
      'drawer_feedback': 'Feedback',
      'drawer_feedback_sub': 'Share your thoughts with us',
      'drawer_share_app': 'Share App',
      'drawer_share_app_sub': 'Invite your friends',

      'choose_language': 'Choose Language',
      'apply': 'Apply',
    },
    'hi': {
      'nav_home': 'होम',
      'nav_music': 'संगीत',
      'nav_online': 'ऑनलाइन',
      'nav_profile': 'प्रोफ़ाइल',

      'drawer_main_features': 'मुख्य सुविधाएं',
      'drawer_dashboard': 'डैशबोर्ड',
      'drawer_dashboard_sub': 'प्रदर्शन ट्रैक करें',
      'drawer_all_photos': 'सभी फ़ोटो',
      'drawer_all_photos_sub': 'कैद किए पल',
      'drawer_all_musics': 'सभी संगीत',
      'drawer_all_musics_sub': 'मधुर गूंज',
      'drawer_vidstream': 'विडस्ट्रीम',
      'drawer_vidstream_sub': 'एक क्लिक में वीडियो',
      'drawer_file_manager': 'फ़ाइल मैनेजर',
      'drawer_file_manager_sub': 'सभी फ़ाइलें, कभी भी, कहीं भी',
      'drawer_status_saver': 'स्टेटस सेवर',
      'drawer_status_saver_sub': 'वीडियो और फ़ोटो आसानी से सेव करें',

      'drawer_preferences': 'प्राथमिकताएं',
      'drawer_night_mode': 'नाइट मोड',
      'drawer_night_mode_sub': 'रात में आरामदायक व्यूइंग',
      'drawer_theme': 'थीम',
      'drawer_theme_sub': 'ऐप का रूप चुनें',
      'drawer_language': 'भाषा',
      'drawer_language_sub': 'ऐप की भाषा बदलें',

      'drawer_support_more': 'सहायता और अधिक',
      'drawer_notifications': 'सूचनाएं',
      'drawer_notifications_sub': 'अपडेट रहें, कुछ भी न चूकें',
      'drawer_privacy': 'गोपनीयता',
      'drawer_privacy_sub': 'गोपनीयता और सुरक्षा',
      'drawer_rate_us': 'हमें रेट करें',
      'drawer_rate_us_sub': 'प्ले स्टोर पर ऐप रेट करें',
      'drawer_help_support': 'सहायता और समर्थन',
      'drawer_help_support_sub': 'जरूरत पड़ने पर मदद पाएं',
      'drawer_feedback': 'प्रतिक्रिया',
      'drawer_feedback_sub': 'अपने विचार हमारे साथ साझा करें',
      'drawer_share_app': 'ऐप शेयर करें',
      'drawer_share_app_sub': 'अपने दोस्तों को आमंत्रित करें',

      'choose_language': 'भाषा चुनें',
      'apply': 'लागू करें',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
