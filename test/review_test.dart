import 'package:chess/chess.dart' as ch;
import 'package:flutter_test/flutter_test.dart';
import 'package:oct/data/engine/chess_engine.dart';
import 'package:oct/domain/services/game_review_service.dart';
import 'package:oct/presentation/providers/play_controller.dart';

/// Eval falso: material × 100, relativo a quem tem a vez.
Future<EngineEval?> fakeEval(String fen) async {
  final pos = ch.Chess.fromFEN(fen);
  var white = 0;
  var black = 0;
  const values = {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9};
  const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  for (final f in files) {
    for (var r = 1; r <= 8; r++) {
      final piece = pos.get('$f$r');
      if (piece == null) continue;
      final v = values[piece.type.name] ?? 0;
      if (piece.color == ch.Color.WHITE) {
        white += v;
      } else {
        black += v;
      }
    }
  }
  final whiteRel = (white - black) * 100;
  final side = fen.split(' ')[1] == 'b' ? 'b' : 'w';
  return EngineEval(cp: side == 'w' ? whiteRel : -whiteRel, depth: 1);
}

({List<String> sans, List<String> fens}) playMoves(List<String> ucis) {
  final game = ch.Chess();
  final sans = <String>[];
  final fens = <String>[game.fen];
  for (final u in ucis) {
    game.move({
      'from': u.substring(0, 2),
      'to': u.substring(2, 4),
      'promotion': u.length > 4 ? u[4] : 'q',
    });
    sans.add('${game.getHistory().last}');
    fens.add(game.fen);
  }
  return (sans: sans, fens: fens);
}

void main() {
  group('GameReviewService.math', () {
    test('cp 0 = 50%, accuracy perfeita = 100', () {
      expect(GameReviewService.cpToWinPct(0), 50);
      expect(GameReviewService.accuracyFromAvgLoss(0), 100);
      expect(GameReviewService.estimateFromAvgLoss(0), 2500);
    });

    test('formatWhiteEval cobre peões e mates', () {
      expect(GameReviewService.formatWhiteEval(cp: 150), '+1.5');
      expect(GameReviewService.formatWhiteEval(cp: -30), '-0.3');
      expect(GameReviewService.formatWhiteEval(cp: 0), '0.0');
      expect(GameReviewService.formatWhiteEval(mate: 3), 'M3');
      expect(GameReviewService.formatWhiteEval(mate: -2), '-M2');
    });
  });

  group('OpeningBook', () {
    test('identifica linhas comuns', () {
      expect(OpeningBook.identify(['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']).name,
          'RUY LOPEZ');
      expect(OpeningBook.identify(['e4', 'c5']).name, 'SICILIANA');
      expect(OpeningBook.identify(['d4', 'd5', 'c4', 'c6']).name,
          'GAMBITO DA DAMA: ESLAVA');
      expect(OpeningBook.identify(['a4', 'h5']).name, 'FORA DO LIVRO');
    });
  });

  group('analyze (mate do louco)', () {
    test('estrutura + mate final bem classificado', () async {
      final g = playMoves(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
      final review = await GameReviewService.analyze(
        historySan: g.sans,
        historyFen: g.fens,
        evalFn: fakeEval,
      );
      expect(review.labels.length, 4);
      expect(review.timeline.length, 5);
      expect(review.evalTexts.length, 5);
      expect(
          review.labels.last,
          anyOf([
            MoveLabel.best,
            MoveLabel.great,
            MoveLabel.brilliant,
            MoveLabel.excellent,
          ]));
      expect(review.accuracyWhite, inInclusiveRange(0, 100));
      expect(review.accuracyBlack, inInclusiveRange(0, 100));
      final totalWhite =
          review.countsWhite.values.reduce((a, b) => a + b);
      expect(totalWhite, 2);
      expect(review.openingName, isNotEmpty);
    });
  });

  group('PlayController.casualChance', () {
    test('250 joga casual, 1100+ nunca', () {
      expect(PlayController.casualChance(250), 0.65);
      expect(PlayController.casualChance(800), greaterThan(0.2));
      expect(PlayController.casualChance(1100), 0);
      expect(PlayController.casualChance(2500), 0);
    });
  });
}
