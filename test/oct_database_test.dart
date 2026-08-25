import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:oct/data/db/oct_database.dart';
import 'package:oct/domain/entities/puzzle.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _sampleJson = '''
[
 {"id":"t1","fen":"6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1","moves":"a1a8","rating":1200,"themes":"mateIn1,endgame"},
 {"id":"t2","fen":"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1","moves":"e2e4","rating":900,"themes":"fork,opening"},
 {"id":"t3","fen":"4k3/8/8/8/8/8/8/4K2R w K - 0 1","moves":"h1h8","rating":1500,"themes":"mateIn1"}
]
''';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('OctDatabase', () {
    late OctDatabase db;

    setUp(() async {
      databaseFactory = databaseFactoryFfi;
      db = await OctDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactory,
      );
    });

    tearDown(() => db.close());

    test('seed gratuito popula e marca meta', () async {
      final puzzles =
          const PuzzleAssetSourceProbe().parse(_sampleJson);
      expect(puzzles.length, 3);

      await db.insertPuzzles(puzzles);
      await db.markFreeSeeded();

      expect(await db.isFreeSeeded(), isTrue);
      expect(await db.countByTier('free'), 3);
      expect(await db.countByTier('premium'), 0);
    });

    test('primary theme prioriza temas especificos', () async {
      final puzzles =
          const PuzzleAssetSourceProbe().parse(_sampleJson);
      expect(puzzles[0].primaryTheme, 'mateIn1');
      expect(puzzles[1].primaryTheme, 'fork');
    });

    test('pickPuzzle respeita tema e evita resolvidas', () async {
      final puzzles =
          const PuzzleAssetSourceProbe().parse(_sampleJson);
      await db.insertPuzzles(puzzles);

      final first = await db.pickPuzzle(theme: 'mateIn1');
      expect(first, isNotNull);
      await db.recordAttempt(first!.id, true);

      final second = await db.pickPuzzle(theme: 'mateIn1');
      expect(second, isNotNull);
      expect(second!.id, isNot(first.id));
      await db.recordAttempt(second.id, true);

      final exhausted = await db.pickPuzzle(theme: 'mateIn1');
      expect(exhausted, isNull);
    });

    test('progresso por tema calcula percentuais corretos', () async {
      final puzzles =
          const PuzzleAssetSourceProbe().parse(_sampleJson);
      await db.insertPuzzles(puzzles);

      await db.recordAttempt('t1', true);
      await db.recordAttempt('t2', true);
      await db.recordAttempt('t2', false);

      final overall = await db.overallProgress();
      expect(overall.total, 3);
      expect(overall.solved, 2);
      expect(overall.percent, closeTo(66.66, 0.01));

      final byTheme = await db.themeProgress();
      final mateIn1 =
          byTheme.firstWhere((t) => t.theme == 'mateIn1');
      expect(mateIn1.total, 2);
      expect(mateIn1.solved, 1);
      expect(mateIn1.percent, closeTo(50, 0.01));

      final fork = byTheme.firstWhere((t) => t.theme == 'fork');
      expect(fork.total, 1);
      expect(fork.solved, 1);
      expect(fork.percent, 100);

      expect(byTheme.any((t) => t.theme == 'opening'), isFalse,
          reason: 'opening nunca e primario quando fork esta presente');
      expect(byTheme.length, 2,
          reason: 'apenas fork e mateIn1 sao temas primarios');
    });

    test('bulk insert premium soma ao banco sem duplicar', () async {
      final puzzles =
          const PuzzleAssetSourceProbe().parse(_sampleJson);
      await db.insertPuzzles(puzzles);

      final premiumBatch = puzzles
          .take(1)
          .map((pz) => Puzzle(
                id: pz.id,
                fen: pz.fen,
                movesUci: pz.movesUci,
                rating: pz.rating,
                themes: pz.themes,
                primaryTheme: pz.primaryTheme,
                premium: true,
              ))
          .toList()
        ..add(const Puzzle(
          id: 'px1',
          fen: '8/8/8/8/8/8/8/K1k5 w - - 0 1',
          movesUci: ['a1b2'],
          rating: 2600,
          themes: ['endgame'],
          primaryTheme: 'endgame',
          premium: true,
        ));

      await db.insertPuzzles(premiumBatch);
      expect(await db.countByTier('free'), 3);
      expect(await db.countByTier('premium'), 1);
    });
  });
}

class PuzzleAssetSourceProbe {
  const PuzzleAssetSourceProbe();

  List<Puzzle> parse(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(Puzzle.fromJsonMap)
        .whereType<Puzzle>()
        .toList();
  }
}
