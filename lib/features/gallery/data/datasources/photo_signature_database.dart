import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/photo_signature.dart';

const _dbName = 'vidnexa_gallery.db';
const _table = 'photo_signature';

/// Raw sqflite access for the gallery's per-photo signatures.
///
/// Owns its own database file rather than adding a table to
/// `vidnexa_video_index.db`. The blueprint originally proposed sharing that
/// file so search could join metadata against signatures in one query — but
/// the grid reads MediaStore directly and never touches the index, and smart
/// search can intersect two indexed id sets in Dart just as cheaply. That left
/// only the cost: a shared version ladder, where every gallery schema change
/// bumps a number another feature owns, and one module reaching into the
/// other's connection. Separate files, no coupling.
///
/// Schema and SQL live here; the pixel maths lives in
/// `photo_signature_worker.dart`; the scan that drives both lives in
/// `PhotoSignatureService`. One job each, the same split
/// `features/voice_search` uses.
class PhotoSignatureDatabase {
  PhotoSignatureDatabase._();

  /// Single instance for the whole app.
  ///
  /// Both the background signature pass and the repository that reads the
  /// results need this table, and they run at the same time — the duplicate
  /// finder opens while a scan is still going. One connection keeps them
  /// reading the same state instead of racing two handles on one file.
  static final PhotoSignatureDatabase instance = PhotoSignatureDatabase._();

  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  static const _columns = '''
            source_id TEXT PRIMARY KEY,
            d_hash INTEGER NOT NULL,
            d_hash_bucket INTEGER NOT NULL,
            blur_score REAL NOT NULL,
            dominant_hue_bin INTEGER,
            hue_histogram TEXT NOT NULL,
            neutral_percent INTEGER NOT NULL,
            mean_luma INTEGER NOT NULL,
            width INTEGER NOT NULL,
            height INTEGER NOT NULL,
            file_size_bytes INTEGER,
            content_hash TEXT,
            source_modified_at INTEGER NOT NULL,
            signed_at INTEGER NOT NULL
  ''';

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 added file_size_bytes and content_hash, and fixed width/height
          // which v1 wrote from the thumbnail rather than the source photo.
          // Every existing row is therefore wrong or incomplete, and the pass
          // that would refresh them only re-signs photos whose modified time
          // changed — so drop and rebuild rather than migrate. Safe: v1 was
          // never released, and re-signing is incremental and resumable.
          await db.execute('DROP TABLE IF EXISTS $_table');
          await _createSchema(db);
        }
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('CREATE TABLE $_table ($_columns)');
    // Bucket drives the duplicate finder's candidate lookup, hue drives colour
    // search, blur and size drive the junk cleaner's buckets. Everything else
    // is read by primary key.
    await db.execute('CREATE INDEX idx_sig_bucket ON $_table(d_hash_bucket)');
    await db.execute('CREATE INDEX idx_sig_hue ON $_table(dominant_hue_bin)');
    await db.execute('CREATE INDEX idx_sig_blur ON $_table(blur_score)');
    await db.execute('CREATE INDEX idx_sig_size ON $_table(file_size_bytes)');
  }

  /// Caches SHA-256 results the duplicate finder computed, so a second run
  /// over the same candidates does not read those files again.
  Future<void> updateContentHashes(Map<String, String> hashes) async {
    if (hashes.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      hashes.forEach((sourceId, hash) {
        batch.update(
          _table,
          {'content_hash': hash},
          where: 'source_id = ?',
          whereArgs: [sourceId],
        );
      });
      await batch.commit(noResult: true);
    });
  }

  Future<void> upsertAll(List<PhotoSignature> signatures) async {
    if (signatures.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final signature in signatures) {
        batch.insert(
          _table,
          signature.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// Every signed photo's id mapped to the source modified time it was signed
  /// against.
  ///
  /// This is what makes the scan resumable and incremental: a photo already in
  /// this map with an unchanged modified time is skipped, so an interrupted
  /// pass picks up exactly where it stopped and a photo edited elsewhere is
  /// re-signed rather than keeping a stale hash.
  Future<Map<String, int>> signedFingerprints() async {
    final db = await _database;
    final rows = await db.query(
      _table,
      columns: ['source_id', 'source_modified_at'],
    );
    return {
      for (final row in rows)
        row['source_id'] as String: row['source_modified_at'] as int,
    };
  }

  Future<List<PhotoSignature>> allSignatures() async {
    final db = await _database;
    final rows = await db.query(_table);
    return rows.map(PhotoSignature.fromMap).toList();
  }

  /// Signatures whose bucket falls in [buckets] — the duplicate finder's
  /// candidate fetch, so it never loads the whole table to compare.
  Future<List<PhotoSignature>> byBuckets(Iterable<int> buckets) async {
    final list = buckets.toList();
    if (list.isEmpty) return const [];
    final db = await _database;
    final placeholders = List.filled(list.length, '?').join(',');
    final rows = await db.query(
      _table,
      where: 'd_hash_bucket IN ($placeholders)',
      whereArgs: list,
    );
    return rows.map(PhotoSignature.fromMap).toList();
  }

  Future<void> deleteByIds(Iterable<String> sourceIds) async {
    final list = sourceIds.toList();
    if (list.isEmpty) return;
    final db = await _database;
    final placeholders = List.filled(list.length, '?').join(',');
    await db.delete(
      _table,
      where: 'source_id IN ($placeholders)',
      whereArgs: list,
    );
  }

  Future<int> count() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
