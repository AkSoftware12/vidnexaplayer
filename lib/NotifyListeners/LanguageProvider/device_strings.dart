/// In-code translation table for the device/file storage, photo album and
/// WhatsApp status-saver screens. Follows the exact same shape and fallback
/// behavior as `AppStrings` (see app_strings.dart) but is kept in its own
/// namespace/file so it can be worked on independently.
///
/// Only `en` and `hi` are actually translated; any other locale code falls
/// back to English until real translations are added for it.
///
/// A handful of values are tiny templates containing `{placeholder}` tokens
/// (e.g. `{free}`, `{count}`, `{date}`, `{type}`) — callers substitute those
/// with `String.replaceAll` after fetching the translated template. This
/// keeps grammar order natural per-language (Hindi often reorders a phrase
/// relative to English) without needing a heavier templating engine.
class DeviceStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // ── Device / storage screen ──
      'device_appbar_title': 'Directory',
      'device_internal_storage': 'Internal Storage',
      'device_storage_free_of': 'Free {free} GB of {total} GB',

      // ── Photo album screens ──
      'album_permission_denied': 'Permission denied to access photos',
      'album_title': 'Photo Albums',
      'album_no_albums': 'No albums found',
      'album_photos_count': '{count} photos',
      'album_no_photos_in_album': 'No photos in this album',
      'album_delete_title': 'Delete Photo',
      'album_delete_confirm': 'Are you sure you want to delete this photo?',
      'album_cancel': 'Cancel',
      'album_delete': 'Delete',
      'album_delete_success': 'Photo deleted successfully',
      'album_delete_failed': 'Failed to delete photo',
      'album_delete_error_prefix': 'Error deleting photo: ',
      'album_no_photos_available': 'No photos available',
      'album_file_unavailable': 'This file is no longer available',

      // ── WhatsApp status saver ──
      'wa_title': 'Status Saver',
      'wa_subtitle': 'Allow access to view and save statuses.',
      'wa_tab_all': 'All',
      'wa_tab_images': 'Images',
      'wa_tab_videos': 'Videos',
      'wa_tab_downloads': 'Downloads',
      'wa_permission_title': 'Allow access to load statuses',
      'wa_permission_message':
      'On first launch, allow media access. If your device still hides the status folder, use Pick Folder.',
      'wa_allow_access': 'Allow Access',
      'wa_pick_folder': 'Pick Folder',
      'wa_waiting_title': 'No statuses found yet',
      'wa_waiting_message':
      'Open WhatsApp, watch any status, then return here and tap Refresh. New statuses will appear automatically after refresh.',
      'wa_refresh': 'Refresh',
      'wa_change_folder': 'Change Folder',
      'wa_empty_filter_title': 'Nothing in this filter',
      'wa_empty_filter_message':
      'Try another tab or refresh after viewing more statuses in WhatsApp.',
      'wa_no_downloads_title': 'No downloads yet',
      'wa_no_downloads_message':
      'Saved statuses will appear here with a green check mark.',
      'wa_view_statuses': 'View statuses',
      'wa_status_access_required': 'Access required',
      'wa_status_waiting_for_statuses': 'Waiting for statuses',
      'wa_status_available': 'Statuses available',
      'wa_mode_direct': 'Direct permission mode',
      'wa_mode_folder': 'Folder access mode',
      'wa_mode_none': 'No access selected',
      'wa_saved_count': '{count} saved',
      'wa_connected_folder_prefix': 'Connected folder: ',
      'wa_opening': 'Opening...',
      'wa_reset_folder': 'Reset folder',
      'wa_hint_access_allowed_watch':
      'Access is allowed. Open WhatsApp, watch at least one status, then return here and tap Refresh.',
      'wa_hint_allow_access_first':
      'Allow access first. If hidden statuses are blocked on your device, use folder selection.',
      'wa_error_permission_not_granted': 'Media permission was not granted.',
      'wa_hint_allow_or_select_folder':
      'Allow access or select the WhatsApp media folder manually.',
      'wa_hint_access_available_no_statuses':
      'Access is available, but no visible statuses were found yet. Open WhatsApp and watch a status first.',
      'wa_hint_statuses_loaded':
      'Statuses loaded. Refresh after viewing new statuses in WhatsApp.',
      'wa_error_folder_selection_failed_prefix': 'Folder selection failed: ',
      'wa_error_statuses_folder_not_found':
      'The .Statuses folder was not found. Select WhatsApp/Media or Android/media/.../Media.',
      'wa_hint_folder_connected_watch':
      'Folder connected. Open WhatsApp, view a status, then come back and refresh.',
      'wa_hint_folder_connected_reliable':
      'Folder connected. This mode is reliable on Android 11 and above.',
      'wa_error_unable_load_statuses_prefix': 'Unable to load statuses: ',
      'wa_hint_still_no_statuses':
      'Still no statuses found. Open WhatsApp, view a status, then return and refresh again.',
      'wa_hint_access_granted_watch':
      'Access granted. Open WhatsApp, watch any status, then come back and tap Refresh.',
      'wa_hint_folder_reset': 'Folder reset. Pick the folder again if needed.',
      'wa_saved_to_gallery': '{type} saved to gallery.',
      'wa_save_failed_prefix': 'Save failed: ',
      'wa_share_failed_prefix': 'Share failed: ',
      'wa_video_not_found': 'Video file not found',
      'wa_unable_open_video_prefix': 'Unable to open video: ',
      'wa_type_video': 'Video',
      'wa_type_image': 'Image',
      'wa_saved': 'Saved',
      'wa_unknown_date': 'Unknown date',
      'wa_share': 'Share',
      'wa_save': 'Save',
      'wa_saved_on': 'Saved on {date}',
      'wa_downloaded': 'Downloaded',
      'wa_preview_unavailable': 'Preview unavailable',
      'wa_share_status_title': 'Share status',
      'wa_file_unavailable': 'File unavailable',
      'wa_preview_file_unavailable': 'Preview file unavailable',

      // ── WhatsApp status-saver instructions guide ──
      'guide_appbar_title': 'Instructions',
      'guide_header_title': 'How to Save WhatsApp Status?',
      'guide_header_subtitle':
          "Follow the steps below to save your friends' statuses easily.",
      'guide_title': 'Step-by-Step Guide',
      'guide_quick_access': 'Quick Access',
      'guide_open_whatsapp': 'Open WhatsApp',
      'guide_tip': 'Tip: After viewing a status, come back here and save it.',
      'guide_whatsapp_not_installed': 'WhatsApp is not installed!',
      'guide_step1_title': 'Open WhatsApp',
      'guide_step1_subtitle': 'Use the button below or open WhatsApp manually.',
      'guide_step2_title': 'Go to Status Tab',
      'guide_step2_subtitle': 'Tap the "Status" tab at the bottom of WhatsApp.',
      'guide_step3_title': 'View the Status',
      'guide_step3_subtitle': 'Watch the status you want to save completely.',
      'guide_step4_title': 'Come Back Here',
      'guide_step4_subtitle': 'After viewing, return to this app.',
      'guide_step5_title': 'Select & Save',
      'guide_step5_subtitle': 'Choose the status from the list and tap Save.',
    },
    'hi': {
      // ── Device / storage screen ──
      'device_appbar_title': 'डायरेक्टरी',
      'device_internal_storage': 'इंटरनल स्टोरेज',
      'device_storage_free_of': 'कुल {total} GB में से {free} GB खाली',

      // ── Photo album screens ──
      'album_permission_denied': 'फ़ोटो एक्सेस करने की अनुमति नहीं मिली',
      'album_title': 'फ़ोटो एल्बम',
      'album_no_albums': 'कोई एल्बम नहीं मिला',
      'album_photos_count': '{count} फ़ोटो',
      'album_no_photos_in_album': 'इस एल्बम में कोई फ़ोटो नहीं है',
      'album_delete_title': 'फ़ोटो हटाएं',
      'album_delete_confirm': 'क्या आप वाकई इस फ़ोटो को हटाना चाहते हैं?',
      'album_cancel': 'रद्द करें',
      'album_delete': 'हटाएं',
      'album_delete_success': 'फ़ोटो सफलतापूर्वक हटा दी गई',
      'album_delete_failed': 'फ़ोटो हटाने में विफल',
      'album_delete_error_prefix': 'फ़ोटो हटाने में त्रुटि: ',
      'album_no_photos_available': 'कोई फ़ोटो उपलब्ध नहीं है',
      'album_file_unavailable': 'यह फ़ाइल अब उपलब्ध नहीं है',

      // ── WhatsApp status saver ──
      'wa_title': 'स्टेटस सेवर',
      'wa_subtitle': 'स्टेटस देखने और सेव करने के लिए एक्सेस दें।',
      'wa_tab_all': 'सभी',
      'wa_tab_images': 'इमेज',
      'wa_tab_videos': 'वीडियो',
      'wa_tab_downloads': 'डाउनलोड',
      'wa_permission_title': 'स्टेटस लोड करने के लिए एक्सेस दें',
      'wa_permission_message':
      'पहली बार खोलने पर मीडिया एक्सेस की अनुमति दें। अगर आपका डिवाइस अभी भी स्टेटस फ़ोल्डर छुपाता है, तो "फ़ोल्डर चुनें" विकल्प का उपयोग करें।',
      'wa_allow_access': 'एक्सेस दें',
      'wa_pick_folder': 'फ़ोल्डर चुनें',
      'wa_waiting_title': 'अभी तक कोई स्टेटस नहीं मिला',
      'wa_waiting_message':
      'WhatsApp खोलें, कोई भी स्टेटस देखें, फिर यहां वापस आकर रिफ्रेश पर टैप करें। रिफ्रेश करने के बाद नए स्टेटस अपने आप दिखाई देंगे।',
      'wa_refresh': 'रिफ्रेश करें',
      'wa_change_folder': 'फ़ोल्डर बदलें',
      'wa_empty_filter_title': 'इस फ़िल्टर में कुछ नहीं है',
      'wa_empty_filter_message':
      'किसी अन्य टैब को आज़माएं या WhatsApp में और स्टेटस देखने के बाद रिफ्रेश करें।',
      'wa_no_downloads_title': 'अभी तक कोई डाउनलोड नहीं',
      'wa_no_downloads_message':
      'सेव किए गए स्टेटस यहां हरे चेक मार्क के साथ दिखाई देंगे।',
      'wa_view_statuses': 'स्टेटस देखें',
      'wa_status_access_required': 'एक्सेस आवश्यक है',
      'wa_status_waiting_for_statuses': 'स्टेटस का इंतज़ार है',
      'wa_status_available': 'स्टेटस उपलब्ध हैं',
      'wa_mode_direct': 'डायरेक्ट परमिशन मोड',
      'wa_mode_folder': 'फ़ोल्डर एक्सेस मोड',
      'wa_mode_none': 'कोई एक्सेस चयनित नहीं',
      'wa_saved_count': '{count} सेव किए गए',
      'wa_connected_folder_prefix': 'जुड़ा हुआ फ़ोल्डर: ',
      'wa_opening': 'खोला जा रहा है...',
      'wa_reset_folder': 'फ़ोल्डर रीसेट करें',
      'wa_hint_access_allowed_watch':
      'एक्सेस की अनुमति है। WhatsApp खोलें, कम से कम एक स्टेटस देखें, फिर यहां वापस आकर रिफ्रेश पर टैप करें।',
      'wa_hint_allow_access_first':
      'पहले एक्सेस की अनुमति दें। अगर आपके डिवाइस पर छिपे हुए स्टेटस ब्लॉक हैं, तो फ़ोल्डर चयन का उपयोग करें।',
      'wa_error_permission_not_granted': 'मीडिया अनुमति नहीं मिली।',
      'wa_hint_allow_or_select_folder':
      'एक्सेस दें या WhatsApp मीडिया फ़ोल्डर को मैन्युअल रूप से चुनें।',
      'wa_hint_access_available_no_statuses':
      'एक्सेस उपलब्ध है, लेकिन अभी तक कोई स्टेटस नहीं मिला। पहले WhatsApp खोलें और एक स्टेटस देखें।',
      'wa_hint_statuses_loaded':
      'स्टेटस लोड हो गए। WhatsApp में नए स्टेटस देखने के बाद रिफ्रेश करें।',
      'wa_error_folder_selection_failed_prefix': 'फ़ोल्डर चयन विफल: ',
      'wa_error_statuses_folder_not_found':
      '.Statuses फ़ोल्डर नहीं मिला। WhatsApp/Media या Android/media/.../Media चुनें।',
      'wa_hint_folder_connected_watch':
      'फ़ोल्डर जुड़ गया। WhatsApp खोलें, एक स्टेटस देखें, फिर वापस आकर रिफ्रेश करें।',
      'wa_hint_folder_connected_reliable':
      'फ़ोल्डर जुड़ गया। यह मोड Android 11 और उससे ऊपर पर भरोसेमंद है।',
      'wa_error_unable_load_statuses_prefix': 'स्टेटस लोड करने में असमर्थ: ',
      'wa_hint_still_no_statuses':
      'अभी भी कोई स्टेटस नहीं मिला। WhatsApp खोलें, एक स्टेटस देखें, फिर वापस आकर दोबारा रिफ्रेश करें।',
      'wa_hint_access_granted_watch':
      'एक्सेस मिल गई। WhatsApp खोलें, कोई भी स्टेटस देखें, फिर वापस आकर रिफ्रेश पर टैप करें।',
      'wa_hint_folder_reset': 'फ़ोल्डर रीसेट हो गया। ज़रूरत पड़ने पर फिर से फ़ोल्डर चुनें।',
      'wa_saved_to_gallery': '{type} गैलरी में सेव हो गया।',
      'wa_save_failed_prefix': 'सेव करने में विफल: ',
      'wa_share_failed_prefix': 'शेयर करने में विफल: ',
      'wa_video_not_found': 'वीडियो फ़ाइल नहीं मिली',
      'wa_unable_open_video_prefix': 'वीडियो खोलने में असमर्थ: ',
      'wa_type_video': 'वीडियो',
      'wa_type_image': 'इमेज',
      'wa_saved': 'सेव किया गया',
      'wa_unknown_date': 'अज्ञात तारीख',
      'wa_share': 'शेयर करें',
      'wa_save': 'सेव करें',
      'wa_saved_on': '{date} को सेव किया गया',
      'wa_downloaded': 'डाउनलोड हो गया',
      'wa_preview_unavailable': 'पूर्वावलोकन उपलब्ध नहीं है',
      'wa_share_status_title': 'स्टेटस शेयर करें',
      'wa_file_unavailable': 'फ़ाइल उपलब्ध नहीं है',
      'wa_preview_file_unavailable': 'पूर्वावलोकन फ़ाइल उपलब्ध नहीं है',

      // ── WhatsApp status-saver instructions guide ──
      'guide_appbar_title': 'निर्देश',
      'guide_header_title': 'WhatsApp Status कैसे Save करें?',
      'guide_header_subtitle':
          'नीचे दिए गए स्टेप्स फॉलो करें और आसानी से Status Save करें।',
      'guide_title': 'स्टेप-बाय-स्टेप गाइड',
      'guide_quick_access': 'जल्दी खोलें',
      'guide_open_whatsapp': 'WhatsApp खोलें',
      'guide_tip': 'टिप: Status देखने के बाद यहाँ वापस आएं और Save करें।',
      'guide_whatsapp_not_installed': 'WhatsApp इंस्टॉल नहीं है!',
      'guide_step1_title': 'WhatsApp खोलें',
      'guide_step1_subtitle': 'नीचे दिए बटन से या खुद WhatsApp खोलें।',
      'guide_step2_title': 'Status Tab पर जाएं',
      'guide_step2_subtitle': 'WhatsApp में नीचे "Status" टैब पर टैप करें।',
      'guide_step3_title': 'Status देखें',
      'guide_step3_subtitle': 'जो Status Save करना है, उसे पूरा देख लें।',
      'guide_step4_title': 'वापस आएं',
      'guide_step4_subtitle': 'Status देखने के बाद इस App में वापस आएं।',
      'guide_step5_title': 'Select करें & Save करें',
      'guide_step5_subtitle': 'लिस्ट से Status चुनें और Save बटन दबाएं।',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
