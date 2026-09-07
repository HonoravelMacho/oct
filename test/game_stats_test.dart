import 'package:chess/chess.dart' as ch;
import 'package:flutter_test/flutter_test.dart';
import 'package:oct/core/app_constants.dart';
import 'package:oct/domain/entities/bot_profile.dart';
import 'package:oct/domain/services/win_chance_service.dart';

void main() {
  group('WinChance', () {
    test('posição inicial tem material igual e 50%', () {
      final game = ch.Chess();
      final m = WinChance.materialOf(game);
      expect(m.white, 39);
      expect(m.black, 39);
      expect(WinChance.materialDiff(game, 'w'), 0);
      expect(WinChance.probability(0), 50);
    });

    test('vantagem de +3 dá cerca de 85%', () {
      final p = WinChance.probability(3);
      expect(p, greaterThan(80));
      expect(p, lessThan(90));
    });

    test('materialDiff inverte pela perspectiva', () {
      final game = ch.Chess.fromFEN(
          'rnbqkbnr/ppp1pppp/8/3p4/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1');
      // Pretas capturaram? e4xd5 seria... aqui só checa simetria do cálculo.
      expect(WinChance.materialDiff(game, 'w'),
          -WinChance.materialDiff(game, 'b'));
    });

    test('dama a mais (+9) dá quase 100%', () {
      expect(WinChance.probability(9), greaterThan(99));
    });
  });

  group('BotProfile.tuned', () {
    test('extremos do slider mapeiam skill 0..20', () {
      final min = BotProfile.tuned(
          name: 'PEAO', elo: AppConstants.minBotElo);
      final max = BotProfile.tuned(
          name: 'REI', elo: AppConstants.maxBotElo);
      expect(min.elo, 250);
      expect(min.skillLevel, 0);
      expect(max.elo, 2500);
      expect(max.skillLevel, 20);
      expect(min.moveTimeMs, lessThan(max.moveTimeMs));
    });

    test('passo de 50 e uciElo dentro da faixa do Stockfish', () {
      var prev = 0;
      for (var elo = AppConstants.minBotElo;
          elo <= AppConstants.maxBotElo;
          elo += AppConstants.botEloStep) {
        final bot = BotProfile.tuned(name: 'TORRE', elo: elo);
        expect(bot.uciElo, greaterThanOrEqualTo(1320));
        expect(bot.uciElo, lessThanOrEqualTo(3190));
        expect(bot.elo, greaterThan(prev));
        prev = bot.elo;
      }
    });

    test('valores fora da faixa são limitados', () {
      expect(BotProfile.tuned(name: 'X', elo: 0).elo, 250);
      expect(BotProfile.tuned(name: 'X', elo: 9999).elo, 2500);
    });
  });
}
