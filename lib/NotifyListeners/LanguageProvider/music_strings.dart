/// Tiny in-code translation table for the offline-music surfaces (tabs,
/// album/artist/genre pages, mini player, full-screen player). Mirrors the
/// pattern used by `AppStrings` but kept as a separate namespace so it can be
/// edited independently. Only `en` and `hi` are actually translated; any
/// other locale code falls back to English until real translations are
/// added for it.
class MusicStrings {
  static const Map<String, Map<String, String>> _values = {
    'en': {
      // Offline music tabs
      'music_tab_songs': 'Songs',
      'music_tab_artists': 'Artists',
      'music_tab_albums': 'Albums',
      'music_tab_genres': 'Genres',

      // Permission card
      'music_permission_required_title': 'Music Permission Required',
      'music_permission_required_desc':
          'Offline songs show karne ke liye audio/storage permission chahiye.',
      'music_open_settings': 'Open Settings',
      'music_allow_permission': 'Allow Permission',

      // Shared / common
      'music_unknown': 'Unknown',
      'music_unknown_artist': 'Unknown Artist',
      'music_songs_count_suffix': 'songs',
      'music_album_tag': 'Album',
      'music_nothing_found': 'Nothing found!',

      // Album page
      'music_play_all': 'Play All',
      'music_shuffle': 'Shuffle',
      'music_tracks_title': 'Tracks',
      'music_tap_to_play': 'Tap to play',
      'music_album_empty': 'No songs found in this album.',

      // Artist page
      'music_sort_az': 'A - Z',
      'music_sort_za': 'Z - A',
      'music_sort_duration_high': 'Long → Short',
      'music_sort_duration_low': 'Short → Long',
      'music_sort_newest': 'Newest',
      'music_sort_oldest': 'Oldest',
      'music_search_song_album_hint': 'Search song / album...',
      'music_loading': 'Loading...',
      'music_songs_suffix_cap': 'Songs',
      'music_no_songs_found': 'No songs found',

      // Albums view
      'music_search_albums_artist_hint': 'Search albums / artist...',
      'music_error_prefix': 'Error: ',
      'music_no_match_found': 'No match found!',
      'music_sort_label': 'Sort',
      'music_sort_album_az': 'Album A → Z',
      'music_sort_album_za': 'Album Z → A',
      'music_sort_artist_az': 'Artist A → Z',
      'music_sort_artist_za': 'Artist Z → A',

      // Artists view
      'music_search_artists_hint': 'Search artists...',
      'music_sort_az_short': 'A-Z',
      'music_sort_za_short': 'Z-A',
      'music_sort_most': 'Most',
      'music_sort_least': 'Least',
      'music_sort_most_songs': 'Most Songs',
      'music_sort_least_songs': 'Least Songs',

      // Genres view
      'music_song_singular': 'song',
      'music_song_plural': 'songs',

      // Songs view — bottom sheet options
      'music_play': 'Play',
      'music_play_next': 'Play Next',
      'music_lyrics': 'Lyrics',
      'music_ringtone_maker': 'Ringtone Maker',
      'music_add_to_playlist': 'Add to playlist',
      'music_lock': 'Lock',
      'music_share': 'Share',
      'music_add_to_queue': 'Add to Queue',
      'music_set_as_ringtone': 'Set as ringtone',
      'music_delete': 'Delete',
      'music_properties': 'Properties',
      'music_no_artist': 'No Artist',

      // Full player screen
      'music_adjust_volume': 'Adjust volume',
      'music_sleep_timer': 'Sleep Timer',
      'music_turn_off': 'Turn Off',
      'music_minutes_suffix': 'minutes',
      'music_close': 'Close',
      'music_now_playing_queue': 'Now Playing Queue',
      'music_playing_badge': 'PLAYING',
      'music_pause': 'Pause',
      'music_pause_current_song': 'Pause current song',
      'music_play_this_song_now': 'Play this song now',
      'music_share_subtitle': 'Share audio file or song details',
      'music_song_info': 'Song Info',
      'music_view_details': 'View details',
      'music_remove_from_device': 'Remove from device',
      'music_delete_song_confirm_title': 'Delete song?',
      'music_delete_song_confirm_content':
          'This will remove the audio file from your device.',
      'music_cancel': 'Cancel',
      'music_deleted_prefix': 'Deleted: ',
      'music_delete_failed': 'Delete failed',
      'music_song_information': 'Song Information',
      'music_duration_label': 'Duration',
      'music_id_label': 'ID',
    },
    'hi': {
      // Offline music tabs
      'music_tab_songs': 'गाने',
      'music_tab_artists': 'कलाकार',
      'music_tab_albums': 'एल्बम',
      'music_tab_genres': 'शैलियां',

      // Permission card
      'music_permission_required_title': 'संगीत अनुमति आवश्यक है',
      'music_permission_required_desc':
          'ऑफ़लाइन गाने दिखाने के लिए ऑडियो/स्टोरेज अनुमति आवश्यक है।',
      'music_open_settings': 'सेटिंग्स खोलें',
      'music_allow_permission': 'अनुमति दें',

      // Shared / common
      'music_unknown': 'अज्ञात',
      'music_unknown_artist': 'अज्ञात कलाकार',
      'music_songs_count_suffix': 'गाने',
      'music_album_tag': 'एल्बम',
      'music_nothing_found': 'कुछ नहीं मिला!',

      // Album page
      'music_play_all': 'सभी चलाएं',
      'music_shuffle': 'शफ़ल',
      'music_tracks_title': 'ट्रैक',
      'music_tap_to_play': 'चलाने के लिए टैप करें',
      'music_album_empty': 'इस एल्बम में कोई गाना नहीं मिला।',

      // Artist page
      'music_sort_az': 'A - Z',
      'music_sort_za': 'Z - A',
      'music_sort_duration_high': 'लंबा → छोटा',
      'music_sort_duration_low': 'छोटा → लंबा',
      'music_sort_newest': 'नवीनतम',
      'music_sort_oldest': 'सबसे पुराना',
      'music_search_song_album_hint': 'गाना / एल्बम खोजें...',
      'music_loading': 'लोड हो रहा है...',
      'music_songs_suffix_cap': 'गाने',
      'music_no_songs_found': 'कोई गाना नहीं मिला',

      // Albums view
      'music_search_albums_artist_hint': 'एल्बम / कलाकार खोजें...',
      'music_error_prefix': 'त्रुटि: ',
      'music_no_match_found': 'कोई मिलान नहीं मिला!',
      'music_sort_label': 'क्रमबद्ध करें',
      'music_sort_album_az': 'एल्बम A → Z',
      'music_sort_album_za': 'एल्बम Z → A',
      'music_sort_artist_az': 'कलाकार A → Z',
      'music_sort_artist_za': 'कलाकार Z → A',

      // Artists view
      'music_search_artists_hint': 'कलाकार खोजें...',
      'music_sort_az_short': 'A-Z',
      'music_sort_za_short': 'Z-A',
      'music_sort_most': 'सबसे ज़्यादा',
      'music_sort_least': 'सबसे कम',
      'music_sort_most_songs': 'सबसे ज़्यादा गाने',
      'music_sort_least_songs': 'सबसे कम गाने',

      // Genres view
      'music_song_singular': 'गाना',
      'music_song_plural': 'गाने',

      // Songs view — bottom sheet options
      'music_play': 'चलाएं',
      'music_play_next': 'अगला चलाएं',
      'music_lyrics': 'गीत के बोल',
      'music_ringtone_maker': 'रिंगटोन मेकर',
      'music_add_to_playlist': 'प्लेलिस्ट में जोड़ें',
      'music_lock': 'लॉक करें',
      'music_share': 'शेयर करें',
      'music_add_to_queue': 'कतार में जोड़ें',
      'music_set_as_ringtone': 'रिंगटोन के रूप में सेट करें',
      'music_delete': 'हटाएं',
      'music_properties': 'विशेषताएं',
      'music_no_artist': 'कोई कलाकार नहीं',

      // Full player screen
      'music_adjust_volume': 'आवाज़ समायोजित करें',
      'music_sleep_timer': 'स्लीप टाइमर',
      'music_turn_off': 'बंद करें',
      'music_minutes_suffix': 'मिनट',
      'music_close': 'बंद करें',
      'music_now_playing_queue': 'चल रही कतार',
      'music_playing_badge': 'चल रहा है',
      'music_pause': 'रोकें',
      'music_pause_current_song': 'मौजूदा गाना रोकें',
      'music_play_this_song_now': 'यह गाना अभी चलाएं',
      'music_share_subtitle': 'ऑडियो फ़ाइल या गाने का विवरण शेयर करें',
      'music_song_info': 'गाने की जानकारी',
      'music_view_details': 'विवरण देखें',
      'music_remove_from_device': 'डिवाइस से हटाएं',
      'music_delete_song_confirm_title': 'गाना हटाएं?',
      'music_delete_song_confirm_content':
          'इससे ऑडियो फ़ाइल आपके डिवाइस से हट जाएगी।',
      'music_cancel': 'रद्द करें',
      'music_deleted_prefix': 'हटाया गया: ',
      'music_delete_failed': 'हटाने में विफल',
      'music_song_information': 'गाने की जानकारी',
      'music_duration_label': 'अवधि',
      'music_id_label': 'आईडी',
    },
  };

  static String t(String languageCode, String key) {
    return _values[languageCode]?[key] ?? _values['en']![key] ?? key;
  }
}
