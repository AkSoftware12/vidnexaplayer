import 'translations/vi.dart';
import 'translations/tr.dart';
import 'translations/ru.dart';
import 'translations/bn.dart';
import 'translations/ar.dart';
import 'translations/id.dart';
import 'translations/pt.dart';
import 'translations/es.dart';
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
      'notification_new': 'NEW',
      'notification_clear_all': 'Clear all',
      'notification_just_now': 'Just now',
      'notification_minutes_ago': '{n}m ago',
      'notification_hours_ago': '{n}h ago',

      // ---- Toolbar color picker ----
      'colorpicker_title': 'Select ToolBar Color',
      'reset': 'Reset',

      // ---- Internet status banner ----
      'internet_banner_offline': 'No internet connection',

      // ---- Rating popup ----
      'rating_playstore_open_failed': 'Could not open the Play Store',

      // ---- Ads ----
      'ads_sponsored': 'Sponsored',
      'rewarded_watch': 'Watch ad',
      'rewarded_not_now': 'Not now',
      'rewarded_unlocked': 'Unlocked for the next {minutes} minutes',
      'rewarded_incomplete': 'The ad was not finished, so nothing was unlocked.',
      'rewarded_unavailable': 'No ad available right now. Please try again in a moment.',
      'rewarded_enhance_title': 'Unlock Enhance to 4K',
      'rewarded_enhance_body':
          'Watch a short video ad and 4K enhance is unlocked for the next '
          '{minutes} minutes — enhance as many photos as you like in that '
          'time. You can close this and keep using everything else.',
      'rewarded_hdr_title': 'Unlock HDR for your videos',
      'rewarded_hdr_body': 'Richer colours, brighter dark scenes and punchier contrast — see the difference above. It enhances the picture on this screen; it does not turn the file into true HDR. Watch one short video ad to use HDR for {minutes} minutes. You can turn it off any time.',
      'rewarded_filters_title': 'Unlock saving filtered photos',
      'rewarded_filters_body':
          'Watch a short video ad and saving filtered photos is unlocked for '
          'the next {minutes} minutes — save as many as you like in that '
          'time. Trying filters stays free, and you can close this and keep '
          'using everything else.',

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
      'voice_search_mic_disclosure_title': 'Use the microphone?',
      'voice_search_mic_disclosure_body':
          'Voice search listens only while the mic button is on. Your '
          "phone's speech service (usually Google) turns what you say into "
          'text, and may send the audio to Google to do that. Vidnexa does not '
          'record or store your voice.',
      'voice_search_mic_disclosure_yes': 'Continue',
      'voice_search_mic_disclosure_no': 'Not now',
      'voice_search_something_wrong': 'Something went wrong',
      'voice_search_please_try_again': 'Please try again.',
      'voice_search_try_again': 'Try Again',
    },
    'es': esMisc,
    'pt': ptMisc,
    'id': idMisc,
    'ar': arMisc,
    'bn': bnMisc,
    'ru': ruMisc,
    'tr': trMisc,
    'vi': viMisc,
    'hi': {
      // ---- Notification screen ----
      'notification_title': 'सूचनाएं',
      'notification_empty_title': 'अभी कोई सूचना नहीं',
      'notification_empty_subtitle':
          'आप पूरी तरह अपडेट हैं! कुछ नया होने पर हम आपको सूचित करेंगे',
      'go_back': 'वापस जाएं',
      'notification_new': 'नया',
      'notification_clear_all': 'सभी हटाएँ',
      'notification_just_now': 'अभी',
      'notification_minutes_ago': '{n} मिनट पहले',
      'notification_hours_ago': '{n} घंटे पहले',

      // ---- Toolbar color picker ----
      'colorpicker_title': 'टूलबार का रंग चुनें',
      'reset': 'रीसेट करें',

      // ---- Internet status banner ----
      'internet_banner_offline': 'इंटरनेट कनेक्शन नहीं है',

      // ---- Rating popup ----
      'rating_playstore_open_failed': 'Play Store नहीं खोला जा सका',

      // ---- Ads ----
      'ads_sponsored': 'प्रायोजित',
      'rewarded_watch': 'विज्ञापन देखें',
      'rewarded_not_now': 'अभी नहीं',
      'rewarded_unlocked': 'अगले {minutes} मिनट के लिए अनलॉक हो गया',
      'rewarded_incomplete': 'विज्ञापन पूरा नहीं हुआ, इसलिए कुछ अनलॉक नहीं हुआ।',
      'rewarded_unavailable': 'अभी कोई विज्ञापन उपलब्ध नहीं है। थोड़ी देर बाद फिर कोशिश करें।',
      'rewarded_enhance_title': '4K एन्हांस अनलॉक करें',
      'rewarded_enhance_body':
          'एक छोटा वीडियो विज्ञापन देखें और अगले {minutes} मिनट के लिए 4K '
          'एन्हांस अनलॉक हो जाएगा — उतनी देर में जितनी चाहें उतनी फ़ोटो '
          'एन्हांस करें। इसे बंद करके बाकी सब कुछ वैसे ही इस्तेमाल कर सकते हैं।',
      'rewarded_hdr_title': 'अपने वीडियो के लिए HDR अनलॉक करें',
      'rewarded_hdr_body': 'ज़्यादा गहरे रंग, अंधेरे सीन में ज़्यादा रोशनी और बेहतर कंट्रास्ट — ऊपर फ़र्क देखें। यह स्क्रीन पर तस्वीर को बेहतर बनाता है; फ़ाइल को असली HDR में नहीं बदलता। एक छोटा वीडियो विज्ञापन देखें और {minutes} मिनट तक HDR इस्तेमाल करें। इसे कभी भी बंद कर सकते हैं।',
      'rewarded_filters_title': 'फ़िल्टर वाली फ़ोटो सेव करना अनलॉक करें',
      'rewarded_filters_body':
          'एक छोटा वीडियो विज्ञापन देखें और अगले {minutes} मिनट के लिए '
          'फ़िल्टर वाली फ़ोटो सेव करना अनलॉक हो जाएगा — उतनी देर में जितनी '
          'चाहें उतनी सेव करें। फ़िल्टर आज़माना हमेशा फ़्री है, और इसे बंद '
          'करके बाकी सब कुछ वैसे ही इस्तेमाल कर सकते हैं।',

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
      'voice_search_mic_disclosure_title': 'माइक्रोफ़ोन इस्तेमाल करें?',
      'voice_search_mic_disclosure_body':
          'वॉइस सर्च सिर्फ़ तब सुनता है जब माइक बटन चालू हो। आपके फ़ोन की स्पीच '
          'सर्विस (आमतौर पर Google) आपकी बात को टेक्स्ट में बदलती है, और इसके लिए '
          'आवाज़ Google को भेज सकती है। Vidnexa आपकी आवाज़ रिकॉर्ड या सेव नहीं करता।',
      'voice_search_mic_disclosure_yes': 'जारी रखें',
      'voice_search_mic_disclosure_no': 'अभी नहीं',
      'voice_search_something_wrong': 'कुछ गलत हो गया',
      'voice_search_please_try_again': 'कृपया फिर से प्रयास करें।',
      'voice_search_try_again': 'फिर से प्रयास करें',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
