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
      'home_cat_images': 'Gallery',
      'home_cat_files': 'Files',
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

      // ── File operations ──
      'fb_search_hint': 'Search in this folder',
      'fb_search_deep': 'Search sub-folders',
      'fb_searching': 'Searching…',
      'fb_no_matches': 'Nothing matched',
      'fb_sort': 'Sort by',
      'fb_sort_name_asc': 'Name (A–Z)',
      'fb_sort_name_desc': 'Name (Z–A)',
      'fb_sort_size_desc': 'Size (largest)',
      'fb_sort_size_asc': 'Size (smallest)',
      'fb_sort_date_desc': 'Newest first',
      'fb_sort_date_asc': 'Oldest first',
      'fb_sort_type': 'Type',
      'fb_view_grid': 'Grid view',
      'fb_view_list': 'List view',
      'fb_show_hidden': 'Show hidden files',
      'fb_new_folder': 'New folder',
      'fb_folder_name': 'Folder name',
      'fb_create': 'Create',
      'fb_cancel': 'Cancel',
      'fb_rename': 'Rename',
      'fb_new_name': 'New name',
      'fb_copy': 'Copy',
      'fb_cut': 'Cut',
      'fb_paste': 'Paste',
      'fb_delete': 'Delete',
      'fb_share': 'Share',
      'fb_properties': 'Properties',
      'fb_select_all': 'Select all',
      'fb_selected': '{count} selected',
      'fb_delete_confirm': 'Delete {count} item(s)? This cannot be undone.',
      'fb_working': 'Working… {done}/{total}',
      'fb_done_some': '{ok} done, {bad} failed',
      'fb_done_all': '{ok} done',
      'fb_clipboard_ready': '{count} item(s) ready to paste',
      'fb_prop_name': 'Name',
      'fb_prop_path': 'Location',
      'fb_prop_size': 'Size',
      'fb_prop_type': 'Type',
      'fb_prop_modified': 'Modified',
      'fb_prop_perms': 'Access',
      'fb_perm_read': 'read',
      'fb_perm_write': 'write',
      'fb_perm_delete': 'delete',
      'fb_close': 'Close',
      'fb_more': 'More',
      'fb_items_count': '{count} items',
      'fb_downloads': 'Downloads',
      'fb_no_files': 'Nothing here yet',
      'fb_open_failed': 'No app on this device can open this file',
      'fb_folder': 'Folder',
      'fb_copied': 'Copied',

      // ── Bookmarks ──
      'fb_bookmarks': 'Bookmarks',
      'fb_bookmark_add': 'Bookmark this folder',
      'fb_bookmark_remove': 'Remove bookmark',
      'fb_no_bookmarks': 'No bookmarks yet',

      // ── Archives ──
      'fb_compress': 'Compress to ZIP',
      'fb_extract': 'Extract here',
      'fb_zip_name': 'Archive name',
      'fb_zip_only': 'Only ZIP files can be extracted in-app',
      'fb_zip_failed': 'Could not create the archive',
      'fb_extract_failed': 'Could not extract this archive',

      // ── Scans (categories / recent / analyzer / duplicates) ──
      'fb_categories': 'Categories',
      'fb_recent': 'Recent files',
      'fb_analyzer': 'Storage analyzer',
      'fb_duplicates': 'Duplicate finder',
      'fb_cat_images': 'Images',
      'fb_cat_videos': 'Videos',
      'fb_cat_audio': 'Audio',
      'fb_cat_documents': 'Documents',
      'fb_cat_apks': 'APKs',
      'fb_cat_archives': 'Archives',
      'fb_cat_other': 'Other',
      'fb_scanning': 'Scanning… {files} files in {folders} folders',
      'fb_scan_files': '{count} files',
      'fb_by_folder': 'By folder',
      'fb_no_duplicates': 'No duplicates found',
      'fb_dupes_summary': '{groups} sets of duplicates · {size} wasted',
      'fb_scan_no_folder':
          'Pick a folder in the Folders tab first — that is the folder these '
              'tools look inside.',
      'fb_scan_truncated':
          'Showing the first {files} files. Pick a smaller folder for a '
              'complete picture.',

      // ── Wireless transfer ──
      'fb_wireless': 'Wireless transfer',
      'fb_wireless_on': 'Server running',
      'fb_wireless_off': 'Server stopped',
      'fb_wireless_body':
          'Open this address in any browser on the same Wi-Fi to download '
              'files from this folder. Downloads only — nothing can be '
              'written to your phone.',
      'fb_wireless_start': 'Start server',
      'fb_wireless_stop': 'Stop server',
      'fb_wireless_stats': 'Sharing {files} files · {hits} requests',
      'fb_wifi_needed': 'Connect to Wi-Fi first',

      // ── Vault ──
      'fb_to_vault': 'Move to vault',
      'fb_vault_done': 'Moved to vault',
      'fb_vault_failed': 'Could not move to vault',

      // ── File Manager tool rows ──
      'device_tools': 'Tools',
      'device_tools_categories': 'Images, videos, APKs, archives',
      'device_tools_recent': 'Changed in the last 30 days',
      'device_tools_analyzer': 'See what is using the space',
      'device_tools_duplicates': 'Find identical copies',
      'device_tools_wireless': 'Download to a PC over Wi-Fi',
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
      'home_cat_images': 'गैलरी',
      'home_cat_files': 'फ़ाइलें',
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

      // ── File operations ──
      'fb_search_hint': 'इस फ़ोल्डर में खोजें',
      'fb_search_deep': 'सब-फ़ोल्डर में खोजें',
      'fb_searching': 'खोजा जा रहा है…',
      'fb_no_matches': 'कुछ नहीं मिला',
      'fb_sort': 'क्रम',
      'fb_sort_name_asc': 'नाम (A–Z)',
      'fb_sort_name_desc': 'नाम (Z–A)',
      'fb_sort_size_desc': 'साइज़ (बड़ा पहले)',
      'fb_sort_size_asc': 'साइज़ (छोटा पहले)',
      'fb_sort_date_desc': 'नया पहले',
      'fb_sort_date_asc': 'पुराना पहले',
      'fb_sort_type': 'टाइप',
      'fb_view_grid': 'ग्रिड व्यू',
      'fb_view_list': 'लिस्ट व्यू',
      'fb_show_hidden': 'छिपी फ़ाइलें दिखाएँ',
      'fb_new_folder': 'नया फ़ोल्डर',
      'fb_folder_name': 'फ़ोल्डर का नाम',
      'fb_create': 'बनाएँ',
      'fb_cancel': 'रद्द करें',
      'fb_rename': 'नाम बदलें',
      'fb_new_name': 'नया नाम',
      'fb_copy': 'कॉपी',
      'fb_cut': 'कट',
      'fb_paste': 'पेस्ट',
      'fb_delete': 'हटाएँ',
      'fb_share': 'शेयर',
      'fb_properties': 'जानकारी',
      'fb_select_all': 'सभी चुनें',
      'fb_selected': '{count} चुने गए',
      'fb_delete_confirm': '{count} आइटम हटाएँ? ये वापस नहीं आएँगे।',
      'fb_working': 'चल रहा है… {done}/{total}',
      'fb_done_some': '{ok} हुए, {bad} नहीं हुए',
      'fb_done_all': '{ok} हुए',
      'fb_clipboard_ready': '{count} आइटम पेस्ट के लिए तैयार',
      'fb_prop_name': 'नाम',
      'fb_prop_path': 'जगह',
      'fb_prop_size': 'साइज़',
      'fb_prop_type': 'टाइप',
      'fb_prop_modified': 'बदला गया',
      'fb_prop_perms': 'एक्सेस',
      'fb_perm_read': 'पढ़ना',
      'fb_perm_write': 'लिखना',
      'fb_perm_delete': 'हटाना',
      'fb_close': 'बंद करें',
      'fb_more': 'और',
      'fb_items_count': '{count} आइटम',
      'fb_downloads': 'डाउनलोड',
      'fb_no_files': 'यहाँ अभी कुछ नहीं है',
      'fb_open_failed': 'इस फ़ाइल को खोलने वाला कोई ऐप नहीं है',
      'fb_folder': 'फ़ोल्डर',
      'fb_copied': 'कॉपी हो गया',

      // ── Bookmarks ──
      'fb_bookmarks': 'बुकमार्क',
      'fb_bookmark_add': 'इस फ़ोल्डर को बुकमार्क करें',
      'fb_bookmark_remove': 'बुकमार्क हटाएँ',
      'fb_no_bookmarks': 'अभी कोई बुकमार्क नहीं',

      // ── Archives ──
      'fb_compress': 'ZIP बनाएँ',
      'fb_extract': 'यहीं एक्सट्रैक्ट करें',
      'fb_zip_name': 'आर्काइव का नाम',
      'fb_zip_only': 'ऐप में सिर्फ़ ZIP फ़ाइलें एक्सट्रैक्ट हो सकती हैं',
      'fb_zip_failed': 'आर्काइव नहीं बन पाया',
      'fb_extract_failed': 'ये आर्काइव एक्सट्रैक्ट नहीं हो पाया',

      // ── Scans ──
      'fb_categories': 'श्रेणियाँ',
      'fb_recent': 'हाल की फ़ाइलें',
      'fb_analyzer': 'स्टोरेज एनालाइज़र',
      'fb_duplicates': 'डुप्लिकेट खोजें',
      'fb_cat_images': 'इमेज',
      'fb_cat_videos': 'वीडियो',
      'fb_cat_audio': 'ऑडियो',
      'fb_cat_documents': 'डॉक्यूमेंट',
      'fb_cat_apks': 'APK',
      'fb_cat_archives': 'आर्काइव',
      'fb_cat_other': 'अन्य',
      'fb_scanning': 'स्कैन हो रहा है… {folders} फ़ोल्डर में {files} फ़ाइलें',
      'fb_scan_files': '{count} फ़ाइलें',
      'fb_by_folder': 'फ़ोल्डर के हिसाब से',
      'fb_no_duplicates': 'कोई डुप्लिकेट नहीं मिली',
      'fb_dupes_summary': '{groups} डुप्लिकेट सेट · {size} बर्बाद',
      'fb_scan_no_folder':
          'पहले Folders टैब में एक फ़ोल्डर चुनें — ये टूल उसी फ़ोल्डर के '
              'अंदर देखते हैं।',
      'fb_scan_truncated':
          'पहली {files} फ़ाइलें दिखाई जा रही हैं। पूरी जानकारी के लिए छोटा '
              'फ़ोल्डर चुनें।',

      // ── Wireless transfer ──
      'fb_wireless': 'वायरलेस ट्रांसफ़र',
      'fb_wireless_on': 'सर्वर चालू है',
      'fb_wireless_off': 'सर्वर बंद है',
      'fb_wireless_body':
          'इसी Wi-Fi पर किसी भी ब्राउज़र में ये पता खोलें और फ़ोल्डर की '
              'फ़ाइलें डाउनलोड करें। सिर्फ़ डाउनलोड — फ़ोन पर कुछ लिखा '
              'नहीं जा सकता।',
      'fb_wireless_start': 'सर्वर चालू करें',
      'fb_wireless_stop': 'सर्वर बंद करें',
      'fb_wireless_stats': '{files} फ़ाइलें शेयर · {hits} रिक्वेस्ट',
      'fb_wifi_needed': 'पहले Wi-Fi से जुड़ें',

      // ── Vault ──
      'fb_to_vault': 'वॉल्ट में डालें',
      'fb_vault_done': 'वॉल्ट में चला गया',
      'fb_vault_failed': 'वॉल्ट में नहीं डाल पाए',

      // ── File Manager tool rows ──
      'device_tools': 'टूल',
      'device_tools_categories': 'इमेज, वीडियो, APK, आर्काइव',
      'device_tools_recent': 'पिछले 30 दिन में बदली',
      'device_tools_analyzer': 'देखें जगह कहाँ जा रही है',
      'device_tools_duplicates': 'एक जैसी कॉपी खोजें',
      'device_tools_wireless': 'Wi-Fi से PC पर डाउनलोड करें',
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
