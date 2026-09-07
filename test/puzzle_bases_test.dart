import 'package:chess/chess.dart' as ch;
import 'package:flutter_test/flutter_test.dart';

/// Espelha as bases do gerador da base gratuita: (fen, lance).
/// Se este teste passa, todo puzzle embarcado tem posição+lance legal,
/// ou seja, é jogável na tela de táticas.
const List<(String, String)> kPuzzleBases = [
  ('6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1', 'a1a8'),
  ('6k1/8/8/8/8/8/5PPP/R5K1 w - - 0 1', 'a1a8'),
  ('r1bqkbnr/pppp1ppp/2n5/4p2Q/2B1P3/8/PPPP1PPP/RNB1K1NR w KQkq - 0 1', 'h5f7'),
  ('5rk1/8/8/8/8/8/6PP/5RK1 w - - 0 1', 'f1f8'),
  ('r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 1', 'c4f7'),
  ('r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3', 'f3g5'),
  ('r1bqkbnr/ppp2ppp/2n5/3p4/3PP3/5N2/PPP2PPP/RNBQKB1R w KQkq - 0 1', 'e4e5'),
  ('r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3', 'd2d4'),
  ('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1', 'e2e4'),
  ('8/5P1k/8/8/8/8/6K1/8 w - - 0 1', 'f7f8q'),
  ('8/5P1k/8/8/8/8/6K1/8 w - - 0 1', 'f7f8n'),
  ('rnbqkbnr/ppp1p1pp/8/3pPp2/8/8/PPPP1PPP/RNBQKBNR w KQkq f6 0 1', 'e5f6'),
  ('r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1', 'e1g1'),
  ('5k2/8/8/8/8/8/5B1P/5K2 w - - 0 1', 'f2g3'),
  ('5k2/8/8/8/8/8/3Q2P1/5K2 w - - 0 1', 'd2d7'),
  ('5k2/8/8/8/8/8/5N1P/5K2 w - - 0 1', 'f2g4'),
  ('r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 1', 'd2d4'),
];

void main() {
  group('bases de táticas embarcadas', () {
    for (final (fen, uci) in kPuzzleBases) {
      test('$uci em ${fen.split(' ').first}', () {
        final game = ch.Chess.fromFEN(fen);
        final ok = game.move({
          'from': uci.substring(0, 2),
          'to': uci.substring(2, 4),
          'promotion': uci.length > 4 ? uci[4] : null,
        });
        expect(ok, isTrue, reason: 'lance ilegal: $uci em $fen');
      });
    }
  });
}
