/// Why an enhance could not produce an image.
///
/// Lives in the domain layer even though only the worker raises it: the worker
/// imports down into domain, the repository contract speaks in these terms,
/// and the UI maps each case to its own message. A single "it failed" would
/// leave the user with nothing to act on.
enum UpscaleFailure {
  /// The file could not be read — deleted, or on storage that went away.
  unreadable,

  /// Bytes were read but are not an image this decoder understands.
  undecodable,

  /// Source is beyond what fits in memory alongside its own output.
  tooLarge,

  /// Already at or above the target size. Enlarging further would only add
  /// softness, so it is refused rather than done badly.
  alreadyLarge,

  /// Rendered, but the gallery would not accept it.
  notSaved;

  String get messageKey => 'gallery_upscale_error_$name';
}
