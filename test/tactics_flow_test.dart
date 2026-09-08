import 'package:flutter_test/flutter_test.dart';
import 'package:oct/data/db/oct_database.dart';
import 'package:oct/domain/entities/puzzle.dart';
import 'package:oct/presentation/providers/session_provider.dart';
import 'package:oct/presentation/providers/tactics_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// O botão PRÓXIMA (skip) deve sempre avançar: nunca repete o exercício
/// atual em seguida, mesmo pulando várias vezes seguidas.
List<Puzzle> _seedFork(int n) => List.generate(
      n,
      (i) => Puzzle(
        id: 'flow_$i',
        fen: '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
        movesUci: const ['a1a8'],
        rating: 1000 + i,
        themes: const ['fork'],
        primaryTheme: 'fork',
      ),
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('fluxo PRÓXIMA nas táticas', () {
    test('10 pulos seguidos nunca repetem o atual', () async {
      databaseFactory = databaseFactoryFfi;
      final db = await OctDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactory,
      );
      await db.insertPuzzles(_seedFork(6));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = SessionProvider(prefs);
      session.setDbForTesting(db);
      final c = TacticsController(session);

      expect(await c.openTheme('fork'), isTrue);
      for (var i = 0; i < 10; i++) {
        final prev = c.currentPuzzle!.id;
        await c.skipPuzzle();
        expect(c.currentPuzzle, isNotNull);
        expect(c.currentPuzzle!.id, isNot(equals(prev)),
            reason: 'PRÓXIMA repetiu o exercício $prev');
      }
      await db.close();
    });
  });

  group('lado do solver (1º lance é do oponente)', () {
    test('oponente toca sozinho e o solver resolve', () async {
      databaseFactory = databaseFactoryFfi;
      final db = await OctDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactory,
      );
      await db.insertPuzzles([
        const Puzzle(
          id: 'flip_1',
          fen:
              'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          movesUci: ['e7e5', 'g1f3'],
          rating: 1000,
          themes: ['fork'],
          primaryTheme: 'fork',
        ),
      ]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = SessionProvider(prefs);
      session.setDbForTesting(db);
      final c = TacticsController(session);

      expect(await c.openTheme('fork'), isTrue);
      expect(c.waitingOpening, isTrue);
      expect(c.solverSide, 'w');
      // Entrada bloqueada enquanto o oponente não tocou.
      expect(c.tryHumanMove('g1', 'f3', null), isFalse);

      await Future.delayed(const Duration(milliseconds: 850));
      expect(c.waitingOpening, isFalse);
      expect(c.solutionIndex, 1);
      expect(c.board.get('e5'), isNotNull);

      expect(c.tryHumanMove('g1', 'f3', null), isTrue);
      expect(c.feedback, TacticFeedback.solved);
      await db.close();
    });
  });

  group('percentual por tema', () {
    test('2 de 6 resolvidas = 33.33333%', () async {
      databaseFactory = databaseFactoryFfi;
      final db = await OctDatabase.open(
        path: inMemoryDatabasePath,
        factory: databaseFactory,
      );
      await db.insertPuzzles(List.generate(
        6,
        (i) => Puzzle(
          id: 'pct_$i',
          fen: '6k1/6pp/8/8/8/8/8/R5K1 b - - 0 1',
          movesUci: const ['g7g6', 'a1a8'],
          rating: 1000 + i,
          themes: const ['fork'],
          primaryTheme: 'fork',
        ),
      ));

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final session = SessionProvider(prefs);
      session.setDbForTesting(db);
      final c = TacticsController(session);

      expect(await c.openTheme('fork'), isTrue);
      for (var solved = 0; solved < 2; solved++) {
        await Future.delayed(const Duration(milliseconds: 850));
        expect(c.waitingOpening, isFalse);
        final mv = c.currentPuzzle!.movesUci[1];
        expect(
            c.tryHumanMove(
                mv.substring(0, 2), mv.substring(2, 4), null),
            isTrue);
        expect(c.feedback, TacticFeedback.solved);
        await c.skipPuzzle();
      }

      await c.refreshProgress();
      final fork = c.themeProgressList
          .firstWhere((tp) => tp.theme == 'fork');
      expect(fork.total, 6);
      expect(fork.solved, 2);
      expect(fork.percent, closeTo(33.33333, 0.0001));
      expect(c.overall.percent, closeTo(33.33333, 0.0001));
      await db.close();
    });
  });
}
