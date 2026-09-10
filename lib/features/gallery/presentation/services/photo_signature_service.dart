import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/datasources/gallery_asset_datasource.dart';
import '../../data/datasources/photo_signature_database.dart';
import '../../data/datasources/photo_signature_worker.dart';
import '../../data/models/photo_signature.dart';
import '../../domain/entities/photo_entity.dart';
import '../../domain/entities/signature_progress.dart';

/// App-level singleton that keeps `photo_signature` in step with the device's
/// photos.
///
/// Mirrors `VideoIndexService`'s role for voice search — fire-and-forget, never
/// throws, safe to call from `initState` — but exposes progress, because a
/// first pass over a large library takes long enough that the duplicate finder
/// and junk cleaner need to show what is happening rather than a bare spinner.
///
/// The pass is incremental and resumable by construction: it diffs the device
/// against what is already signed on every run, so an interrupted scan resumes
/// where it stopped and nothing is ever re-hashed without reason.
class PhotoSignatureService {
  PhotoSignatureService._();

  static final PhotoSignatureService instance = PhotoSignatureService._();

  /// Photos per isolate hop. `compute` spawns an isolate per call, so this
  /// trades that fixed cost against how long the main isolate waits between
  /// chances to render a frame.
  static const _batchSize = 64;

  /// Photos read from MediaStore per page while enumerating.
  static const _scanPageSize = 500;

  /// How many thumbnails to pull from the platform at once.
  ///
  /// Each one is a channel round-trip that spends nearly all its time on the
  /// platform's decoder thread, so issuing them one after another left the
  /// device mostly idle. Bounded rather than unbounded: every in-flight reply
  /// holds its bytes in memory, and the platform pool cannot serve more than
  /// a handful in parallel anyway.
  static const _thumbnailConcurrency = 8;

  /// Worker isolates decoding batches at the same time.
  ///
  /// The pixel work (`img.decodeImage` plus the hash/blur/colour passes) is
  /// pure CPU and was running one batch at a time on a single core. Capped at
  /// 4, and always leaves one core for the UI isolate.
  static final int _workerCount =
      Platform.numberOfProcessors <= 2 ? 1 : (Platform.numberOfProcessors - 1).clamp(1, 4);

  /// Its own datasource, not the one the open gallery screen uses. The scan
  /// wants [GalleryAssetDatasource.signatureBytes], which bypasses the grid's
  /// thumbnail cache on purpose, and a background job should not be reaching
  /// into a UI-scoped object's state.
  final GalleryAssetDatasource _assets = GalleryAssetDatasource();
  final PhotoSignatureDatabase _database = PhotoSignatureDatabase.instance;

  final ValueNotifier<SignatureProgress> progress =
      ValueNotifier<SignatureProgress>(SignatureProgress.idle);

  bool _running = false;
  bool get running => _running;

  Future<int> signedCount() => _database.count();

  Future<List<PhotoSignature>> allSignatures() => _database.allSignatures();

  Future<List<PhotoSignature>> signaturesInBuckets(Iterable<int> buckets) =>
      _database.byBuckets(buckets);

  /// Signs whatever is new or changed since the last pass.
  ///
  /// Never throws — a failure here must not take down whichever screen asked
  /// for it. Returns the number of photos actually signed this run.
  Future<int> ensureSignatures() async {
    if (_running) return 0;
    _running = true;
    progress.value = SignatureProgress.idle.copyWith(running: true);

    try {
      final permission = await _assets.ensurePermission();
      if (!permission.canRead) return 0;

      final known = await _database.signedFingerprints();
      final pending = <PhotoEntity>[];
      final seen = <String>{};

      // Enumerate the whole library page by page, collecting only what needs
      // work. Metadata pages are cheap; it is the thumbnail decode we are
      // trying to avoid repeating.
      var offset = 0;
      while (true) {
        final page = await _assets.loadPhotos(
          offset: offset,
          limit: _scanPageSize,
        );
        if (page.isEmpty) break;

        for (final photo in page) {
          seen.add(photo.id);
          final signedAgainst = known[photo.id];
          if (signedAgainst != photo.modifiedAt.millisecondsSinceEpoch) {
            pending.add(photo);
          }
        }

        offset += page.length;
        if (page.length < _scanPageSize) break;
      }

      // Photos that have left the device since the last pass. Guarded by
      // `seen` being non-empty: an enumeration that returned nothing is far
      // more likely to be a permission or plugin failure than a user who
      // deleted every photo they own, and acting on it would wipe the index.
      if (seen.isNotEmpty) {
        final stale = known.keys.where((id) => !seen.contains(id)).toList();
        await _database.deleteByIds(stale);
      }

      if (pending.isEmpty) return 0;

      progress.value = SignatureProgress(
        done: 0,
        total: pending.length,
        running: true,
      );

      var signed = 0;
      final startedAt = DateTime.now();

      // One MediaStore query for the whole library instead of a lookup per
      // photo. See GalleryAssetDatasource.allFileSizes for why asking per
      // photo was the pass's dominant cost.
      final fileSizes = await _assets.allFileSizes();

      // Fetching bytes is I/O on the platform side, decoding them is CPU on a
      // worker. Running them in lockstep left whichever side was idle doing
      // nothing, so the next group's thumbnails are pulled while the current
      // group is still being decoded.
      final groupSize = _batchSize * _workerCount;
      Future<List<SignatureBatchRequest>>? prefetch;

      for (var start = 0; start < pending.length; start += groupSize) {
        final end = (start + groupSize).clamp(0, pending.length);

        final requests = await (prefetch ??
            _buildRequests(pending.sublist(start, end), fileSizes));

        final nextStart = end;
        if (nextStart < pending.length) {
          final nextEnd = (nextStart + groupSize).clamp(0, pending.length);
          prefetch =
              _buildRequests(pending.sublist(nextStart, nextEnd), fileSizes);
        } else {
          prefetch = null;
        }

        if (requests.isNotEmpty) {
          // One `compute` per batch, all in flight together — that is what
          // puts more than one core on the decode.
          final results = await Future.wait(
            requests.map((request) => compute(computeSignatureBatch, request)),
          );
          for (final signatures in results) {
            await _database.upsertAll(signatures);
            signed += signatures.length;
          }
        }

        progress.value = progress.value.copyWith(done: end);
      }

      if (kDebugMode) {
        final ms = DateTime.now().difference(startedAt).inMilliseconds;
        debugPrint(
          '🖼️ signature scan: $signed photos in ${ms}ms '
          '(${(ms / (signed == 0 ? 1 : signed)).toStringAsFixed(1)}ms each, '
          '$_workerCount workers)',
        );
      }

      return signed;
    } catch (error, stackTrace) {
      debugPrint('PhotoSignatureService.ensureSignatures failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 0;
    } finally {
      _running = false;
      progress.value = progress.value.copyWith(running: false);
    }
  }

  /// Drops every signature and signs the library from scratch. For a "rescan"
  /// action, or after the thresholds these scores feed are retuned.
  Future<int> rebuild() async {
    if (_running) return 0;
    final known = await _database.signedFingerprints();
    await _database.deleteByIds(known.keys);
    return ensureSignatures();
  }

  /// Fetches thumbnail bytes on the main isolate — `photo_manager`'s channels
  /// only work here — and packs one [SignatureBatchRequest] per worker batch.
  ///
  /// Photos whose bytes cannot be read are dropped rather than failing the
  /// group. They stay unsigned and are retried next pass.
  Future<List<SignatureBatchRequest>> _buildRequests(
    List<PhotoEntity> group,
    Map<String, int> fileSizes,
  ) async {
    final loaded = await _loadThumbnails(group, fileSizes);

    final requests = <SignatureBatchRequest>[];
    for (var start = 0; start < loaded.length; start += _batchSize) {
      final end = (start + _batchSize).clamp(0, loaded.length);
      final batch = loaded.sublist(start, end);
      if (batch.isEmpty) continue;

      requests.add(
        SignatureBatchRequest(
          sourceIds: [for (final item in batch) item.photo.id],
          thumbnails: [for (final item in batch) item.bytes],
          sourceModifiedAt: [
            for (final item in batch) item.photo.modifiedAt.millisecondsSinceEpoch,
          ],
          fileSizeBytes: [for (final item in batch) item.sizeBytes],
          // The source photo's own dimensions — the worker only ever sees a
          // 256px thumbnail and cannot recover these.
          width: [for (final item in batch) item.photo.width],
          height: [for (final item in batch) item.photo.height],
        ),
      );
    }
    return requests;
  }

  /// Reads thumbnail bytes for [group], [_thumbnailConcurrency] photos at a
  /// time, pairing each with its size from the prefetched [fileSizes] map.
  ///
  /// This loop used to be strictly sequential — and each turn also awaited a
  /// size lookup that copied the photo to disk. That is why a large library
  /// took minutes: the device spent most of it either idle between replies or
  /// copying files it never read.
  Future<List<_LoadedThumbnail>> _loadThumbnails(
    List<PhotoEntity> group,
    Map<String, int> fileSizes,
  ) async {
    final loaded = <_LoadedThumbnail>[];

    for (var start = 0; start < group.length; start += _thumbnailConcurrency) {
      final end = (start + _thumbnailConcurrency).clamp(0, group.length);
      final slice = group.sublist(start, end);

      final results = await Future.wait(
        slice.map((photo) async {
          // Per photo, not per slice: one unreadable asset must not drop the
          // seven good ones fetched alongside it. It also keeps the prefetched
          // future from ever completing with an error — that one is not
          // awaited until the next turn of the loop, so a throw there would
          // surface as an unhandled async error instead of being caught.
          try {
            final bytes = await _assets.signatureBytes(photo.id);
            if (bytes == null) return null;
            return _LoadedThumbnail(
              photo: photo,
              bytes: bytes,
              sizeBytes: fileSizes[photo.id],
            );
          } catch (_) {
            return null;
          }
        }),
      );

      for (final result in results) {
        if (result != null) loaded.add(result);
      }
    }

    return loaded;
  }
}

/// One photo's bytes and size, held only long enough to be packed into a
/// [SignatureBatchRequest].
class _LoadedThumbnail {
  const _LoadedThumbnail({
    required this.photo,
    required this.bytes,
    required this.sizeBytes,
  });

  final PhotoEntity photo;
  final Uint8List bytes;
  final int? sizeBytes;
}
