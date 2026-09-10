/// Translation table for the shared equalizer (page, bottom sheet, profiles,
/// presets). Mirrors the pattern used by [VideoStrings] / [MusicStrings] but is
/// its own namespace so the whole feature's copy lives in one place.
///
/// Only `en` and `hi` are translated; any other locale falls back to English.
///
/// Preset names, reverb names and output-device names are here too rather than
/// in the domain layer — `EqPreset`, `ReverbPreset` and `OutputDevice` carry a
/// KEY, never a display string, so the model stays language-independent and a
/// saved profile never bakes in the language it was created under.
class EqStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // ── shell ──────────────────────────────────────────────────────────
      'eq_title': 'Equalizer',
      'eq_my_profiles': 'My profiles',
      'eq_open_full': 'Open full equalizer',

      // ── header ─────────────────────────────────────────────────────────
      'eq_media_video': 'Video',
      'eq_media_music': 'Music',
      'eq_video_audio': 'Video audio',
      'eq_on': 'On',
      'eq_off': 'Off',
      'eq_not_available': 'Not available on this device',

      // Engine line
      'eq_engine_system': 'System effects',
      'eq_engine_system_global': 'System effects (global session)',
      'eq_engine_player': 'Player filters',
      'eq_engine_player_limited': 'Player filters (limited)',
      'eq_engine_unavailable': 'Unavailable',

      // Banners
      'eq_banner_device':
          'The equalizer is not supported on this device. Its built-in sound '
              'settings may be holding the audio effects.',
      'eq_banner_waiting':
          'Waiting for playback — the equalizer attaches as soon as a track or '
              'video starts.',
      'eq_codec_note':
          'Dolby (AC3/E-AC3) track detected — level auto-compensated.',

      // ── AI suggestion ──────────────────────────────────────────────────
      'eq_ai_suggests': 'AI suggests:',
      'eq_ai_detected': 'detected',
      'eq_apply': 'Apply',

      // Content the classifier recognises
      'eq_content_speech': 'Speech / Dialogue',
      'eq_content_bass': 'Bass Heavy',
      'eq_content_bright': 'Bright',
      'eq_content_balanced': 'Balanced',
      'eq_content_genre_tag': 'Genre tag',

      // ── bands ──────────────────────────────────────────────────────────
      'eq_band_5': '5 band',
      'eq_band_10': '10 band',
      'eq_interpolated_prefix': 'Device has',
      'eq_interpolated_suffix': 'bands — curve interpolated',

      // ── actions ────────────────────────────────────────────────────────
      'eq_reset': 'Reset',
      'eq_save_profile': 'Save as profile',
      'eq_save_profile_title': 'Save as profile',
      'eq_profile_name_hint': 'e.g. Late Night, Gym, My Bass',
      'eq_saved': 'Saved',
      'eq_common_cancel': 'Cancel',
      'eq_common_save': 'Save',
      'eq_common_delete': 'Delete',
      'eq_common_done': 'Done',

      // ── sound effects ──────────────────────────────────────────────────
      'eq_section_effects': 'Sound effects',
      'eq_bass_boost': 'Bass Boost',
      'eq_surround': '3D Surround',
      'eq_surround_sub': 'Widens the stereo image',
      'eq_surround_warning':
          'Virtualization is designed for headphones. On the phone speaker the '
              'effect is barely audible.',
      'eq_volume_boost': 'Volume Boost',
      'eq_volume_warning':
          'Above +10 dB quiet recordings can distort, and sustained high volume '
              'damages hearing. Keep sessions short.',
      'eq_reverb': 'Reverb',

      // ── channels ───────────────────────────────────────────────────────
      'eq_section_channels': 'Channels',
      'eq_balance': 'Balance',
      'eq_balance_centre': 'Centre',
      'eq_mono': 'Mono audio',
      'eq_mono_sub': 'Both channels play the same signal',
      'eq_dialogue': 'Dialogue downmix',
      'eq_dialogue_sub': 'Folds surround to stereo, keeping speech forward',
      'eq_night': 'Night mode',
      'eq_night_sub': 'Loud scenes down, quiet dialogue up',

      // ── analysis ───────────────────────────────────────────────────────
      'eq_section_analysis': 'Analysis',
      'eq_spectrum': 'Live spectrum',
      'eq_spectrum_sub': 'Show the frequency bars behind the curve',
      'eq_spectrum_unavailable': 'Not available for this player',
      'eq_auto': 'Auto EQ',
      'eq_auto_sub': 'Detects speech vs. music and switches preset for you',
      'eq_permission_note':
          "Live spectrum and Auto EQ read this app's own audio output. Android "
              'gates that behind the microphone permission — nothing is recorded '
              'from the mic, and nothing leaves the device.',
      'eq_permission_denied':
          'Permission needed to read the audio output. Enable Microphone for '
              'Vidnexa in Settings.',

      // ── output devices ─────────────────────────────────────────────────
      'eq_out_speaker': 'Speaker',
      'eq_out_wired': 'Wired earphones',
      'eq_out_bluetooth': 'Bluetooth',
      'eq_out_usb': 'USB / Type-C DAC',

      // ── reverb presets ─────────────────────────────────────────────────
      'eq_reverb_none': 'None',
      'eq_reverb_small_room': 'Small Room',
      'eq_reverb_medium_room': 'Medium Room',
      'eq_reverb_large_room': 'Large Room',
      'eq_reverb_medium_hall': 'Hall',
      'eq_reverb_large_hall': 'Large Hall',
      'eq_reverb_plate': 'Plate',

      // ── presets ────────────────────────────────────────────────────────
      'eq_preset_normal': 'Normal',
      'eq_preset_pop': 'Pop',
      'eq_preset_rock': 'Rock',
      'eq_preset_jazz': 'Jazz',
      'eq_preset_classical': 'Classical',
      'eq_preset_dance': 'Dance',
      'eq_preset_hip_hop': 'Hip-Hop',
      'eq_preset_metal': 'Metal',
      'eq_preset_bass_booster': 'Bass Booster',
      'eq_preset_treble_booster': 'Treble Booster',
      'eq_preset_vocal_boost': 'Vocal Boost',
      'eq_preset_movie': 'Movie',
      'eq_preset_movie_sub': 'Wide, cinematic',
      'eq_preset_dialogue': 'Dialogue Clarity',
      'eq_preset_dialogue_sub': 'Speech forward',
      'eq_preset_podcast': 'Podcast',
      'eq_preset_podcast_sub': 'Even, spoken word',
      'eq_preset_night': 'Night Mode',
      'eq_preset_night_sub': 'Even volume, late hours',
      'eq_preset_headphone': 'Headphone',
      'eq_preset_custom': 'Custom',

      // ── profiles sheet ─────────────────────────────────────────────────
      'eq_profiles_import': 'Import from clipboard',
      'eq_profiles_empty_title': 'No saved profiles yet',
      'eq_profiles_empty_sub':
          'Set up a curve you like, then use "Save as profile" to keep it and '
              'auto-apply it per output device.',
      'eq_profiles_clipboard_empty': 'Clipboard is empty',
      'eq_profiles_import_failed':
          'That does not look like a Vidnexa EQ profile',
      'eq_profiles_imported': 'Imported',
      'eq_profiles_updated': 'Updated',
      'eq_profiles_saved': 'Saved',
      'eq_menu_apply': 'Apply',
      'eq_menu_overwrite': 'Save current here',
      'eq_menu_rename': 'Rename',
      'eq_menu_duplicate': 'Duplicate',
      'eq_menu_set_default': 'Set as default',
      'eq_menu_clear_default': 'Clear default',
      'eq_menu_auto_apply': 'Auto-apply on…',
      'eq_menu_share': 'Share',
      'eq_menu_delete': 'Delete',
      'eq_rename_title': 'Rename profile',
      'eq_rename_hint': 'Profile name',
      'eq_delete_body':
          'The profile and any output-device rules pointing at it are removed.',
      'eq_default': 'Default',
      'eq_flat': 'Flat',
      'eq_peak': 'Peak',
      'eq_bass_short': 'Bass',
      'eq_device_used_by_other': 'Used by another profile',
      'eq_share_subject': 'Vidnexa EQ profile',

      // ── settings entry ─────────────────────────────────────────────────
      'eq_entry_sub': 'Presets, profiles, bass boost & dialogue clarity',
    },
    'hi': {
      // ── shell ──────────────────────────────────────────────────────────
      'eq_title': 'इक्वलाइज़र',
      'eq_my_profiles': 'मेरी प्रोफ़ाइल',
      'eq_open_full': 'पूरा इक्वलाइज़र खोलें',

      // ── header ─────────────────────────────────────────────────────────
      'eq_media_video': 'वीडियो',
      'eq_media_music': 'संगीत',
      'eq_video_audio': 'वीडियो ऑडियो',
      'eq_on': 'चालू',
      'eq_off': 'बंद',
      'eq_not_available': 'इस डिवाइस पर उपलब्ध नहीं',

      'eq_engine_system': 'सिस्टम इफ़ेक्ट',
      'eq_engine_system_global': 'सिस्टम इफ़ेक्ट (ग्लोबल सेशन)',
      'eq_engine_player': 'प्लेयर फ़िल्टर',
      'eq_engine_player_limited': 'प्लेयर फ़िल्टर (सीमित)',
      'eq_engine_unavailable': 'अनुपलब्ध',

      'eq_banner_device':
          'इस डिवाइस पर इक्वलाइज़र समर्थित नहीं है। हो सकता है डिवाइस की अपनी '
              'साउंड सेटिंग्स ऑडियो इफ़ेक्ट रोके हुए हों।',
      'eq_banner_waiting':
          'प्लेबैक का इंतज़ार — कोई ट्रैक या वीडियो शुरू होते ही इक्वलाइज़र जुड़ '
              'जाएगा।',
      'eq_codec_note':
          'डॉल्बी (AC3/E-AC3) ट्रैक मिला — आवाज़ अपने आप संतुलित की गई।',

      // ── AI suggestion ──────────────────────────────────────────────────
      'eq_ai_suggests': 'AI सुझाव:',
      'eq_ai_detected': 'पहचाना गया',
      'eq_apply': 'लागू करें',

      'eq_content_speech': 'बातचीत / संवाद',
      'eq_content_bass': 'बेस-प्रधान',
      'eq_content_bright': 'तीखा',
      'eq_content_balanced': 'संतुलित',
      'eq_content_genre_tag': 'शैली टैग',

      // ── bands ──────────────────────────────────────────────────────────
      'eq_band_5': '5 बैंड',
      'eq_band_10': '10 बैंड',
      'eq_interpolated_prefix': 'डिवाइस में',
      'eq_interpolated_suffix': 'बैंड हैं — कर्व अनुमानित है',

      // ── actions ────────────────────────────────────────────────────────
      'eq_reset': 'रीसेट करें',
      'eq_save_profile': 'प्रोफ़ाइल सेव करें',
      'eq_save_profile_title': 'प्रोफ़ाइल के रूप में सेव करें',
      'eq_profile_name_hint': 'जैसे Late Night, Gym, मेरा बेस',
      'eq_saved': 'सेव किया',
      'eq_common_cancel': 'रद्द करें',
      'eq_common_save': 'सेव करें',
      'eq_common_delete': 'हटाएं',
      'eq_common_done': 'हो गया',

      // ── sound effects ──────────────────────────────────────────────────
      'eq_section_effects': 'साउंड इफ़ेक्ट',
      'eq_bass_boost': 'बेस बूस्ट',
      'eq_surround': '3D सराउंड',
      'eq_surround_sub': 'स्टीरियो को चौड़ा करता है',
      'eq_surround_warning':
          'वर्चुअलाइज़ेशन हेडफ़ोन के लिए बना है। फ़ोन के स्पीकर पर इसका असर बहुत '
              'कम सुनाई देगा।',
      'eq_volume_boost': 'वॉल्यूम बूस्ट',
      'eq_volume_warning':
          '+10 dB से ऊपर धीमी रिकॉर्डिंग खराब सुनाई दे सकती है, और लगातार तेज़ '
              'आवाज़ सुनने की क्षमता को नुकसान पहुँचाती है। ज़्यादा देर न सुनें।',
      'eq_reverb': 'रिवर्ब',

      // ── channels ───────────────────────────────────────────────────────
      'eq_section_channels': 'चैनल',
      'eq_balance': 'बैलेंस',
      'eq_balance_centre': 'बीच में',
      'eq_mono': 'मोनो ऑडियो',
      'eq_mono_sub': 'दोनों चैनलों में एक ही आवाज़',
      'eq_dialogue': 'डायलॉग डाउनमिक्स',
      'eq_dialogue_sub': 'सराउंड को स्टीरियो में बदलकर आवाज़ आगे रखता है',
      'eq_night': 'नाइट मोड',
      'eq_night_sub': 'तेज़ आवाज़ कम, धीमी बातचीत तेज़',

      // ── analysis ───────────────────────────────────────────────────────
      'eq_section_analysis': 'विश्लेषण',
      'eq_spectrum': 'लाइव स्पेक्ट्रम',
      'eq_spectrum_sub': 'कर्व के पीछे फ़्रीक्वेंसी बार दिखाएं',
      'eq_spectrum_unavailable': 'इस प्लेयर के लिए उपलब्ध नहीं',
      'eq_auto': 'ऑटो EQ',
      'eq_auto_sub': 'बातचीत और संगीत पहचानकर खुद प्रीसेट बदलता है',
      'eq_permission_note':
          'लाइव स्पेक्ट्रम और ऑटो EQ सिर्फ़ इसी ऐप की अपनी आवाज़ पढ़ते हैं। '
              'एंड्रॉइड इसके लिए माइक्रोफ़ोन अनुमति माँगता है — माइक से कुछ '
              'रिकॉर्ड नहीं होता और कोई डेटा डिवाइस से बाहर नहीं जाता।',
      'eq_permission_denied':
          'ऑडियो आउटपुट पढ़ने के लिए अनुमति चाहिए। सेटिंग्स में Vidnexa के लिए '
              'माइक्रोफ़ोन चालू करें।',

      // ── output devices ─────────────────────────────────────────────────
      'eq_out_speaker': 'स्पीकर',
      'eq_out_wired': 'वायर्ड ईयरफ़ोन',
      'eq_out_bluetooth': 'ब्लूटूथ',
      'eq_out_usb': 'USB / Type-C DAC',

      // ── reverb presets ─────────────────────────────────────────────────
      'eq_reverb_none': 'कोई नहीं',
      'eq_reverb_small_room': 'छोटा कमरा',
      'eq_reverb_medium_room': 'मध्यम कमरा',
      'eq_reverb_large_room': 'बड़ा कमरा',
      'eq_reverb_medium_hall': 'हॉल',
      'eq_reverb_large_hall': 'बड़ा हॉल',
      'eq_reverb_plate': 'प्लेट',

      // ── presets ────────────────────────────────────────────────────────
      'eq_preset_normal': 'सामान्य',
      'eq_preset_pop': 'पॉप',
      'eq_preset_rock': 'रॉक',
      'eq_preset_jazz': 'जैज़',
      'eq_preset_classical': 'शास्त्रीय',
      'eq_preset_dance': 'डांस',
      'eq_preset_hip_hop': 'हिप-हॉप',
      'eq_preset_metal': 'मेटल',
      'eq_preset_bass_booster': 'बेस बूस्टर',
      'eq_preset_treble_booster': 'ट्रेबल बूस्टर',
      'eq_preset_vocal_boost': 'वोकल बूस्ट',
      'eq_preset_movie': 'मूवी',
      'eq_preset_movie_sub': 'चौड़ा, सिनेमा जैसा',
      'eq_preset_dialogue': 'डायलॉग क्लैरिटी',
      'eq_preset_dialogue_sub': 'आवाज़ आगे',
      'eq_preset_podcast': 'पॉडकास्ट',
      'eq_preset_podcast_sub': 'एक-सा, बोले गए शब्द',
      'eq_preset_night': 'नाइट मोड',
      'eq_preset_night_sub': 'रात के लिए एक-सी आवाज़',
      'eq_preset_headphone': 'हेडफ़ोन',
      'eq_preset_custom': 'कस्टम',

      // ── profiles sheet ─────────────────────────────────────────────────
      'eq_profiles_import': 'क्लिपबोर्ड से इम्पोर्ट करें',
      'eq_profiles_empty_title': 'अभी कोई प्रोफ़ाइल सेव नहीं है',
      'eq_profiles_empty_sub':
          'अपनी पसंद का कर्व बनाइए, फिर "प्रोफ़ाइल सेव करें" से उसे रखिए और हर '
              'आउटपुट डिवाइस पर अपने आप लगने दीजिए।',
      'eq_profiles_clipboard_empty': 'क्लिपबोर्ड खाली है',
      'eq_profiles_import_failed': 'यह Vidnexa EQ प्रोफ़ाइल नहीं लगती',
      'eq_profiles_imported': 'इम्पोर्ट किया',
      'eq_profiles_updated': 'अपडेट किया',
      'eq_profiles_saved': 'सेव किया',
      'eq_menu_apply': 'लागू करें',
      'eq_menu_overwrite': 'मौजूदा सेटिंग यहाँ सेव करें',
      'eq_menu_rename': 'नाम बदलें',
      'eq_menu_duplicate': 'कॉपी बनाएं',
      'eq_menu_set_default': 'डिफ़ॉल्ट बनाएं',
      'eq_menu_clear_default': 'डिफ़ॉल्ट हटाएं',
      'eq_menu_auto_apply': 'इस पर अपने आप लगाएं…',
      'eq_menu_share': 'साझा करें',
      'eq_menu_delete': 'हटाएं',
      'eq_rename_title': 'प्रोफ़ाइल का नाम बदलें',
      'eq_rename_hint': 'प्रोफ़ाइल का नाम',
      'eq_delete_body':
          'प्रोफ़ाइल और उससे जुड़े आउटपुट-डिवाइस नियम हटा दिए जाएंगे।',
      'eq_default': 'डिफ़ॉल्ट',
      'eq_flat': 'सपाट',
      'eq_peak': 'पीक',
      'eq_bass_short': 'बेस',
      'eq_device_used_by_other': 'किसी और प्रोफ़ाइल में इस्तेमाल हो रहा है',
      'eq_share_subject': 'Vidnexa EQ प्रोफ़ाइल',

      // ── settings entry ─────────────────────────────────────────────────
      'eq_entry_sub': 'प्रीसेट, प्रोफ़ाइल, बेस बूस्ट और डायलॉग क्लैरिटी',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
