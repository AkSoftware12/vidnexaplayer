/// Tiny in-code translation table for the video/streaming surfaces of the
/// app (YouTube playlists, network stream screen, the 4K player and its
/// popups, the local video list, and the custom video app bar).
///
/// Only `en` and `hi` are actually translated; any other locale code falls
/// back to English until real translations are added for it. Mirrors the
/// exact pattern used by `AppStrings` — kept as a separate namespace/file so
/// work on other screens doesn't collide here.
class VideoStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // Common action words reused across several dialogs/menus.
      'common_ok': 'OK',
      'common_reset': 'Reset',
      'common_cancel': 'Cancel',
      'common_done': 'Done',
      'common_delete': 'Delete',
      'common_play': 'Play',
      'common_pause': 'Pause',
      'common_info': 'Info',
      'common_share': 'Share',
      'common_loading': 'Loading...',

      // YouTube playlists / playlist videos.
      'yt_no_playlists_found': 'No playlists found',
      'yt_loading_videos': 'Loading videos...',
      'yt_no_videos_found': 'No videos found',

      // Network stream screen.
      'stream_please_enter_url': 'Please enter a video URL',
      'stream_enter_full_url':
          'Enter a full URL, e.g. https://example.com/video.mp4',
      'stream_appbar_title': 'Stream Video',
      'stream_card_title': 'Stream Your Video',
      'stream_url_label': 'Enter Video URL',
      'stream_play_now': 'Play Now',

      // HDR / filter popup.
      'hdr_dialog_title': 'HDR',
      'hdr_filter_normal': 'Normal',
      'hdr_filter_dark': 'Dark',
      'hdr_filter_blue': 'Blue',
      'hdr_filter_warm': 'Warm HDR',
      'hdr_filter_sepia': 'Sepia',
      'hdr_filter_neon': 'Neon',
      'hdr_filter_green': 'Green',
      'hdr_filter_hdr': 'HDR',

      // Playback speed dialog.
      'speed_adjust_title': 'Adjust Speed',

      // Volume / boost dialog.
      'volume_title': 'Volume',
      'volume_boost_title': 'Volume Boost',
      'volume_boost_badge': 'BOOST',
      'volume_hint_distort': '⚠️ Very high boost can distort the audio.',
      'volume_hint_max_gain':
          'Device volume is at max — this is extra gain.',
      'volume_hint_drag_boost': 'Drag past 100% for boost.',

      // Local video list (folder screen).
      'video_no_videos_in_folder': 'No videos in this folder',
      'video_delete_success': '🗑️ Video deleted successfully',
      'video_delete_failed_prefix': '❌ Failed to delete video:',
      'video_unable_access_file': '❌ Unable to access video file',
      'video_permission_denied': 'Permission denied',
      'video_delete_dialog_title': 'Delete Video',
      'video_delete_dialog_content':
          'Are you sure you want to delete this video?',
      'video_deleted_from_device': 'Video deleted from device',
      'video_delete_failed_generic': 'Failed to delete video',
      'video_delete_error_prefix': 'Error deleting video:',
      'video_file_not_found': '❌ File not found',
      'video_share_failed': '❌ Failed to share video',
      'video_info_title': 'Video Info',
      'video_info_file_not_found': 'File not found',
      'video_info_name': 'Name',
      'video_info_path': 'Path',
      'video_info_size': 'Size',
      'video_info_duration': 'Duration',
      'video_info_last_modified': 'Last Modified',
      'video_info_unknown': 'Unknown',
      'video_untitled': 'Untitled',
      'video_file_missing': 'File missing',

      // 4K player screen, popups and control sheets.
      'player_video_file_not_found': 'Video file not found',
      'player_link_play_failed_prefix': 'Link play failed:',
      'player_playback_failed_prefix': 'Playback failed:',
      'player_screenshot_failed_empty_frame':
          'Screenshot failed: empty frame',
      'player_storage_permission_denied': 'Storage permission denied',
      'player_screenshot_saved': 'Screenshot saved to gallery',
      'player_screenshot_save_failed': 'Screenshot save failed',
      'player_screenshot_failed_prefix': 'Screenshot failed:',
      'player_boost_not_supported': 'BOOST NOT SUPPORTED',
      'player_boost_hint_normal':
          '100% = normal. Device volume works separately.',
      'player_controls_title': 'Player Controls',
      'player_controls_barrier_label': 'Controls',
      'player_quick_actions': 'Quick Actions',
      'player_action_screenshot': 'Screenshot',
      'player_action_rotate': 'Rotate',
      'player_action_video_on': 'Video On',
      'player_action_audio_only': 'Audio Only',
      'player_action_filters': 'Filters',
      'player_action_hdr': 'HDR',
      'player_action_boost': 'Boost',
      'player_action_speed': 'Speed',
      'player_action_pip': 'PIP',
      'player_playback_section': 'Playback',
      'player_locked': 'Locked',
      'player_lock': 'Lock',
      'player_prev': 'Prev',
      'player_next': 'Next',
      'player_resize': 'Resize',
      'player_hdr_processing': 'HDR PROCESSING',
      'player_hdr_turning_off': 'Turning HDR OFF',
      'player_hdr_turning_on': 'Turning HDR ON',
      'player_streaming_title': 'Streaming',

      // Custom video app bar / playlist panel.
      'appbar_tooltip_back': 'Back',
      'appbar_tooltip_playlist': 'Playlist',
      'appbar_tooltip_all_item': 'All Item',
      'appbar_playlist_suffix': 'Playlist',
      'playlist_panel_title': 'Playlist',
      'playlist_panel_playing_suffix': 'playing',
      'playlist_tile_playing_badge': 'PLAYING',
    },
    'hi': {
      'common_ok': 'ठीक है',
      'common_reset': 'रीसेट करें',
      'common_cancel': 'रद्द करें',
      'common_done': 'हो गया',
      'common_delete': 'हटाएं',
      'common_play': 'चलाएं',
      'common_pause': 'रोकें',
      'common_info': 'जानकारी',
      'common_share': 'साझा करें',
      'common_loading': 'लोड हो रहा है...',

      'yt_no_playlists_found': 'कोई प्लेलिस्ट नहीं मिली',
      'yt_loading_videos': 'वीडियो लोड हो रहे हैं...',
      'yt_no_videos_found': 'कोई वीडियो नहीं मिला',

      'stream_please_enter_url': 'कृपया वीडियो का URL दर्ज करें',
      'stream_enter_full_url':
          'पूरा URL दर्ज करें, जैसे https://example.com/video.mp4',
      'stream_appbar_title': 'वीडियो स्ट्रीम करें',
      'stream_card_title': 'अपना वीडियो स्ट्रीम करें',
      'stream_url_label': 'वीडियो का URL दर्ज करें',
      'stream_play_now': 'अभी चलाएं',

      'hdr_dialog_title': 'HDR',
      'hdr_filter_normal': 'सामान्य',
      'hdr_filter_dark': 'डार्क',
      'hdr_filter_blue': 'नीला',
      'hdr_filter_warm': 'वॉर्म HDR',
      'hdr_filter_sepia': 'सेपिया',
      'hdr_filter_neon': 'नियॉन',
      'hdr_filter_green': 'हरा',
      'hdr_filter_hdr': 'HDR',

      'speed_adjust_title': 'गति समायोजित करें',

      'volume_title': 'आवाज़',
      'volume_boost_title': 'आवाज़ बूस्ट',
      'volume_boost_badge': 'बूस्ट',
      'volume_hint_distort': '⚠️ बहुत ज़्यादा बूस्ट से आवाज़ खराब हो सकती है।',
      'volume_hint_max_gain':
          'डिवाइस की आवाज़ अधिकतम पर है — यह अतिरिक्त गेन है।',
      'volume_hint_drag_boost': 'बूस्ट के लिए 100% से आगे खींचें।',

      'video_no_videos_in_folder': 'इस फ़ोल्डर में कोई वीडियो नहीं है',
      'video_delete_success': '🗑️ वीडियो सफलतापूर्वक हटाया गया',
      'video_delete_failed_prefix': '❌ वीडियो हटाने में विफल:',
      'video_unable_access_file': '❌ वीडियो फ़ाइल तक पहुंचा नहीं जा सका',
      'video_permission_denied': 'अनुमति अस्वीकृत',
      'video_delete_dialog_title': 'वीडियो हटाएं',
      'video_delete_dialog_content':
          'क्या आप वाकई इस वीडियो को हटाना चाहते हैं?',
      'video_deleted_from_device': 'वीडियो डिवाइस से हटा दिया गया',
      'video_delete_failed_generic': 'वीडियो हटाने में विफल रहा',
      'video_delete_error_prefix': 'वीडियो हटाने में त्रुटि:',
      'video_file_not_found': '❌ फ़ाइल नहीं मिली',
      'video_share_failed': '❌ वीडियो साझा करने में विफल',
      'video_info_title': 'वीडियो जानकारी',
      'video_info_file_not_found': 'फ़ाइल नहीं मिली',
      'video_info_name': 'नाम',
      'video_info_path': 'पथ',
      'video_info_size': 'आकार',
      'video_info_duration': 'अवधि',
      'video_info_last_modified': 'अंतिम बार संशोधित',
      'video_info_unknown': 'अज्ञात',
      'video_untitled': 'बिना शीर्षक',
      'video_file_missing': 'फ़ाइल गुम है',

      'player_video_file_not_found': 'वीडियो फ़ाइल नहीं मिली',
      'player_link_play_failed_prefix': 'लिंक चलाने में विफल:',
      'player_playback_failed_prefix': 'प्लेबैक विफल:',
      'player_screenshot_failed_empty_frame':
          'स्क्रीनशॉट विफल: खाली फ्रेम',
      'player_storage_permission_denied': 'स्टोरेज अनुमति अस्वीकृत',
      'player_screenshot_saved': 'स्क्रीनशॉट गैलरी में सेव हो गया',
      'player_screenshot_save_failed': 'स्क्रीनशॉट सेव करने में विफल',
      'player_screenshot_failed_prefix': 'स्क्रीनशॉट विफल:',
      'player_boost_not_supported': 'बूस्ट समर्थित नहीं है',
      'player_boost_hint_normal':
          '100% = सामान्य। डिवाइस की आवाज़ अलग से काम करती है।',
      'player_controls_title': 'प्लेयर नियंत्रण',
      'player_controls_barrier_label': 'नियंत्रण',
      'player_quick_actions': 'त्वरित क्रियाएं',
      'player_action_screenshot': 'स्क्रीनशॉट',
      'player_action_rotate': 'घुमाएं',
      'player_action_video_on': 'वीडियो चालू',
      'player_action_audio_only': 'केवल ऑडियो',
      'player_action_filters': 'फ़िल्टर',
      'player_action_hdr': 'HDR',
      'player_action_boost': 'बूस्ट',
      'player_action_speed': 'गति',
      'player_action_pip': 'PIP',
      'player_playback_section': 'प्लेबैक',
      'player_locked': 'लॉक्ड',
      'player_lock': 'लॉक',
      'player_prev': 'पिछला',
      'player_next': 'अगला',
      'player_resize': 'आकार बदलें',
      'player_hdr_processing': 'HDR प्रोसेसिंग',
      'player_hdr_turning_off': 'HDR बंद हो रहा है',
      'player_hdr_turning_on': 'HDR चालू हो रहा है',
      'player_streaming_title': 'स्ट्रीमिंग',

      'appbar_tooltip_back': 'वापस',
      'appbar_tooltip_playlist': 'प्लेलिस्ट',
      'appbar_tooltip_all_item': 'सभी आइटम',
      'appbar_playlist_suffix': 'प्लेलिस्ट',
      'playlist_panel_title': 'प्लेलिस्ट',
      'playlist_panel_playing_suffix': 'चल रहा है',
      'playlist_tile_playing_badge': 'चल रहा है',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
