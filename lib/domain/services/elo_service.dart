import 'dart:math' as math;

class EloService {
  EloService._();

  static const int startingElo = 1200;
  static const int provisionalGames = 30;
  static const int veteranThreshold = 2400;

  static double expectedScore(int playerElo, int opponentElo) {
    return 1 / (1 + math.pow(10, (opponentElo - playerElo) / 400));
  }

  static double kFactor({required int gamesPlayed, required int playerElo}) {
    if (gamesPlayed < provisionalGames) return 40;
    if (playerElo >= veteranThreshold) return 10;
    return 20;
  }

  static int updatedRating({
    required int currentRating,
    required int opponentRating,
    required double score,
    required int gamesPlayed,
  }) {
    assert(score >= 0 && score <= 1);
    final k = kFactor(gamesPlayed: gamesPlayed, playerElo: currentRating);
    final expected = expectedScore(currentRating, opponentRating);
    final next = (currentRating + k * (score - expected)).round();
    return next.clamp(100, 3500);
  }

  static double scoreForResult({
    required bool userWon,
    required bool draw,
  }) {
    if (draw) return 0.5;
    return userWon ? 1.0 : 0.0;
  }
}
