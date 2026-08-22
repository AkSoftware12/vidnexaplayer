/// Which kind of local media a search targets.
///
/// Defaults to [video] everywhere — this feature started as video-only
/// search, and stays that way unless the spoken command explicitly names a
/// photo/image or an mp3/song, per the user's own framing: "agar mp3 bolta
/// hai to photo ya image [ya music] dikhao" (only switch kind when asked).
enum MediaKind {
  video,
  photo,
  music;

  /// Stored value in the `media_kind` DB column.
  String get storageKey => name;

  static MediaKind fromStorageKey(String? key) {
    switch (key) {
      case 'photo':
        return MediaKind.photo;
      case 'music':
        return MediaKind.music;
      default:
        return MediaKind.video;
    }
  }
}
