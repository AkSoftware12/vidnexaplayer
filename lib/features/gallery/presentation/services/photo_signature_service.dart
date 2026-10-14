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

  /// The same two limits for a background pass — one the app started on its
  /// own while the user is scrolling the grid. The grid's thumbnails come out
  /// of the same platform decoder pool, and a full-speed pass starved them.
  /// See [_foreground].
  static const _backgroundThumbnailConcurrency = 3;
  static const _backgroundWorkerCount = 1;

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

  /// The pass in progress, if any. Every caller during a pass gets this same
  /// future — it used to get an immediate 0 instead, so a tool opened while a
  /// scan was running went on to analyse a half-built index as if complete.
  Future<int>? _current;
  bool get running => _current != null;

  /// Whether the running pass goes at full speed. A background pass starts
  /// slow; the moment anything the user is waiting on asks for the index, it
  /// is raised for the rest of the run. Read per group, so it takes effect
  /// mid-pass.
  bool _foreground = false;

  int get _activeWorkers => _foreground ? _workerCount : _backgroundWorkerCount;
  int get _activeThumbnailConcurrency =>
      _foreground ? _thumbnailConcurrency : _backgroundThumbnailConcurrency;

  Future<int> signedCount() => _database.count();

  Future<List<PhotoSignature>> allSignatures() => _database.allSignatures();

  Future<List<PhotoSignature>> signaturesInBuckets(Iterable<int> buckets) =>
      _database.byBuckets(buckets);

  /// Signs whatever is new or changed since the last pass.
  ///
  /// Never throws — a failure here must not take down whichever screen asked
  /// for it. Returns the number of photos actually signed this run. If a pass
  /// is already running, returns that pass's result once it finishes.
  ///
  /// [background] is for passes the app starts on its own (see
  /// `GalleryController`): they run at reduced speed so scrolling stays
  /// smooth. Callers must only use it once read permission is granted, so it
  /// never puts up a permission prompt nobody asked for.
  Future<int> ensureSignatures({bool background = false}) {
    if (!background) _foreground = true;
    final current = _current;
    if (current != null) return current;

    _foreground = !background;
    return _current = _run();
  }

  Future<int> _run() async {
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
      //
      // One group = one batch per worker. The group size is re-read each turn
      // because a background pass can be raised to full speed mid-run.
      Future<List<SignatureBatchRequest>>? prefetch;
      var prefetchEnd = 0;
      var start = 0;

      while (start < pending.length) {
        final end = prefetch != null
            ? prefetchEnd
            : (start + _batchSize * _activeWorkers).clamp(0, pending.length);

        final requests = await (prefetch ??
            _buildRequests(pending.sublist(start, end), fileSizes));

        if (end < pending.length) {
          prefetchEnd =
              (end + _batchSize * _activeWorkers).clamp(0, pending.length);
          prefetch =
              _buildRequests(pending.sublist(end, prefetchEnd), fileSizes);
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
        start = end;
      }

      if (kDebugMode) {
        final ms = DateTime.now().difference(startedAt).inMilliseconds;
        debugPrint(
          '🖼️ signature scan: $signed photos in ${ms}ms '
          '(${(ms / (signed == 0 ? 1 : signed)).toStringAsFixed(1)}ms each, '
          '$_activeWorkers workers at the end)',
        );
      }

      return signed;
    } catch (error, stackTrace) {
      debugPrint('PhotoSignatureService.ensureSignatures failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 0;
    } finally {
      // Cleared before the notifier fires, so a listener reacting to
      // "finished" already sees `running` as false.
      _current = null;
      _foreground = false;
      progress.value = progress.value.copyWith(running: false);
    }
  }

  /// Drops every signature and signs the library from scratch. For a "rescan"
  /// action, or after the thresholds these scores feed are retuned.
  Future<int> rebuild() async {
    if (running) return 0;
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

  /// Reads thumbnail bytes for [group], a few photos at a time (fewer during
  /// a background pass), pairing each with its size from the prefetched
  /// [fileSizes] map.
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
    final concurrency = _activeThumbnailConcurrency;

    for (var start = 0; start < group.length; start += concurrency) {
      final end = (start + concurrency).clamp(0, group.length);
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
