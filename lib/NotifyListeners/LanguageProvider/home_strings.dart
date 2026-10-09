import 'translations/vi.dart';
import 'translations/tr.dart';
import 'translations/ru.dart';
import 'translations/bn.dart';
import 'translations/ar.dart';
import 'translations/id.dart';
import 'translations/pt.dart';
import 'translations/es.dart';
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
          'Allow access to the files on this device so its folders can be listed.',
      'dir_permission_grant': 'Allow access',
      'dir_no_storage': 'No readable storage found on this device.',
      'dir_retry': 'Retry',

      // DirectoryFolder/file_browser/ -- the tabbed Files browser
      'fb_tab_videos': 'Videos',
      'fb_tab_photos': 'Photos',
      'fb_tab_music': 'Music',
      'fb_tab_docs': 'Docs',
      'fb_tab_folders': 'Folders',
      'fb_media_permission':
          'Allow access to photos and videos to browse them here.',
      'fb_grant': 'Allow',

      // ── File operations ──
      'fb_search_hint': 'Search in this folder',
      'fb_searching': 'Searching…',
      'fb_no_matches': 'Nothing matched',
      'fb_sort': 'Sort by',
      'fb_sort_name_asc': 'Name (A–Z)',
      'fb_sort_name_desc': 'Name (Z–A)',
      'fb_sort_size_desc': 'Size (largest)',
      'fb_sort_size_asc': 'Size (smallest)',
      'fb_sort_date_desc': 'Newest first',
      'fb_sort_date_asc': 'Oldest first',
      'fb_view_grid': 'Grid view',
      'fb_view_list': 'List view',
      'fb_copy': 'Copy',
      'fb_working': 'Working… {done}/{total}',
      'fb_items_count': '{count} items',
      'fb_downloads': 'Downloads',
      'fb_no_files': 'Nothing here yet',
      'fb_open_failed': 'No app on this device can open this file',
      'fb_copied': 'Copied',

      // ── Scans (categories / recent / analyzer / duplicates) ──
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
      'fb_by_folder': 'By folder',
      'fb_no_duplicates': 'No duplicates found',
      'fb_dupes_summary': '{groups} sets of duplicates · {size} wasted',
      'fb_scan_no_folder':
          'That folder is no longer available. Choose it again.',

      // ── Wireless transfer ──
      'fb_wireless': 'Wireless transfer',
      'fb_wireless_on': 'Server running',
      'fb_wireless_off': 'Server stopped',
      'fb_wireless_body':
          'Open this exact address in any browser on the same Wi-Fi to '
              'download files from this folder. The code in it changes every '
              'time you start, so only someone you give it to can connect. '
              'Downloads only — nothing can be written to your phone.',
      'fb_wireless_start': 'Start server',
      'fb_wireless_stop': 'Stop server',
      'fb_wireless_stats': 'Sharing {files} files · {hits} requests',
      'fb_wifi_needed': 'Connect to Wi-Fi first',
      'fb_wireless_no_folder': 'No folder chosen',
      'fb_pick_folder': 'Choose folder',
      'fb_change_folder': 'Change',

      // ── File Manager tool rows ──
      'device_tools': 'Tools',
      'device_tools_recent': 'Changed in the last 30 days',
      'device_tools_analyzer': 'See what is using the space',
      'device_tools_duplicates': 'Find identical copies',
      'device_tools_wireless': 'Download to a PC over Wi-Fi',

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
    'es': esHome,
    'pt': ptHome,
    'id': idHome,
    'ar': arHome,
    'bn': bnHome,
    'ru': ruHome,
    'tr': trHome,
    'vi': viHome,
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
          'इस डिवाइस के फ़ोल्डर दिखाने के लिए इसकी फ़ाइलों का एक्सेस दें।',
      'dir_permission_grant': 'अनुमति दें',
      'dir_no_storage': 'इस डिवाइस में कोई पढ़ने योग्य स्टोरेज नहीं मिला।',
      'dir_retry': 'फिर कोशिश करें',

      // DirectoryFolder/file_browser/ -- the tabbed Files browser
      'fb_tab_videos': 'वीडियो',
      'fb_tab_photos': 'फ़ोटो',
      'fb_tab_music': 'म्यूज़िक',
      'fb_tab_docs': 'डॉक्यूमेंट',
      'fb_tab_folders': 'फ़ोल्डर',
      'fb_media_permission':
          'यहाँ देखने के लिए फ़ोटो और वीडियो की अनुमति दें।',
      'fb_grant': 'अनुमति दें',

      // ── File operations ──
      'fb_search_hint': 'इस फ़ोल्डर में खोजें',
      'fb_searching': 'खोजा जा रहा है…',
      'fb_no_matches': 'कुछ नहीं मिला',
      'fb_sort': 'क्रम',
      'fb_sort_name_asc': 'नाम (A–Z)',
      'fb_sort_name_desc': 'नाम (Z–A)',
      'fb_sort_size_desc': 'साइज़ (बड़ा पहले)',
      'fb_sort_size_asc': 'साइज़ (छोटा पहले)',
      'fb_sort_date_desc': 'नया पहले',
      'fb_sort_date_asc': 'पुराना पहले',
      'fb_view_grid': 'ग्रिड व्यू',
      'fb_view_list': 'लिस्ट व्यू',
      'fb_copy': 'कॉपी',
      'fb_working': 'चल रहा है… {done}/{total}',
      'fb_items_count': '{count} आइटम',
      'fb_downloads': 'डाउनलोड',
      'fb_no_files': 'यहाँ अभी कुछ नहीं है',
      'fb_open_failed': 'इस फ़ाइल को खोलने वाला कोई ऐप नहीं है',
      'fb_copied': 'कॉपी हो गया',

      // ── Scans ──
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
      'fb_by_folder': 'फ़ोल्डर के हिसाब से',
      'fb_no_duplicates': 'कोई डुप्लिकेट नहीं मिली',
      'fb_dupes_summary': '{groups} डुप्लिकेट सेट · {size} बर्बाद',
      'fb_scan_no_folder':
          'वह फ़ोल्डर अब उपलब्ध नहीं है। उसे फिर से चुनें।',

      // ── Wireless transfer ──
      'fb_wireless': 'वायरलेस ट्रांसफ़र',
      'fb_wireless_on': 'सर्वर चालू है',
      'fb_wireless_off': 'सर्वर बंद है',
      'fb_wireless_body':
          'इसी Wi-Fi पर किसी भी ब्राउज़र में ठीक यही पता खोलें और फ़ोल्डर की '
              'फ़ाइलें डाउनलोड करें। इसमें लगा कोड हर बार बदलता है, इसलिए सिर्फ़ '
              'वही जुड़ पाएगा जिसे आप ये पता देंगे। सिर्फ़ डाउनलोड — फ़ोन पर कुछ '
              'लिखा नहीं जा सकता।',
      'fb_wireless_start': 'सर्वर चालू करें',
      'fb_wireless_stop': 'सर्वर बंद करें',
      'fb_wireless_stats': '{files} फ़ाइलें शेयर · {hits} रिक्वेस्ट',
      'fb_wifi_needed': 'पहले Wi-Fi से जुड़ें',
      'fb_wireless_no_folder': 'कोई फ़ोल्डर नहीं चुना',
      'fb_pick_folder': 'फ़ोल्डर चुनें',
      'fb_change_folder': 'बदलें',

      // ── File Manager tool rows ──
      'device_tools': 'टूल',
      'device_tools_recent': 'पिछले 30 दिन में बदली',
      'device_tools_analyzer': 'देखें जगह कहाँ जा रही है',
      'device_tools_duplicates': 'एक जैसी कॉपी खोजें',
      'device_tools_wireless': 'Wi-Fi से PC पर डाउनलोड करें',

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
