/// Tiny in-code translation table for miscellaneous, scattered UI surfaces
/// (notifications screen, toolbar color picker, internet banner, rating /
/// feedback popup, ad "Sponsored" labels, voice search) that aren't covered
/// by [AppStrings]. Kept as a fully separate namespace/class on purpose so
/// parallel work on other screens doesn't collide with the same file.
///
/// Only `en` and `hi` are actually translated; any other locale code falls
/// back to English until real translations are added for it.
class MiscStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // ---- Notification screen ----
      'notification_title': 'Notifications',
      'notification_empty_title': 'No Notifications Yet',
      'notification_empty_subtitle':
          "You're all caught up! We'll notify you when there's something new",
      'go_back': 'Go Back',

      // ---- Toolbar color picker ----
      'colorpicker_title': 'Select ToolBar Color',
      'reset': 'Reset',

      // ---- Internet status banner ----
      'internet_banner_offline': 'No internet connection',

      // ---- Rating popup ----
      'rating_popup_title': 'Please Rate Vidnexa Player',
      'rating_popup_subtitle': 'Help us improve with your honest rating.',
      'rating_hint_0': 'Swipe right for stars (1–5)',
      'rating_hint_low': 'Sorry to hear that — tell us what broke',
      'rating_hint_mid': 'Thanks. What would make it a 5?',
      'rating_hint_good': 'Glad it works for you',
      'rating_hint_great': 'Brilliant — thank you!',
      'rating_pick_stars': 'Pick your stars to continue',
      'rating_cta_playstore': 'Rate on Play Store',
      'rating_cta_feedback': 'Send feedback',
      'rating_never_ask': "Don't ask again",
      'rating_later': 'Later',
      'rating_playstore_open_failed': 'Could not open the Play Store',
      'feedback_title': 'What can we fix?',
      'feedback_subtitle':
          'This goes straight to the team — it is not posted publicly.',
      'feedback_hint': 'Playback issues, missing formats, crashes…',
      'feedback_not_now': 'Not now',
      'feedback_sent_snackbar': 'Thanks for the feedback!',

      // ---- Ads ----
      'ads_sponsored': 'Sponsored',

      // ---- Voice search ----
      'voice_search_title': 'Voice Search',
      'voice_search_listening': 'Listening...',
      'voice_search_found_template': 'Found {count} {noun}',
      'voice_search_noun_videos': 'videos',
      'voice_search_noun_photos': 'photos',
      'voice_search_noun_songs': 'songs',
      'voice_search_video_unavailable': 'This video is no longer available.',
      'voice_search_photo_unavailable': 'This photo is no longer available.',
      'voice_search_song_unavailable': 'This song is no longer available.',
      'voice_search_hint_try': 'Tap the mic and try a command like:',
      'voice_search_processing': 'Processing...',
      'voice_search_searching': 'Searching...',
      'voice_search_no_results_template': 'No {noun} found',
      'voice_search_try_saying': 'Try saying:',
      'voice_search_mic_needed_title': 'Microphone access needed',
      'voice_search_mic_needed_subtitle':
          'Voice search needs microphone access to hear your command. '
          'You can grant it from Settings.',
      'voice_search_open_settings': 'Open Settings',
      'voice_search_something_wrong': 'Something went wrong',
      'voice_search_please_try_again': 'Please try again.',
      'voice_search_try_again': 'Try Again',
    },
    'hi': {
      // ---- Notification screen ----
      'notification_title': 'सूचनाएं',
      'notification_empty_title': 'अभी कोई सूचना नहीं',
      'notification_empty_subtitle':
          'आप पूरी तरह अपडेट हैं! कुछ नया होने पर हम आपको सूचित करेंगे',
      'go_back': 'वापस जाएं',

      // ---- Toolbar color picker ----
      'colorpicker_title': 'टूलबार का रंग चुनें',
      'reset': 'रीसेट करें',

      // ---- Internet status banner ----
      'internet_banner_offline': 'इंटरनेट कनेक्शन नहीं है',

      // ---- Rating popup ----
      'rating_popup_title': 'कृपया Vidnexa Player को रेट करें',
      'rating_popup_subtitle': 'अपनी ईमानदार रेटिंग से हमें बेहतर बनाने में मदद करें।',
      'rating_hint_0': 'सितारे देने के लिए दाईं ओर स्वाइप करें (1–5)',
      'rating_hint_low': 'यह सुनकर खेद है — हमें बताएं क्या गड़बड़ हुई',
      'rating_hint_mid': 'धन्यवाद। इसे 5 बनाने के लिए क्या चाहिए?',
      'rating_hint_good': 'खुशी है कि यह आपके लिए ठीक काम कर रहा है',
      'rating_hint_great': 'शानदार — धन्यवाद!',
      'rating_pick_stars': 'जारी रखने के लिए सितारे चुनें',
      'rating_cta_playstore': 'Play Store पर रेट करें',
      'rating_cta_feedback': 'फ़ीडबैक भेजें',
      'rating_never_ask': 'दोबारा न पूछें',
      'rating_later': 'बाद में',
      'rating_playstore_open_failed': 'Play Store नहीं खोला जा सका',
      'feedback_title': 'हम क्या ठीक कर सकते हैं?',
      'feedback_subtitle':
          'यह सीधे टीम तक पहुंचता है — इसे सार्वजनिक रूप से पोस्ट नहीं किया जाता।',
      'feedback_hint': 'प्लेबैक समस्याएं, गायब फॉर्मेट, क्रैश…',
      'feedback_not_now': 'अभी नहीं',
      'feedback_sent_snackbar': 'फ़ीडबैक के लिए धन्यवाद!',

      // ---- Ads ----
      'ads_sponsored': 'प्रायोजित',

      // ---- Voice search ----
      'voice_search_title': 'आवाज़ से खोजें',
      'voice_search_listening': 'सुन रहा है...',
      'voice_search_found_template': '{count} {noun} मिले',
      'voice_search_noun_videos': 'वीडियो',
      'voice_search_noun_photos': 'फ़ोटो',
      'voice_search_noun_songs': 'गाने',
      'voice_search_video_unavailable': 'यह वीडियो अब उपलब्ध नहीं है।',
      'voice_search_photo_unavailable': 'यह फ़ोटो अब उपलब्ध नहीं है।',
      'voice_search_song_unavailable': 'यह गाना अब उपलब्ध नहीं है।',
      'voice_search_hint_try': 'माइक पर टैप करें और ऐसा कमांड आज़माएं:',
      'voice_search_processing': 'प्रोसेस हो रहा है...',
      'voice_search_searching': 'खोजा जा रहा है...',
      'voice_search_no_results_template': '{noun} नहीं मिले',
      'voice_search_try_saying': 'यह बोलकर देखें:',
      'voice_search_mic_needed_title': 'माइक्रोफ़ोन एक्सेस आवश्यक है',
      'voice_search_mic_needed_subtitle':
          'आपका कमांड सुनने के लिए आवाज़ से खोज को माइक्रोफ़ोन एक्सेस चाहिए। '
          'आप इसे सेटिंग्स से दे सकते हैं।',
      'voice_search_open_settings': 'सेटिंग्स खोलें',
      'voice_search_something_wrong': 'कुछ गलत हो गया',
      'voice_search_please_try_again': 'कृपया फिर से प्रयास करें।',
      'voice_search_try_again': 'फिर से प्रयास करें',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
