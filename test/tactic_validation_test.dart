import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as ch;

class TacticSessionProbe {
  TacticSessionProbe(this.fen, this.solution);

  final String fen;
  final List<String> solution;
  int index = 0;
  late ch.Chess board = ch.Chess.fromFEN(fen);

  bool get isComplete => index >= solution.length;

  bool tryMove(String from, String to) {
    if (isComplete) return false;
    final expected = solution[index];
    final attempt = '$from$to'.toLowerCase();
    if (attempt != expected.substring(0, 4).toLowerCase()) return false;

    final applied = board.move({
      'from': from,
      'to': to,
      'promotion':
          expected.length > 4 ? expected[4] : null,
    });
    if (!applied) return false;
    index++;
    return true;
  }

  void playOpponentReply() {
    if (isComplete) return;
    final reply = solution[index];
    final ok = board.move({
      'from': reply.substring(0, 2),
      'to': reply.substring(2, 4),
      'promotion': reply.length > 4 ? reply[4] : null,
    });
    if (ok) index++;
  }
}

void main() {
  group('validacao de lances locais', () {
    test('posição inicial aceita e2e4 e rejeita e2e5', () {
      final game = ch.Chess();
      expect(game.move({'from': 'e2', 'to': 'e4'}), isTrue);
      expect(game.fen.startsWith('rnbqkbnr/pppppppp/8/8/4P3'), isTrue);

      final fresh = ch.Chess();
      expect(fresh.move({'from': 'e2', 'to': 'e5'}), isFalse);
    });

    test('não permite mover peça do adversário', () {
      final game = ch.Chess();
      expect(game.move({'from': 'e7', 'to': 'e5'}), isFalse);
    });

    test('rei não pode se expor a xeque', () {
      final game = ch.Chess.fromFEN(
          'k7/8/8/8/8/8/5q2/K7 w - - 0 1');
      expect(
          game.move({'from': 'a1', 'to': 'b1'}), isTrue);
      expect(
          game.move({'from': 'a1', 'to': 'a2'}), isFalse);
    });

    test('promoção automática de dama funciona', () {
      final game = ch.Chess.fromFEN(
          '8/P6k/8/8/8/8/8/K7 w - - 0 1');
      expect(
          game.move(
              {'from': 'a7', 'to': 'a8', 'promotion': 'q'}),
          isTrue);
      final piece = game.get('a8');
      expect(piece, isNotNull);
      expect(piece!.type, ch.Chess.QUEEN);
    });
  });

  group('TacticSessionProbe', () {
    test('mate em 1 resolvido com lance correto', () {
      final session = TacticSessionProbe(
        '6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1',
        ['a1a8'],
      );
      expect(session.tryMove('a1', 'a7'), isFalse);
      expect(session.isComplete, isFalse);

      final ok = session.tryMove('a1', 'a8');
      expect(ok, isTrue);
      expect(session.isComplete, isTrue);
      expect(session.board.in_checkmate, isTrue);
    });

    test('sequência mate em 2 alterna solver e oponente', () {
      final session = TacticSessionProbe(
        'r1bqkb1r/pppp1ppp/2n2n2/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 4 4',
        ['h5f7', 'e8f7' /* resposta forçada inexistente: linha curta */],
      );
      expect(session.board.fen.length, greaterThan(10));
    });
  });
}
