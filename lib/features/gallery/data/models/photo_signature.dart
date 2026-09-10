/// Everything the gallery derives from a photo's pixels, computed once and
/// cached in `vidnexa_gallery.db`.
///
/// One row per photo. The duplicate finder reads [dHash] and [bucket], the
/// junk cleaner reads [blurScore], and smart search reads [dominantHueBin] and
/// [meanLuma] — all from this single pass, which is why the scan is worth
/// doing once rather than three times.
///
/// Plain fields with no Flutter or plugin imports: instances are sent across
/// an isolate boundary, so everything here must be transferable.
class PhotoSignature {
  /// `AssetEntity.id` of the photo this describes.
  final String sourceId;

  /// 64-bit difference hash. Stored as a signed int because that is what both
  /// Dart and SQLite give you — the sign bit is just bit 63, and Hamming
  /// distance over the raw bit pattern is unaffected.
  final int dHash;

  /// Top 16 bits of [dHash], indexed so the duplicate finder can compare
  /// within a bucket instead of every photo against every other photo.
  final int bucket;

  /// Variance of the Laplacian. Low means little high-frequency detail, which
  /// usually means blur.
  ///
  /// Computed from a 256px thumbnail, not the original — decoding thousands of
  /// full-size photos is exactly what this index exists to avoid. Downscaling
  /// discards high frequencies itself, so treat this as a score for *ranking*
  /// photos against each other, never as an absolute "blurry below N".
  final double blurScore;

  /// Dominant hue bin (0–11, each 30°), or null when the photo is mostly
  /// neutral — greys, black-and-white, documents and screenshots of text.
  final int? dominantHueBin;

  /// Share of pixels in each of the 12 hue bins, as percentages of all pixels.
  /// Kept alongside [dominantHueBin] so search can score "mostly red" above
  /// "slightly red" rather than treating the dominant bin as binary.
  final List<int> hueHistogram;

  /// Percentage of pixels too desaturated or too dark to carry a hue.
  final int neutralPercent;

  /// Mean luminance, 0–255. Backs "dark photos" without a second pass.
  final int meanLuma;

  final int width;
  final int height;

  /// Size on disk. Collected during the signature pass because both tools that
  /// read this table need it — the duplicate finder to prefilter exact matches
  /// and report reclaimable space, the junk cleaner to size every bucket — and
  /// stat-ing thousands of files on demand is exactly the cost this index
  /// exists to pay once.
  final int? fileSizeBytes;

  /// SHA-256 of the file's bytes, or null until something needed it.
  ///
  /// Filled in lazily by the duplicate finder, and only for photos that
  /// already look identical by size, dimensions and hash. Hashing a whole
  /// library up front would read every byte on the device for a question that
  /// only ever gets asked about a handful of candidates.
  final String? contentHash;

  /// The source asset's modified time. The scan diffs on this, so a photo
  /// edited in another app is re-signed instead of keeping a stale hash.
  final int sourceModifiedAt;

  final int signedAt;

  const PhotoSignature({
    required this.sourceId,
    required this.dHash,
    required this.bucket,
    required this.blurScore,
    required this.dominantHueBin,
    required this.hueHistogram,
    required this.neutralPercent,
    required this.meanLuma,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    this.contentHash,
    required this.sourceModifiedAt,
    required this.signedAt,
  });

  PhotoSignature copyWith({String? contentHash}) => PhotoSignature(
        sourceId: sourceId,
        dHash: dHash,
        bucket: bucket,
        blurScore: blurScore,
        dominantHueBin: dominantHueBin,
        hueHistogram: hueHistogram,
        neutralPercent: neutralPercent,
        meanLuma: meanLuma,
        width: width,
        height: height,
        fileSizeBytes: fileSizeBytes,
        contentHash: contentHash ?? this.contentHash,
        sourceModifiedAt: sourceModifiedAt,
        signedAt: signedAt,
      );

  Map<String, Object?> toMap() => {
        'source_id': sourceId,
        'd_hash': dHash,
        'd_hash_bucket': bucket,
        'blur_score': blurScore,
        'dominant_hue_bin': dominantHueBin,
        'hue_histogram': hueHistogram.join(','),
        'neutral_percent': neutralPercent,
        'mean_luma': meanLuma,
        'width': width,
        'height': height,
        'file_size_bytes': fileSizeBytes,
        'content_hash': contentHash,
        'source_modified_at': sourceModifiedAt,
        'signed_at': signedAt,
      };

  factory PhotoSignature.fromMap(Map<String, Object?> map) => PhotoSignature(
        sourceId: map['source_id'] as String,
        dHash: map['d_hash'] as int,
        bucket: map['d_hash_bucket'] as int,
        blurScore: (map['blur_score'] as num).toDouble(),
        dominantHueBin: map['dominant_hue_bin'] as int?,
        hueHistogram: _parseHistogram(map['hue_histogram'] as String?),
        neutralPercent: map['neutral_percent'] as int,
        meanLuma: map['mean_luma'] as int,
        width: map['width'] as int,
        height: map['height'] as int,
        fileSizeBytes: map['file_size_bytes'] as int?,
        contentHash: map['content_hash'] as String?,
        sourceModifiedAt: map['source_modified_at'] as int,
        signedAt: map['signed_at'] as int,
      );

  static List<int> _parseHistogram(String? raw) {
    if (raw == null || raw.isEmpty) return List<int>.filled(12, 0);
    final parts = raw.split(',');
    if (parts.length != 12) return List<int>.filled(12, 0);
    return parts.map((part) => int.tryParse(part) ?? 0).toList(growable: false);
  }

  /// Number of differing bits between two hashes — the duplicate finder's
  /// similarity measure. 0 means the thumbnails are identical; small values
  /// mean burst shots, re-saves, or messenger recompressions.
  static int hammingDistance(int a, int b) {
    var diff = a ^ b;
    var count = 0;
    // Iterating set bits (Kernighan) rather than all 64 — near-duplicates
    // differ in only a handful of bits, which is the case that runs most.
    while (diff != 0) {
      diff &= diff - 1;
      count++;
    }
    return count;
  }
}
