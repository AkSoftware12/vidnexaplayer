import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/photo_signature.dart';

/// The gallery module's first background isolate, and the template for the
/// rest of them.
///
/// This file deliberately imports nothing from Flutter and nothing from
/// `photo_manager`. `photo_manager`'s platform channels only work on the root
/// isolate, so the split is fixed: the main isolate fetches thumbnail bytes
/// and hands them here, this runs the pixel maths on a worker, and the main
/// isolate writes the results. Keep that boundary — the moment a plugin import
/// appears in a worker file it will fail at runtime, not at compile time.
///
/// [computeSignatureBatch] is top-level because `compute()` requires an entry
/// point it can address by symbol.

/// One batch handed to the worker. Batched rather than one photo per call
/// because `compute` spawns a fresh isolate every time, and that setup cost
/// dwarfs the per-photo work.
class SignatureBatchRequest {
  const SignatureBatchRequest({
    required this.sourceIds,
    required this.thumbnails,
    required this.sourceModifiedAt,
    required this.fileSizeBytes,
    required this.width,
    required this.height,
  });

  final List<String> sourceIds;
  final List<Uint8List> thumbnails;
  final List<int> sourceModifiedAt;

  /// Passed through untouched — the worker does no pixel work with these, but
  /// carrying them here keeps one row assembled in one place instead of having
  /// the caller patch every result afterwards.
  final List<int?> fileSizeBytes;

  /// The **source photo's** dimensions, not the thumbnail's.
  ///
  /// These have to be supplied rather than read off the decoded image: what
  /// the worker receives is a 256px thumbnail, so `decoded.width` is 256 and
  /// says nothing about the original. The duplicate finder prefilters on
  /// dimensions and picks which copy to keep by resolution, both of which
  /// would be wrong with the thumbnail's numbers.
  final List<int> width;
  final List<int> height;
}

/// Decodes each thumbnail once and derives every signature field from it.
///
/// A photo whose bytes fail to decode is skipped rather than throwing: one
/// corrupt file must not abort a scan over thousands of good ones. It simply
/// stays unsigned and will be retried on the next pass.
List<PhotoSignature> computeSignatureBatch(SignatureBatchRequest request) {
  final signatures = <PhotoSignature>[];
  final signedAt = DateTime.now().millisecondsSinceEpoch;

  for (var i = 0; i < request.sourceIds.length; i++) {
    final decoded = img.decodeImage(request.thumbnails[i]);
    if (decoded == null) continue;

    final colors = _colorProfile(decoded);
    final hash = _differenceHash(decoded);

    signatures.add(
      PhotoSignature(
        sourceId: request.sourceIds[i],
        dHash: hash,
        bucket: _bucketOf(hash),
        blurScore: _blurScore(decoded),
        dominantHueBin: colors.dominantBin,
        hueHistogram: colors.histogram,
        neutralPercent: colors.neutralPercent,
        meanLuma: colors.meanLuma,
        width: request.width[i],
        height: request.height[i],
        fileSizeBytes: request.fileSizeBytes[i],
        sourceModifiedAt: request.sourceModifiedAt[i],
        signedAt: signedAt,
      ),
    );
  }

  return signatures;
}

/// Top 16 bits of the hash, used as a coarse bucket key.
///
/// Unsigned shift, so the sign bit does not produce a negative bucket.
int _bucketOf(int hash) => hash >>> 48;

/// 64-bit difference hash: resize to 9x8 greyscale, then record whether each
/// pixel is brighter than the one to its right. Robust to scaling, mild
/// compression and small brightness shifts, which is exactly what separates a
/// re-saved copy from a genuinely different photo.
int _differenceHash(img.Image source) {
  final small = img.copyResize(
    source,
    width: 9,
    height: 8,
    interpolation: img.Interpolation.average,
  );

  var hash = 0;
  var bit = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final left = small.getPixel(x, y).luminanceNormalized;
      final right = small.getPixel(x + 1, y).luminanceNormalized;
      if (left > right) hash |= 1 << bit;
      bit++;
    }
  }
  return hash;
}

/// Variance of the Laplacian over a 128x128 greyscale copy.
///
/// A sharp photo has strong second derivatives at its edges and therefore a
/// high variance; a blurred one has almost none. See [PhotoSignature.blurScore]
/// for why this is a relative score rather than an absolute threshold.
double _blurScore(img.Image source) {
  const size = 128;
  final small = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );

  final luma = Float64List(size * size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      luma[y * size + x] = small.getPixel(x, y).luminanceNormalized * 255.0;
    }
  }

  var sum = 0.0;
  var sumSquares = 0.0;
  var count = 0;

  // 4-neighbour Laplacian, skipping the border where the kernel would read
  // outside the image.
  for (var y = 1; y < size - 1; y++) {
    for (var x = 1; x < size - 1; x++) {
      final index = y * size + x;
      final value = luma[index - size] +
          luma[index + size] +
          luma[index - 1] +
          luma[index + 1] -
          4.0 * luma[index];
      sum += value;
      sumSquares += value * value;
      count++;
    }
  }

  if (count == 0) return 0;
  final mean = sum / count;
  final variance = (sumSquares / count) - (mean * mean);
  return variance < 0 ? 0 : variance;
}

class _ColorProfile {
  const _ColorProfile({
    required this.histogram,
    required this.dominantBin,
    required this.neutralPercent,
    required this.meanLuma,
  });

  final List<int> histogram;
  final int? dominantBin;
  final int neutralPercent;
  final int meanLuma;
}

/// Twelve 30° hue bins plus a neutral share and mean brightness.
///
/// Pixels that are too desaturated or too dark are counted as neutral instead
/// of being forced into a hue bin — without that, a black-and-white photo
/// lands in whatever bin its sensor noise happens to favour and turns up under
/// "red photos".
_ColorProfile _colorProfile(img.Image source) {
  const size = 64;
  final small = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.average,
  );

  final bins = List<int>.filled(12, 0);
  final maxChannel = small.maxChannelValue.toDouble();
  var neutral = 0;
  var lumaSum = 0.0;
  var total = 0;

  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final pixel = small.getPixel(x, y);
      final r = pixel.r / maxChannel;
      final g = pixel.g / maxChannel;
      final b = pixel.b / maxChannel;

      lumaSum += pixel.luminanceNormalized;
      total++;

      final maxValue = r > g ? (r > b ? r : b) : (g > b ? g : b);
      final minValue = r < g ? (r < b ? r : b) : (g < b ? g : b);
      final saturation = maxValue <= 0 ? 0.0 : (maxValue - minValue) / maxValue;

      if (saturation < 0.18 || maxValue < 0.12) {
        neutral++;
        continue;
      }

      final delta = maxValue - minValue;
      double hue;
      if (delta == 0) {
        hue = 0;
      } else if (maxValue == r) {
        hue = 60 * (((g - b) / delta) % 6);
      } else if (maxValue == g) {
        hue = 60 * (((b - r) / delta) + 2);
      } else {
        hue = 60 * (((r - g) / delta) + 4);
      }
      if (hue < 0) hue += 360;

      bins[(hue ~/ 30) % 12]++;
    }
  }

  if (total == 0) {
    return _ColorProfile(
      histogram: List<int>.filled(12, 0),
      dominantBin: null,
      neutralPercent: 100,
      meanLuma: 0,
    );
  }

  final histogram = bins
      .map((count) => (count * 100 / total).round())
      .toList(growable: false);

  // A bin only counts as dominant if it carries a real share of the frame.
  // Below that the photo reads as neutral and gets no hue at all, which keeps
  // "red photos" from returning every screenshot with a red notification dot.
  const dominantThresholdPercent = 12;
  var dominantBin = -1;
  var dominantShare = 0;
  for (var bin = 0; bin < histogram.length; bin++) {
    if (histogram[bin] > dominantShare) {
      dominantShare = histogram[bin];
      dominantBin = bin;
    }
  }

  return _ColorProfile(
    histogram: histogram,
    dominantBin:
        dominantShare >= dominantThresholdPercent && dominantBin >= 0
            ? dominantBin
            : null,
    neutralPercent: (neutral * 100 / total).round(),
    meanLuma: (lumaSum / total * 255).round().clamp(0, 255),
  );
}
