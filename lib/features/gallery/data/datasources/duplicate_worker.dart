import 'dart:io';

import 'package:crypto/crypto.dart';

import '../models/photo_signature.dart';

/// Duplicate detection, off the main isolate.
///
/// Same rules as `photo_signature_worker.dart`: no Flutter, no `photo_manager`.
/// File paths are resolved on the root isolate and handed in; reading and
/// hashing those files happens here, because `dart:io` works on any isolate
/// while plugin channels do not.
///
/// Two top-level entry points, because the work happens in two stages with a
/// plugin call between them: group by perceptual hash, then confirm the exact
/// matches by content.

/// How many bits two hashes may differ by and still count as the same photo.
///
/// **This number is a starting point, not a fact.** It wants tuning against a
/// real burst-photo folder on a real device before release. Too tight and
/// re-saved copies slip through; too loose and it groups genuinely different
/// photos, which is the one failure in this feature that destroys user data.
const int kNearDuplicateDistance = 8;

/// Grouping request: every signature that has a usable hash.
class DuplicateScanRequest {
  const DuplicateScanRequest({
    required this.signatures,
    this.maxDistance = kNearDuplicateDistance,
  });

  final List<PhotoSignature> signatures;
  final int maxDistance;
}

/// One cluster of photos that look like the same picture.
class RawDuplicateCluster {
  const RawDuplicateCluster({required this.sourceIds, required this.exact});

  final List<String> sourceIds;

  /// True when every member shares byte size **and** dimensions **and** a
  /// distance-0 hash — the shape of a straight copy. Still unconfirmed at this
  /// stage; [verifyExactGroups] is what settles it.
  final bool exact;
}

/// Clusters photos whose perceptual hashes are within [maxDistance] bits.
///
/// Comparing every photo against every other is O(n²) and unusable past a few
/// thousand photos. Instead each photo is bucketed by the top 16 bits of its
/// hash and compared only within its own bucket and the buckets one bit away
/// from it. Two hashes within 8 bits can still land in different buckets, so
/// this trades a small number of missed far-apart pairs for a scan that
/// finishes — the alternative is a feature that hangs on a real library.
List<RawDuplicateCluster> groupDuplicates(DuplicateScanRequest request) {
  final byBucket = <int, List<PhotoSignature>>{};
  for (final signature in request.signatures) {
    byBucket.putIfAbsent(signature.bucket, () => []).add(signature);
  }

  final visited = <String>{};
  final clusters = <RawDuplicateCluster>[];

  for (final signature in request.signatures) {
    if (visited.contains(signature.sourceId)) continue;

    // Breadth-first over the similarity graph, so a chain of near-identical
    // burst shots ends up in one cluster rather than a string of pairs.
    final cluster = <PhotoSignature>[signature];
    visited.add(signature.sourceId);
    final queue = <PhotoSignature>[signature];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      for (final candidate in _candidatesFor(current, byBucket)) {
        if (visited.contains(candidate.sourceId)) continue;
        final distance = PhotoSignature.hammingDistance(
          current.dHash,
          candidate.dHash,
        );
        if (distance > request.maxDistance) continue;
        visited.add(candidate.sourceId);
        cluster.add(candidate);
        queue.add(candidate);
      }
    }

    if (cluster.length < 2) continue;

    clusters.add(
      RawDuplicateCluster(
        sourceIds: cluster.map((item) => item.sourceId).toList(),
        exact: _looksExact(cluster),
      ),
    );
  }

  return clusters;
}

/// The bucket a photo sits in, plus every bucket reachable by flipping one of
/// the 16 bucket bits.
Iterable<PhotoSignature> _candidatesFor(
  PhotoSignature signature,
  Map<int, List<PhotoSignature>> byBucket,
) sync* {
  yield* byBucket[signature.bucket] ?? const [];
  for (var bit = 0; bit < 16; bit++) {
    final neighbour = signature.bucket ^ (1 << bit);
    yield* byBucket[neighbour] ?? const [];
  }
}

/// Identical size, identical dimensions, identical hash — the fingerprint of a
/// straight file copy rather than a re-encode.
bool _looksExact(List<PhotoSignature> cluster) {
  final first = cluster.first;
  if (first.fileSizeBytes == null) return false;
  for (final other in cluster.skip(1)) {
    if (other.fileSizeBytes != first.fileSizeBytes) return false;
    if (other.width != first.width || other.height != first.height) return false;
    if (PhotoSignature.hammingDistance(first.dHash, other.dHash) != 0) {
      return false;
    }
  }
  return true;
}

/// Verification request: candidate paths, keyed by photo id.
class ExactVerifyRequest {
  const ExactVerifyRequest({required this.pathsBySourceId});

  final Map<String, String> pathsBySourceId;
}

/// SHA-256 of each candidate file, so "exact duplicate" means the bytes really
/// match rather than the thumbnails merely agreeing.
///
/// Only ever called for photos that already share size, dimensions and a
/// distance-0 hash. Hashing a whole library to answer that would read every
/// byte on the device; hashing a handful of candidates costs nothing.
///
/// A file that cannot be read is left out of the result rather than throwing —
/// the caller treats a missing hash as "not confirmed exact", which is the
/// safe direction to fail in.
Map<String, String> verifyExactGroups(ExactVerifyRequest request) {
  final hashes = <String, String>{};
  request.pathsBySourceId.forEach((sourceId, path) {
    try {
      final bytes = File(path).readAsBytesSync();
      hashes[sourceId] = sha256.convert(bytes).toString();
    } catch (_) {
      // Skipped deliberately — see above.
    }
  });
  return hashes;
}
