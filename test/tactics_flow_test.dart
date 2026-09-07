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
}
