import 'package:flutter_test/flutter_test.dart';
import 'package:oct/domain/services/elo_service.dart';

void main() {
  group('EloService', () {
    test('expected score é 0.5 para ratings iguais', () {
      expect(EloService.expectedScore(1500, 1500), closeTo(0.5, 0.0001));
    });

    test('expected score cresce quando jogador tem rating maior', () {
      final stronger = EloService.expectedScore(1800, 1400);
      final weaker = EloService.expectedScore(1400, 1800);
      expect(stronger, greaterThan(0.75));
      expect(weaker, lessThan(0.25));
      expect(stronger + weaker, closeTo(1.0, 0.0001));
    });

    test('K fator provisório para novos jogadores', () {
      expect(
          EloService.kFactor(gamesPlayed: 5, playerElo: 1200), 40);
      expect(
          EloService.kFactor(gamesPlayed: 29, playerElo: 1200), 40);
    });

    test('K fator padrão após período provisório', () {
      expect(
          EloService.kFactor(gamesPlayed: 30, playerElo: 1200), 20);
    });

    test('K fator reduzido para veteranos acima de 2400', () {
      expect(
          EloService.kFactor(gamesPlayed: 100, playerElo: 2500), 10);
    });

    test('vitória contra oponente mais forte rende mais pontos', () {
      final vsStronger = EloService.updatedRating(
        currentRating: 1200,
        opponentRating: 1800,
        score: 1,
        gamesPlayed: 50,
      );
      final vsWeaker = EloService.updatedRating(
        currentRating: 1200,
        opponentRating: 800,
        score: 1,
        gamesPlayed: 50,
      );
      expect(vsStronger - 1200, greaterThan(vsWeaker - 1200));
      expect(vsStronger, greaterThan(1218));
    });

    test('derrota reduz rating e empate ajusta levemente', () {
      final afterLoss = EloService.updatedRating(
        currentRating: 1500,
        opponentRating: 1500,
        score: 0,
        gamesPlayed: 100,
      );
      final afterDraw = EloService.updatedRating(
        currentRating: 1500,
        opponentRating: 1500,
        score: 0.5,
        gamesPlayed: 100,
      );
      expect(afterLoss, lessThan(1500));
      expect(afterDraw, 1500);
    });

    test('rating nunca sai dos limites globais', () {
      final absurdWin = EloService.updatedRating(
        currentRating: 3499,
        opponentRating: 100,
        score: 1,
        gamesPlayed: 5,
      );
      expect(absurdWin, lessThanOrEqualTo(3500));
    });
  });
}
