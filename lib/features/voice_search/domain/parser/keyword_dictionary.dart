/// Hindi / Hinglish / English vocabulary used by the voice command extractors.
///
/// Centralised here so adding support for a new spoken word (a new folder
/// alias, a new filler word, a new "bigger than" synonym, ...) is a one-line
/// change instead of hunting through extractor logic.
class VoiceKeywords {
  VoiceKeywords._();

  /// Spoken word -> canonical file extension (without the dot).
  static const Map<String, String> extensionWords = {
    'mp4': 'mp4',
    'mkv': 'mkv',
    'avi': 'avi',
    'mov': 'mov',
    'webm': 'webm',
    '3gp': '3gp',
    'm4v': 'm4v',
    'flv': 'flv',
    'wmv': 'wmv',
  };

  /// Words that switch the search to photos/images instead of videos.
  static const Set<String> photoWords = {
    'photo', 'photos', 'image', 'images', 'picture', 'pictures',
    'pic', 'pics', 'tasveer', 'tasveerein', 'tasvir', 'tasveere',
  };

  /// Words that switch the search to music/audio tracks instead of videos.
  static const Set<String> musicWords = {
    'mp3', 'music', 'song', 'songs', 'audio', 'track', 'tracks',
    'gana', 'gaana', 'gaane', 'geet',
  };

  /// Spoken size unit -> canonical unit key.
  static const Map<String, String> sizeUnits = {
    'gb': 'gb',
    'gigabyte': 'gb',
    'gigabytes': 'gb',
    'mb': 'mb',
    'megabyte': 'mb',
    'megabytes': 'mb',
    'kb': 'kb',
    'kilobyte': 'kb',
    'kilobytes': 'kb',
  };

  static const Map<String, int> sizeUnitToBytes = {
    'gb': 1024 * 1024 * 1024,
    'mb': 1024 * 1024,
    'kb': 1024,
  };

  /// Default threshold used when the user says "badi videos" with no number.
  static const int defaultSizeThresholdBytes = 100 * 1024 * 1024; // 100 MB

  static const Set<String> sizeGreaterWords = {
    'badi', 'bada', 'bade', 'bigger', 'larger', 'large', 'big',
    'zyada', 'jyada', 'more', 'upar',
  };

  static const Set<String> sizeSmallerWords = {
    'choti', 'chota', 'chote', 'smaller', 'small', 'kam', 'niche',
  };

  /// Spoken duration unit -> canonical unit key.
  static const Map<String, String> durationUnits = {
    'second': 's', 'seconds': 's', 'sec': 's', 'secs': 's',
    'minute': 'm', 'minutes': 'm', 'min': 'm', 'mins': 'm',
    'hour': 'h', 'hours': 'h', 'hr': 'h', 'hrs': 'h',
  };

  /// Default threshold used when the user says "lambi videos" with no number.
  static const Duration defaultDurationThreshold = Duration(minutes: 10);

  static const Set<String> durationGreaterWords = {
    'zyada', 'jyada', 'more', 'lambi', 'lamba', 'lambe', 'longer', 'long', 'upar',
  };

  /// "choti"/"chota" are included here (unlike in the bare-qualitative
  /// duration check, which deliberately leaves them to the size extractor)
  /// because here they're only ever consulted right after a duration unit
  /// ("2 minute se choti") has already matched — no ambiguity with size.
  static const Set<String> durationSmallerWords = {
    'kam', 'shorter', 'short', 'niche', 'choti', 'chota',
  };

  /// Connector between a value and a direction word ("1 GB **se** badi").
  static const Set<String> directionConnector = {'se'};

  static const Set<String> todayWords = {'aaj', 'today'};
  static const Set<String> yesterdayWords = {'kal', 'yesterday'};
  static const Set<String> dayBeforeYesterdayWords = {'parso', 'parson'};
  static const Set<String> recentWords = {'recent', 'latest', 'recently'};

  /// Multi-word date phrases, checked as adjacent-token pairs.
  static const List<List<String>> lastWeekPhrases = [
    ['last', 'week'],
    ['pichle', 'hafte'],
    ['pichla', 'hafta'],
    ['pichle', 'hafta'],
  ];

  /// Spoken folder word -> canonical folder key matched via
  /// `folder_name_lower LIKE '%key%'`.
  static const Map<String, String> folderAliases = {
    'download': 'download',
    'downloads': 'download',
    'whatsapp': 'whatsapp',
    'camera': 'camera',
    'dcim': 'camera',
    'telegram': 'telegram',
    'movies': 'movie',
    'movie': 'movie',
    'screenshot': 'screenshot',
    'screenshots': 'screenshot',
    'recording': 'record',
    'recordings': 'record',
    'instagram': 'instagram',
    'snapchat': 'snapchat',
  };

  /// Filler / connector words stripped once every other extractor has run.
  /// Whatever tokens remain after this become the free-text filename search.
  static const Set<String> stopwords = {
    'dikhao', 'dikhana', 'dikha', 'dikhaiye', 'dikhaye', 'batao',
    'search', 'karo', 'karke', 'kar', 'khojo', 'khoj', 'find', 'show',
    'me', 'mein', 'ki', 'ke', 'ka', 'ko', 'wali', 'wala', 'wale',
    'video', 'videos', 'please', 'mujhe', 'mera', 'meri', 'mere', 'folder',
    'hai', 'do', 'all', 'sabhi', 'list', 'duration', 'time', 'se',
    'a', 'the', 'my', 'de',
    // "I want/need" — real device testing surfaced "Mujhe parson ki video
    // chahie" ("I want yesterday-before's video"): without these, "chahie"
    // leaked into the free-text filename filter and zeroed out otherwise
    // correct date-only results.
    'chahie', 'chahiye', 'chaiye', 'want', 'need', 'naam', 'name',
    // "Play/let me hear" — natural Hindi music phrasing ("gaane sunao",
    // "gaana bajao") rather than "dikhao"; without these the verb leaked
    // into the free-text filter for every music command.
    'sunao', 'suna', 'sunado', 'bajao', 'chalao', 'play',
  };
}
