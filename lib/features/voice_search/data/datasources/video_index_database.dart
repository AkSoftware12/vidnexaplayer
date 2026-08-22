import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/media_kind.dart';
import '../../domain/entities/video_search_query.dart';
import '../models/video_index_entry.dart';

const _dbName = 'vidnexa_video_index.db';
const _table = 'video_index';

/// Raw sqflite access for the local media index (video/photo/music).
///
/// Owns the schema and every hand-written SQL statement. Kept separate from
/// the scanner datasources (which talk to `photo_manager` /
/// `on_audio_query_forked`) and from the repository (which just coordinates
/// them) so each has one job.
class VideoIndexDatabase {
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  static const _columns = '''
            id TEXT PRIMARY KEY,
            source_id TEXT NOT NULL,
            media_kind TEXT NOT NULL DEFAULT 'video',
            file_name TEXT NOT NULL,
            file_name_lower TEXT NOT NULL,
            file_path TEXT,
            folder_name TEXT,
            folder_name_lower TEXT,
            folder_path TEXT,
            file_size_bytes INTEGER,
            duration_ms INTEGER,
            created_at INTEGER,
            modified_at INTEGER,
            mime_type TEXT,
            extension TEXT,
            width INTEGER,
            height INTEGER,
            indexed_at INTEGER NOT NULL
  ''';

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_video_folder ON $_table(folder_name_lower)');
    await db.execute('CREATE INDEX idx_video_ext ON $_table(extension)');
    await db.execute('CREATE INDEX idx_video_created ON $_table(created_at)');
    await db.execute('CREATE INDEX idx_video_size ON $_table(file_size_bytes)');
    await db.execute('CREATE INDEX idx_video_duration ON $_table(duration_ms)');
    await db.execute('CREATE INDEX idx_video_name ON $_table(file_name_lower)');
    await db.execute('CREATE INDEX idx_video_kind ON $_table(media_kind)');
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE $_table ($_columns)');
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v1 only ever indexed videos, with the bare video id as the
          // primary key. v2 adds photo/music support, which needs `id` to
          // be a "<kind>:<sourceId>" composite (video/photo/music ids come
          // from independent MediaStore sequences and can collide
          // numerically) — existing rows keep their old bare `id` as the PK
          // (harmless: search/playback both key off `source_id`+`media_kind`
          // now, not the PK format) and self-heal to the composite format
          // the next time a full rescan diffs and re-upserts them.
          await db.execute("ALTER TABLE $_table ADD COLUMN source_id TEXT");
          await db.execute(
            "ALTER TABLE $_table ADD COLUMN media_kind TEXT NOT NULL DEFAULT 'video'",
          );
          await db.execute('UPDATE $_table SET source_id = id WHERE source_id IS NULL');
          await db.execute('CREATE INDEX idx_video_kind ON $_table(media_kind)');
        }
      },
    );
  }

  Future<void> upsertAll(List<VideoIndexEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await _database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final entry in entries) {
        batch.insert(
          _table,
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  /// All ids currently stored, optionally restricted to one [kind] — used to
  /// diff a fresh scan against what's already indexed. Restricting by kind
  /// matters: a scan diff must never treat another kind's untouched rows as
  /// "no longer seen, delete them".
  Future<Set<String>> allIds({MediaKind? kind}) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      columns: ['id'],
      where: kind == null ? null : 'media_kind = ?',
      whereArgs: kind == null ? null : [kind.storageKey],
    );
    return rows.map((r) => r['id'] as String).toSet();
  }

  Future<void> deleteByIds(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _database;
    final idList = ids.toList();
    final placeholders = List.filled(idList.length, '?').join(',');
    await db.delete(
      _table,
      where: 'id IN ($placeholders)',
      whereArgs: idList,
    );
  }

  Future<int> count() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<VideoIndexEntry?> findById(MediaKind kind, String sourceId) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'id = ?',
      whereArgs: [VideoIndexEntry.compositeId(kind, sourceId)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VideoIndexEntry.fromMap(rows.first);
  }

  Future<List<VideoIndexEntry>> search(
    VideoSearchQuery query, {
    int offset = 0,
    int limit = 40,
  }) async {
    final db = await _database;
    final where = <String>['media_kind = ?'];
    final args = <Object?>[query.mediaKind.storageKey];

    if (query.folder != null) {
      where.add('folder_name_lower LIKE ?');
      args.add('%${query.folder}%');
    }
    if (query.extension != null) {
      where.add('extension = ?');
      args.add(query.extension);
    }
    if (query.minSizeBytes != null) {
      where.add('file_size_bytes >= ?');
      args.add(query.minSizeBytes);
    }
    if (query.maxSizeBytes != null) {
      where.add('file_size_bytes <= ?');
      args.add(query.maxSizeBytes);
    }
    if (query.minDuration != null) {
      where.add('duration_ms >= ?');
      args.add(query.minDuration!.inMilliseconds);
    }
    if (query.maxDuration != null) {
      where.add('duration_ms <= ?');
      args.add(query.maxDuration!.inMilliseconds);
    }
    if (query.fromDate != null) {
      where.add('created_at >= ?');
      args.add(query.fromDate!.millisecondsSinceEpoch);
    }
    if (query.toDate != null) {
      where.add('created_at <= ?');
      args.add(query.toDate!.millisecondsSinceEpoch);
    }

    String? textLower;
    final text = query.text?.trim();
    if (text != null && text.isNotEmpty) {
      textLower = text.toLowerCase();

      // Match each remaining word independently (AND-combined) rather than
      // requiring the whole spoken phrase as one contiguous substring.
      // Real speech rarely comes back in exactly filename order/spacing —
      // "Sippy Gill video dikhao" only left "sippy gill" as a contiguous
      // phrase by luck; "video mein Sippy aur Gill" would leave "sippy aur
      // gill" and miss a filename containing "sippy" and "gill" with
      // nothing in between. Per-word matching finds it either way.
      final words = textLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      for (final word in words) {
        where.add('file_name_lower LIKE ?');
        args.add('%$word%');
      }
    }

    // Ranking: exact filename match > prefix match > folder match > rest.
    // ORDER BY can't be parameter-bound via `Database.query`, so this uses
    // `rawQuery` with the CASE args placed right after the WHERE args, in
    // the same left-to-right order they appear in the SQL text.
    final orderArgs = <Object?>[];
    final String orderBy;
    if (textLower != null) {
      orderBy = 'CASE '
          'WHEN file_name_lower = ? THEN 0 '
          'WHEN file_name_lower LIKE ? THEN 1 '
          'WHEN folder_name_lower LIKE ? THEN 2 '
          'ELSE 3 END, created_at DESC';
      orderArgs.addAll([textLower, '$textLower%', '%$textLower%']);
    } else {
      orderBy = 'created_at DESC';
    }

    final sql = StringBuffer('SELECT * FROM $_table');
    sql.write(' WHERE ${where.join(' AND ')}');
    sql.write(' ORDER BY $orderBy');
    sql.write(' LIMIT ? OFFSET ?');

    final rows = await db.rawQuery(sql.toString(), [
      ...args,
      ...orderArgs,
      limit,
      offset,
    ]);

    return rows.map(VideoIndexEntry.fromMap).toList();
  }
}
