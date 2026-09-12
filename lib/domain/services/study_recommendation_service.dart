import 'game_review_service.dart';

/// Recomendação de tema tático para estudar após jogar contra o bot.
class StudyRecommendation {
  const StudyRecommendation({
    required this.theme,
    required this.reason,
    required this.priority,
  });

  final String theme;
  final String reason;
  final int priority; // menor = mais urgente
}

/// Traduz a revisão do motor em "o que estudar".
/// 100% offline, heurística simples e explicável.
class StudyRecommendationService {
  StudyRecommendationService._();

  /// Recomendações a partir de UMA partida revisada.
  static List<StudyRecommendation> fromReview(
    GameReview review, {
    required bool userWhite,
  }) {
    final counts = userWhite ? review.countsWhite : review.countsBlack;
    final skills = userWhite ? review.skillsWhite : review.skillsBlack;
    final out = <StudyRecommendation>[];

    void add(String theme, String reason, int priority) {
      if (out.any((e) => e.theme == theme)) return;
      out.add(StudyRecommendation(
          theme: theme, reason: reason, priority: priority));
    }

    final blunders = counts[MoveLabel.blunder] ?? 0;
    final mistakes = counts[MoveLabel.mistake] ?? 0;
    final inacc = counts[MoveLabel.inaccuracy] ?? 0;
    final misses = counts[MoveLabel.miss] ?? 0;
    final great = (counts[MoveLabel.brilliant] ?? 0) +
        (counts[MoveLabel.great] ?? 0) +
        (counts[MoveLabel.best] ?? 0);

    // Erros graves: peça pendurada / visão tática.
    if (blunders > 0) {
      add('hangingPiece', '$blunders DESASTRE(S): PEÇA PENDURADA',
          10 + blunders);
      add('deflection', 'TREINE DESVIO E ATRAÇÃO P/ NÃO CAIR EM ARMADILHA',
          20);
    }
    if (mistakes > 0) {
      add('hangingPiece', '$mistakes ERRO(S): REVISE SEGURANÇA DAS PEÇAS',
          30);
    }
    if (misses > 0) {
      add('fork', '$misses CHANCE(S) PERDIDA(S): TREINE GARFO', 15);
      add('pin', 'CRAVADAS E ESPETOS CRIAM CHANCES', 25);
      add('discoveredAttack', 'ATAQUE À DESCOBERTA VIRA O JOGO', 26);
    }
    if (inacc >= 2) {
      add('quietMove', 'IMPRECISÕES: TREINE LANCES SILENCIOSOS', 40);
      add('middlegame', 'PLANO DE MEIO-JOGO', 41);
    }

    // Fases fracas.
    final ab = skills.abertura ?? 100;
    final meio = skills.meioJogo ?? 100;
    final fim = skills.finalJogo ?? 100;
    final tat = skills.tatica ?? 100;
    if (ab < 75) {
      add('opening', 'ABERTURA ${(ab).toStringAsFixed(0)}: REPITA LINHAS', 12);
    }
    if (tat < 75) {
      add('fork', 'TÁTICA ${(tat).toStringAsFixed(0)}: GARFO + CRAVADA', 11);
      add('mateIn1', 'FINALIZAÇÃO: MATE EM 1 E 2', 13);
      add('mateIn2', 'FINALIZAÇÃO: MATE EM 2', 14);
    }
    if (meio < 75) {
      add('middlegame', 'MEIO-JOGO ${(meio).toStringAsFixed(0)}', 32);
      add('kingsideAttack', 'ATAQUE AO REI NO MEIO-JOGO', 33);
    }
    if (fim < 75) {
      add('endgame', 'FINAIS ${(fim).toStringAsFixed(0)}: BASE', 34);
      add('rookEndgame', 'FINAIS DE TORRE SÃO OS MAIS COMUNS', 35);
      add('pawnEndgame', 'OPOSIÇÃO E QUADRADO NO FINAL DE PEÃO', 36);
    }

    // Sacrifícios bem executados (brilhantes): aprofunde.
    if ((counts[MoveLabel.brilliant] ?? 0) > 0) {
      add('sacrifice', 'VOCÊ ACHOU SACRIFÍCIOS: APROFUNDE', 50);
    }

    // Se jogou bem, manda aprofundar mate / vantagem.
    if (out.isEmpty) {
      if (great > 0) {
        add('mateIn2', 'BOM JOGO: SUBA PARA MATE EM 2 E 3', 60);
        add('crushing', 'CONVERTA VANTAGEM DECISIVA', 61);
      } else {
        add('mateIn1', 'BASE: MATE EM 1 PARA CALIBRAR', 60);
        add('fork', 'BASE: GARFO (FORK)', 61);
      }
    }

    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out.take(4).toList();
  }

  /// Recomendações agregadas do dashboard (médias de todas as partidas).
  static List<StudyRecommendation> fromDashboard({
    required double? abertura,
    required double? meio,
    required double? fim,
    required double? tatica,
    required Map<String, int> labels,
  }) {
    int get(String name) {
      final byName = <String, int>{};
      for (final l in MoveLabel.values) {
        byName[l.name] = labels[l.name] ?? 0;
      }
      return byName[name] ?? 0;
    }

    final blunders = get('blunder');
    final mistakes = get('mistake');
    final misses = get('miss');
    final out = <StudyRecommendation>[];

    void add(String theme, String reason, int priority) {
      if (out.any((e) => e.theme == theme)) return;
      out.add(StudyRecommendation(
          theme: theme, reason: reason, priority: priority));
    }

    if (blunders >= 3) {
      add('hangingPiece', '$blunders DESASTRES NO TOTAL: PEÇA PENDURADA', 10);
    } else if (blunders > 0 || mistakes >= 3) {
      add('hangingPiece', 'ERROS CAROS: SEGURANÇA TÁTICA', 20);
    }
    if (misses >= 2) {
      add('fork', '$misses CHANCES PERDIDAS: GARFO', 11);
      add('pin', 'CRAVADA E ESPETO', 12);
    }
    if ((abertura ?? 100) < 78) {
      add('opening', 'ABERTURA É SEU PONTO FRACO', 13);
    }
    if ((tatica ?? 100) < 78) {
      add('mateIn1', 'TÁTICA PEDE MATE EM 1 E 2', 14);
      add('mateIn2', 'MATE EM 2', 15);
    }
    if ((meio ?? 100) < 78) {
      add('middlegame', 'MEIO-JOGO PEDE PLANO', 16);
    }
    if ((fim ?? 100) < 78) {
      add('endgame', 'FINAIS PEDEM BASE', 17);
      add('rookEndgame', 'FINAIS DE TORRE', 18);
    }
    if (out.isEmpty) {
      add('mateIn2', 'EVOLUA: MATE EM 2 E 3', 50);
      add('crushing', 'CONVERSÃO DE VANTAGEM', 51);
    }
    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out.take(4).toList();
  }
}
