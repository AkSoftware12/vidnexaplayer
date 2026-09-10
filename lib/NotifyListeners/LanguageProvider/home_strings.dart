/// Tiny in-code translation table for the Home tab and the screens it opens
/// directly (folder bottom sheet, folder info dialog, media categories strip,
/// coming-soon placeholder, the file-manager "Directory" screen and the
/// Recently Played section). Only `en` and `hi` are actually translated; any
/// other locale code falls back to English until real translations are added
/// for it.
///
/// Kept as its own namespace (separate from [AppStrings]) so screens can be
/// worked on in parallel without both agents editing the same map.
class HomeStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // home2.dart
      'home_permission_required_title': 'Permissions Required',
      'home_permission_required_desc':
          'Please grant access to photos and videos to view your media content.',
      'home_allow_permissions': 'Allow Permissions',
      'home_folders': 'Folders',
      'home_no_albums_found': 'No albums found',
      'home_sd_card': 'SD Card',
      'home_videos_suffix': 'Videos',
      'home_videos_suffix_lower': 'videos',
      'home_untitled_album': 'Untitled Album',

      // BottomsheetHomeScreen/bottomsheet_menu_button.dart
      'home_menu_open': 'Open',
      'home_menu_delete': 'Delete',
      'home_menu_info': 'Info',
      'home_menu_copy': 'Copy',
      'home_menu_hide': 'Hide',

      // DialogHomeScreen/FolderInfoDialog/folder_info_dialog.dart
      'folder_info_title': 'Folder Info',
      'folder_info_name_label': 'Folder Name',
      'folder_info_size_label': 'Size',
      'folder_info_location_label': 'Location',
      'folder_info_modified_label': 'Modified Date',
      'folder_info_ok': 'OK',

      // HorizontalGridList/horizontal_gridlist.dart
      'home_media_categories_title': 'Media Categories',
      'home_media_categories_subtitle': 'Videos, Music & Albums',
      'home_cat_all_videos': 'All Videos',
      'home_cat_images': 'Images',
      'home_cat_music': 'Music',
      'home_cat_status_saver': 'Status Saver',
      'home_cat_network': 'Network',

      // ComingSoon/coming_soon.dart
      'coming_soon_go_back': 'Go Back',

      // DirectoryFolder/directory_folder.dart
      'dir_folder_label': 'Folder',
      'dir_image_not_found': 'Image not found',
      'dir_permission_title': 'Storage access needed',
      'dir_permission_body':
          'Allow access to all files so folders on this device can be listed.',
      'dir_permission_grant': 'Allow access',
      'dir_permission_settings': 'Open settings',
      'dir_no_storage': 'No readable storage found on this device.',
      'dir_retry': 'Retry',

      // DirectoryFolder/file_browser/ -- the tabbed Files browser
      'fb_title': 'Files',
      'fb_tab_videos': 'Videos',
      'fb_tab_photos': 'Photos',
      'fb_tab_music': 'Music',
      'fb_tab_docs': 'Docs',
      'fb_tab_folders': 'Folders',
      'fb_videos_suffix': 'videos',
      'fb_photos_suffix': 'photos',
      'fb_songs_suffix': 'songs',
      'fb_empty_videos': 'No videos found on this device.',
      'fb_empty_photos': 'No photos found on this device.',
      'fb_empty_music': 'No music found on this device.',
      'fb_media_permission':
          'Allow access to photos and videos to browse them here.',
      'fb_audio_permission':
          'Allow access to music and audio to browse it here.',
      'fb_grant': 'Allow',
      'fb_docs_title': 'Choose a folder for documents',
      'fb_docs_body':
          'Pick any folder once and its PDFs, Office files, text files and '
              'archives show up here. The choice is remembered.',
      'fb_folders_title': 'Choose a folder to browse',
      'fb_folders_body':
          'Pick any folder once and you can open everything inside it, '
              'including sub-folders. The choice is remembered.',
      'fb_pick_folder': 'Choose folder',
      'fb_change_folder': 'Change',
      'fb_no_items': 'This folder is empty.',
      'fb_no_docs': 'No documents in this folder.',
      'fb_classic': 'Device storage (classic)',

      // RecentlyVideos/RecentlyPlayedScreen/recently_played_screen.dart
      'home_recently_played_title': 'Recently Played',
      'home_recently_played_subtitle': 'Your last watched videos',
      'home_clear': 'Clear',
      'recent_remove_video_title': 'Remove this video?',
      'recent_remove_video_desc':
          'This will remove only this item from Recently Played.',
      'recent_cancel': 'Cancel',
      'recent_remove_this': 'Remove This',
      'recent_clear_all': 'Clear All Recently Played',
    },
    'hi': {
      // home2.dart
      'home_permission_required_title': 'अनुमति आवश्यक है',
      'home_permission_required_desc':
          'अपनी मीडिया सामग्री देखने के लिए कृपया फ़ोटो और वीडियो तक पहुंच की अनुमति दें।',
      'home_allow_permissions': 'अनुमति दें',
      'home_folders': 'फ़ोल्डर',
      'home_no_albums_found': 'कोई एल्बम नहीं मिला',
      'home_sd_card': 'एसडी कार्ड',
      'home_videos_suffix': 'वीडियो',
      'home_videos_suffix_lower': 'वीडियो',
      'home_untitled_album': 'बिना नाम का एल्बम',

      // BottomsheetHomeScreen/bottomsheet_menu_button.dart
      'home_menu_open': 'खोलें',
      'home_menu_delete': 'हटाएं',
      'home_menu_info': 'जानकारी',
      'home_menu_copy': 'कॉपी',
      'home_menu_hide': 'छुपाएं',

      // DialogHomeScreen/FolderInfoDialog/folder_info_dialog.dart
      'folder_info_title': 'फ़ोल्डर जानकारी',
      'folder_info_name_label': 'फ़ोल्डर नाम',
      'folder_info_size_label': 'आकार',
      'folder_info_location_label': 'स्थान',
      'folder_info_modified_label': 'संशोधन तिथि',
      'folder_info_ok': 'ठीक है',

      // HorizontalGridList/horizontal_gridlist.dart
      'home_media_categories_title': 'मीडिया श्रेणियां',
      'home_media_categories_subtitle': 'वीडियो, संगीत और एल्बम',
      'home_cat_all_videos': 'सभी वीडियो',
      'home_cat_images': 'फ़ोटो',
      'home_cat_music': 'संगीत',
      'home_cat_status_saver': 'स्टेटस सेवर',
      'home_cat_network': 'नेटवर्क',

      // ComingSoon/coming_soon.dart
      'coming_soon_go_back': 'वापस जाएं',

      // DirectoryFolder/directory_folder.dart
      'dir_folder_label': 'फ़ोल्डर',
      'dir_image_not_found': 'छवि नहीं मिली',
      'dir_permission_title': 'स्टोरेज अनुमति चाहिए',
      'dir_permission_body':
          'इस डिवाइस के फ़ोल्डर दिखाने के लिए सभी फ़ाइलों तक पहुँच की अनुमति दें।',
      'dir_permission_grant': 'अनुमति दें',
      'dir_permission_settings': 'सेटिंग्स खोलें',
      'dir_no_storage': 'इस डिवाइस में कोई पढ़ने योग्य स्टोरेज नहीं मिला।',
      'dir_retry': 'फिर कोशिश करें',

      // DirectoryFolder/file_browser/ -- the tabbed Files browser
      'fb_title': 'फ़ाइलें',
      'fb_tab_videos': 'वीडियो',
      'fb_tab_photos': 'फ़ोटो',
      'fb_tab_music': 'म्यूज़िक',
      'fb_tab_docs': 'डॉक्यूमेंट',
      'fb_tab_folders': 'फ़ोल्डर',
      'fb_videos_suffix': 'वीडियो',
      'fb_photos_suffix': 'फ़ोटो',
      'fb_songs_suffix': 'गाने',
      'fb_empty_videos': 'इस डिवाइस में कोई वीडियो नहीं मिला।',
      'fb_empty_photos': 'इस डिवाइस में कोई फ़ोटो नहीं मिली।',
      'fb_empty_music': 'इस डिवाइस में कोई म्यूज़िक नहीं मिला।',
      'fb_media_permission':
          'यहाँ देखने के लिए फ़ोटो और वीडियो की अनुमति दें।',
      'fb_audio_permission':
          'यहाँ देखने के लिए म्यूज़िक और ऑडियो की अनुमति दें।',
      'fb_grant': 'अनुमति दें',
      'fb_docs_title': 'डॉक्यूमेंट के लिए फ़ोल्डर चुनें',
      'fb_docs_body':
          'एक बार कोई भी फ़ोल्डर चुनें, उसकी PDF, Office, टेक्स्ट और '
              'आर्काइव फ़ाइलें यहाँ दिखेंगी। चुनाव याद रखा जाता है।',
      'fb_folders_title': 'ब्राउज़ करने के लिए फ़ोल्डर चुनें',
      'fb_folders_body':
          'एक बार फ़ोल्डर चुनने पर उसके अंदर की सभी फ़ाइलें और '
              'सब-फ़ोल्डर खोल सकते हैं। चुनाव याद रखा जाता है।',
      'fb_pick_folder': 'फ़ोल्डर चुनें',
      'fb_change_folder': 'बदलें',
      'fb_no_items': 'यह फ़ोल्डर खाली है।',
      'fb_no_docs': 'इस फ़ोल्डर में कोई डॉक्यूमेंट नहीं है।',
      'fb_classic': 'डिवाइस स्टोरेज (क्लासिक)',

      // RecentlyVideos/RecentlyPlayedScreen/recently_played_screen.dart
      'home_recently_played_title': 'हाल ही में चलाए गए',
      'home_recently_played_subtitle': 'आपके हाल ही में देखे गए वीडियो',
      'home_clear': 'साफ़ करें',
      'recent_remove_video_title': 'यह वीडियो हटाएं?',
      'recent_remove_video_desc':
          'इससे केवल यह आइटम हाल ही में चलाए गए से हटेगा।',
      'recent_cancel': 'रद्द करें',
      'recent_remove_this': 'इसे हटाएं',
      'recent_clear_all': 'सभी हाल ही में चलाए गए साफ़ करें',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
