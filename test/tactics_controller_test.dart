import 'package:chess/chess.dart' as ch;
import 'package:flutter_test/flutter_test.dart';
import 'package:oct/domain/entities/puzzle.dart';
import 'package:oct/presentation/providers/session_provider.dart';
import 'package:oct/presentation/providers/tactics_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regressão do bug "tática não deixa mover": tryHumanMove usava
/// moves com `verbose: true` que retorna Maps (`make_pretty`) e acessava
/// `.fromAlgebraic` o que lançava erro engolido pelo framework.
/// O correto é moves com `asObjects: true`.
Puzzle _mateIn1() => const Puzzle(
      id: 'reg1',
      fen: '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
      movesUci: ['a1a8'],
      rating: 1200,
      themes: ['mateIn1'],
      primaryTheme: 'mateIn1',
    );

Future<TacticsController> _controller() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = SessionProvider(prefs);
  final c = TacticsController(session);
  c.currentPuzzle = _mateIn1();
  c.board = ch.Chess.fromFEN(_mateIn1().fen);
  c.solutionIndex = 0;
  return c;
}

void main() {
  group('TacticsController.tryHumanMove', () {
    test('lance correto da solução é aceito e completa', () async {
      final c = await _controller();
      expect(c.tryHumanMove('a1', 'a7', null), isFalse);
      expect(c.tryHumanMove('a1', 'a8', null), isTrue);
      expect(c.feedback, TacticFeedback.solved);
    });

    test('lance impossível é rejeitado sem exceção', () async {
      final c = await _controller();
      expect(c.tryHumanMove('a1', 'a6', null), isFalse);
    });

    test('roque e en passant da base passam no mesmo caminho', () async {
      final c = await _controller();
      c.currentPuzzle = const Puzzle(
        id: 'reg2',
        fen: 'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
        movesUci: ['e1g1'],
        rating: 1000,
        themes: ['castling'],
        primaryTheme: 'castling',
      );
      c.board = ch.Chess.fromFEN(c.currentPuzzle!.fen);
      c.solutionIndex = 0;
      expect(c.tryHumanMove('e1', 'g1', null), isTrue);
    });
  });
}
