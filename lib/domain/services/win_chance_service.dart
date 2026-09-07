import 'dart:math' as math;

import 'package:chess/chess.dart' as ch;

/// Serviço de estimativa local de chances (sem motor): converte vantagem
/// de material em probabilidade de vitória via curva logística.
///
/// É uma heurística honesta de Fase 1 — a análise fina com Stockfish
/// (centipawns por lance) entra na Fase 2.
class WinChance {
  WinChance._();

  static const Map<String, int> pieceValues = {
    'p': 1,
    'n': 3,
    'b': 3,
    'r': 5,
    'q': 9,
    'k': 0,
  };

  /// Material (brancas, pretas) somando valores das peças no tabuleiro.
  static ({int white, int black}) materialOf(ch.Chess game) {
    var white = 0;
    var black = 0;
    const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    for (final f in files) {
      for (var r = 1; r <= 8; r++) {
        final piece = game.get('$f$r');
        if (piece == null) continue;
        final v = pieceValues[piece.type.name] ?? 0;
        if (piece.color == ch.Color.WHITE) {
          white += v;
        } else {
          black += v;
        }
      }
    }
    return (white: white, black: black);
  }

  /// Diferença de material do ponto de vista de [perspective] ('w'/'b').
  static int materialDiff(ch.Chess game, String perspective) {
    final m = materialOf(game);
    final diff = m.white - m.black;
    return perspective == 'w' ? diff : -diff;
  }

  /// Probabilidade (0..100) de vitória para quem tem [diff] pontos a mais.
  /// +1 ≈ 64%, +3 ≈ 85%, +5 ≈ 95%.
  static double probability(int diff) {
    final p = 1 / (1 + math.pow(10, -diff / 4));
    return (p * 100).clamp(0, 100).toDouble();
  }

  /// Texto de placar de material, ex: "+2".
  static String diffLabel(int diff) =>
      diff == 0 ? 'IGUAL' : '${diff > 0 ? '+' : ''}$diff';
}
