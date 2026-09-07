import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

import '../../domain/entities/puzzle.dart';

class OctDatabase {
  OctDatabase._(this._db);

  final sqflite.Database _db;

  static const String dbName = 'oct_puzzles.db';
  static const int dbVersion = 2;

  static OctDatabase? _instance;

  static Future<OctDatabase> open({
    String? path,
    sqflite.DatabaseFactory? factory,
  }) async {
    if (_instance != null) return _instance!;
    final f = factory ?? sqflite.databaseFactory;
    final dbPath =
        path ?? p.join(await sqflite.getDatabasesPath(), dbName);
    final db = await f.openDatabase(
      dbPath,
      options: sqflite.OpenDatabaseOptions(
        version: dbVersion,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (d, oldVersion, newVersion) async {
          // Base gratuita refeita (posições por tema + lances válidos):
          // limpa tudo para ressemear na próxima abertura.
          await d.execute('DELETE FROM puzzles');
          await d.execute('DELETE FROM puzzle_progress');
          await d.execute("DELETE FROM meta WHERE key = 'free_seeded'");
        },
        onCreate: (d, version) async {
        await d.execute('''
          CREATE TABLE puzzles (
            id TEXT PRIMARY KEY,
            fen TEXT NOT NULL,
            moves TEXT NOT NULL,
            rating INTEGER NOT NULL,
            themes TEXT NOT NULL,
            primary_theme TEXT NOT NULL,
            tier TEXT NOT NULL DEFAULT 'free'
          )
        ''');
        await d.execute(
            'CREATE INDEX idx_puzzles_theme ON puzzles(primary_theme)');
        await d.execute('CREATE INDEX idx_puzzles_tier ON puzzles(tier)');
        await d.execute('''
          CREATE TABLE puzzle_progress (
            puzzle_id TEXT PRIMARY KEY,
            attempts INTEGER NOT NULL DEFAULT 0,
            solved INTEGER NOT NULL DEFAULT 0,
            last_attempt_at INTEGER
          )
        ''');
        await d.execute('''
          CREATE TABLE meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        },
      ),
    );
    _instance = OctDatabase._(db);
    return _instance!;
  }

  Future<bool> isFreeSeeded() async {
    final rows = await _db.query('meta',
        where: 'key = ?', whereArgs: ['free_seeded'], limit: 1);
    return rows.isNotEmpty && rows.first['value'] == '1';
  }

  Future<void> markFreeSeeded() async {
    await _db.insert('meta', {'key': 'free_seeded', 'value': '1'});
  }

  Future<void> insertPuzzles(List<Puzzle> puzzles) async {
    if (puzzles.isEmpty) return;
    final batch = _db.batch();
    for (final pz in puzzles) {
      batch.insert('puzzles', pz.toRow(),
          conflictAlgorithm: sqflite.ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<int> countByTier(String tier) async {
    final r = await _db.rawQuery(
        'SELECT COUNT(*) c FROM puzzles WHERE tier = ?', [tier]);
    return (r.first['c'] as num).toInt();
  }

  Future<Puzzle?> pickPuzzle({
    required String theme,
    int? minRating,
    int? maxRating,
    List<String> excludeIds = const [],
  }) async {
    String where = 'primary_theme = ?';
    final args = <Object>[theme];
    if (minRating != null) {
      where += ' AND rating >= ?';
      args.add(minRating);
    }
    if (maxRating != null) {
      where += ' AND rating <= ?';
      args.add(maxRating);
    }
    if (excludeIds.isNotEmpty) {
      where +=
          ' AND p.id NOT IN (${List.filled(excludeIds.length, '?').join(',')})';
      args.addAll(excludeIds);
    }
    final rows = await _db.rawQuery('''
      SELECT p.* FROM puzzles p
      LEFT JOIN puzzle_progress pp ON pp.puzzle_id = p.id AND pp.solved = 1
      WHERE $where AND pp.puzzle_id IS NULL
      ORDER BY RANDOM() LIMIT 1
    ''', args);
    if (rows.isEmpty) return null;
    return Puzzle.fromRow(rows.first);
  }

  Future<void> recordAttempt(String puzzleId, bool solved) async {
    await _db.rawInsert('''
      INSERT INTO puzzle_progress (puzzle_id, attempts, solved, last_attempt_at)
      VALUES (?, 1, ?, ?)
      ON CONFLICT(puzzle_id) DO UPDATE SET
        attempts = attempts + 1,
        solved = MAX(solved, excluded.solved),
        last_attempt_at = excluded.last_attempt_at
    ''', [
      puzzleId,
      solved ? 1 : 0,
      DateTime.now().millisecondsSinceEpoch,
    ]);
  }

  Future<List<ThemeProgress>> themeProgress({String? tier}) async {
    String sql = '''
      SELECT p.primary_theme AS t,
             COUNT(*) AS total,
             SUM(CASE WHEN pp.solved = 1 THEN 1 ELSE 0 END) AS done
      FROM puzzles p
      LEFT JOIN puzzle_progress pp ON pp.puzzle_id = p.id
    ''';
    final args = <Object?>[];
    if (tier != null) {
      sql += ' WHERE p.tier = ?';
      args.add(tier);
    }
    sql += ' GROUP BY p.primary_theme ORDER BY t ASC';
    final rows = await _db.rawQuery(sql, args);
    return rows
        .map((r) => ThemeProgress(
              theme: r['t'] as String,
              total: (r['total'] as num?)?.toInt() ?? 0,
              solved: (r['done'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<ThemeProgress> overallProgress({String? tier}) async {
    String sql = '''
      SELECT COUNT(*) AS total,
             SUM(CASE WHEN pp.solved = 1 THEN 1 ELSE 0 END) AS done
      FROM puzzles p
      LEFT JOIN puzzle_progress pp ON pp.puzzle_id = p.id
    ''';
    final args = <Object?>[];
    if (tier != null) {
      sql += ' WHERE p.tier = ?';
      args.add(tier);
    }
    final r = await _db.rawQuery(sql, args);
    final row = r.first;
    return ThemeProgress(
      theme: 'ALL',
      total: (row['total'] as num?)?.toInt() ?? 0,
      solved: (row['done'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> close() async {
    await _db.close();
    _instance = null;
  }
}
