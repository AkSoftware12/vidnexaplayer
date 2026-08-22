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
