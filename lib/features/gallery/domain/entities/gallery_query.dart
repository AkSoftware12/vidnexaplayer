/// Shape of a photo, derived from indexed width and height.
enum PhotoOrientation { portrait, landscape, square }

/// Where a photo came from, derived from its folder path.
enum PhotoSource {
  camera('camera'),
  screenshots('screenshot'),
  whatsapp('whatsapp'),
  telegram('telegram'),
  downloads('download');

  const PhotoSource(this.pathMarker);

  /// Lower-case substring matched against the photo's relative path.
  final String pathMarker;

  String get labelKey => 'gallery_source_$name';
}

/// Overall brightness, from the indexed mean luminance.
enum PhotoTone {
  dark,
  bright;

  String get labelKey => 'gallery_tone_$name';
}

/// A named colour, expanded to the hue bins that represent it.
///
/// Bins are 30° each, so most colours span two or three. Red wraps the origin,
/// which is why it is the one entry with non-contiguous bins.
enum PhotoColor {
  red({11, 0}),
  orange({0, 1}),
  yellow({1, 2}),
  green({3, 4}),
  cyan({5, 6}),
  blue({6, 7, 8}),
  purple({8, 9}),
  pink({10, 11});

  const PhotoColor(this.bins);

  final Set<int> bins;

  String get labelKey => 'gallery_color_$name';
}

/// A structured description of what the user is looking for.
///
/// Every field is an independent filter and callers combine as many as apply —
/// the same design as `VideoSearchQuery` in `features/voice_search`, whose
/// parser produces the shared facets here. The photo-only facets
/// ([orientation], [source], [tone], [color]) are what this adds.
///
/// This is facet search, not semantic search. It will find "red photos from
/// WhatsApp last month"; it will not find "photos of my dog".
class GalleryQuery {
  const GalleryQuery({
    this.text,
    this.folder,
    this.extension,
    this.fromDate,
    this.toDate,
    this.minSizeBytes,
    this.maxSizeBytes,
    this.orientation,
    this.sources = const {},
    this.tone,
    this.color,
  });

  static const empty = GalleryQuery();

  final String? text;
  final String? folder;
  final String? extension;
  final DateTime? fromDate;
  final DateTime? toDate;
  final int? minSizeBytes;
  final int? maxSizeBytes;
  final PhotoOrientation? orientation;

  /// Sources are OR-ed, not AND-ed.
  ///
  /// "whatsapp screenshots" names two places a photo could have come from, and
  /// on Android no photo is in both — screenshots live in Screenshots/,
  /// received pictures in WhatsApp Images/. Intersecting them can only ever
  /// return nothing, so multiple sources mean "from any of these".
  final Set<PhotoSource> sources;

  final PhotoTone? tone;
  final PhotoColor? color;

  bool get isEmpty =>
      text == null &&
      folder == null &&
      extension == null &&
      fromDate == null &&
      toDate == null &&
      minSizeBytes == null &&
      maxSizeBytes == null &&
      orientation == null &&
      sources.isEmpty &&
      tone == null &&
      color == null;

  /// True when answering this needs the signature index rather than just
  /// MediaStore metadata. Colour, tone and file size all live in the index.
  bool get needsSignatures =>
      color != null ||
      tone != null ||
      minSizeBytes != null ||
      maxSizeBytes != null;

  GalleryQuery copyWith({
    String? text,
    String? folder,
    String? extension,
    DateTime? fromDate,
    DateTime? toDate,
    int? minSizeBytes,
    int? maxSizeBytes,
    PhotoOrientation? orientation,
    Set<PhotoSource>? sources,
    PhotoTone? tone,
    PhotoColor? color,
  }) =>
      GalleryQuery(
        text: text ?? this.text,
        folder: folder ?? this.folder,
        extension: extension ?? this.extension,
        fromDate: fromDate ?? this.fromDate,
        toDate: toDate ?? this.toDate,
        minSizeBytes: minSizeBytes ?? this.minSizeBytes,
        maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
        orientation: orientation ?? this.orientation,
        sources: sources ?? this.sources,
        tone: tone ?? this.tone,
        color: color ?? this.color,
      );

  /// Removes one facet. Used by the chip row, where each facet has its own ✕.
  GalleryQuery without({
    bool text = false,
    bool folder = false,
    bool extension = false,
    bool dates = false,
    bool sizes = false,
    bool orientation = false,
    PhotoSource? source,
    bool tone = false,
    bool color = false,
  }) =>
      GalleryQuery(
        text: text ? null : this.text,
        folder: folder ? null : this.folder,
        extension: extension ? null : this.extension,
        fromDate: dates ? null : fromDate,
        toDate: dates ? null : toDate,
        minSizeBytes: sizes ? null : minSizeBytes,
        maxSizeBytes: sizes ? null : maxSizeBytes,
        orientation: orientation ? null : this.orientation,
        // Sources get their own chip each, so removal is per-source.
        sources: source == null
            ? sources
            : {...sources.where((item) => item != source)},
        tone: tone ? null : this.tone,
        color: color ? null : this.color,
      );
}
