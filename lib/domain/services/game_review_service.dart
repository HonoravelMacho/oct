import 'dart:math' as math;

import 'package:chess/chess.dart' as ch;

import '../../data/engine/chess_engine.dart';
import 'win_chance_service.dart';

/// Etiquetas de lance da revisão OCT (inspiradas no padrão do mercado,
/// com nomes próprios para não ser cópia).
enum MoveLabel {
  brilliant,
  great,
  best,
  excellent,
  good,
  book,
  inaccuracy,
  mistake,
  miss,
  blunder,
}

/// Revisão de partida 100% local com o motor embutido.
class GameReviewService {
  GameReviewService._();

  /// Profundidade fixa exibida na revisão ("PROFUNDIDADE 11").
  static const int reviewDepth = 11;

  /// Opções de análise: rápida (segundos) → profunda (minutos, mais precisa).
  static const List<int> depthOptions = [8, 11, 15];

  static const Map<MoveLabel, String> labelNames = {
    MoveLabel.brilliant: 'BRILHANTE',
    MoveLabel.great: 'GRANDE LANCE',
    MoveLabel.best: 'MELHOR LANCE',
    MoveLabel.excellent: 'EXCELENTE',
    MoveLabel.good: 'BOM LANCE',
    MoveLabel.book: 'TEORIA',
    MoveLabel.inaccuracy: 'IMPRECISO',
    MoveLabel.mistake: 'ERRO',
    MoveLabel.miss: 'CHANCE PERDIDA',
    MoveLabel.blunder: 'DESASTRE',
  };

  static const Map<MoveLabel, String> labelEmojis = {
    MoveLabel.brilliant: '🔵',
    MoveLabel.great: '🟢',
    MoveLabel.best: '⭐',
    MoveLabel.excellent: '✨',
    MoveLabel.good: '👍',
    MoveLabel.book: '📖',
    MoveLabel.inaccuracy: '⚠️',
    MoveLabel.mistake: '❓',
    MoveLabel.miss: '✖️',
    MoveLabel.blunder: '‼️',
  };

  /// Converte centipawns (perspectiva de quem tem a vantagem) em win%.
  static double cpToWinPct(double cp) =>
      (100 / (1 + math.pow(10, -cp / 400))).clamp(0, 100).toDouble();

  /// Mate em k (positivo = a favor) vira equivalente em cp para a logística.
  static double mateToCp(int k) {
    if (k == 0) return 0;
    final dist = k.abs().clamp(1, 100);
    return (k > 0 ? 1 : -1) * (100000 - 500 * dist).toDouble();
  }

  /// Precisão 0..100 estilo Lichess a partir da perda média em win%.
  static double accuracyFromAvgLoss(double avgLoss) {
    final acc =
        103.1668 * math.exp(-0.04354 * avgLoss.clamp(0, 100)) + 3.1669;
    return acc.clamp(0, 100).toDouble();
  }

  /// Nível estimado na partida a partir da perda média.
  static int estimateFromAvgLoss(double avgLoss) =>
      (2500 - avgLoss * 55).clamp(250, 2900).round();

  static String sideToMove(String fen) {
    final parts = fen.split(' ');
    return parts.length > 1 && parts[1] == 'b' ? 'b' : 'w';
  }

  static double materialCpWhite(String fen) {
    try {
      final pos = ch.Chess.fromFEN(fen);
      final m = WinChance.materialOf(pos);
      return ((m.white - m.black) * 100).toDouble();
    } catch (_) {
      return 0;
    }
  }

  /// Formato da avaliação em perspectiva das brancas: +1.5, -0.3, M4, -M2.
  static String formatWhiteEval({int? cp, int? mate}) {
    if (mate != null && mate != 0) {
      return mate > 0 ? 'M$mate' : '-M${-mate}';
    }
    final pawns = (cp ?? 0) / 100;
    if (pawns == 0) return '0.0';
    final txt = pawns.abs().toStringAsFixed(1);
    return '${pawns > 0 ? '+' : '-'}$txt';
  }

  static Future<GameReview> analyze({
    required List<String> historySan,
    required List<String> historyFen,
    required Future<EngineEval?> Function(String fen) evalFn,
    int depth = reviewDepth,
  }) async {
    final n = historySan.length;
    final raw = <EngineEval?>[];
    for (var i = 0; i <= n; i++) {
      EngineEval? e;
      try {
        e = await evalFn(historyFen[i]);
      } catch (_) {
        e = null;
      }
      raw.add(e);
    }

    var engineUsed = false;
    for (final e in raw) {
      if (e != null && (e.cp != null || e.mate != null)) {
        engineUsed = true;
        break;
      }
    }

    final labels = <MoveLabel>[];
    final lossesWhite = <double>[];
    final lossesBlack = <double>[];
    final timeline = <double>[];
    final evalTexts = <String>[];
    final phaseLossWhite = <String, List<double>>{
      'abertura': [],
      'meio': [],
      'final': [],
    };
    final phaseLossBlack = <String, List<double>>{
      'abertura': [],
      'meio': [],
      'final': [],
    };
    final tacticLossWhite = <double>[];
    final tacticLossBlack = <double>[];
    final sans = <String>[];
    for (var i = 0; i < n; i++) {
      sans.add(_normalizeSan(historySan[i]));
    }

    for (var i = 0; i <= n; i++) {
      final fen = historyFen[i];
      final side = sideToMove(fen);
      final e = raw[i];
      double cpWhite;
      if (e != null && (e.cp != null || e.mate != null)) {
        final sideCp = e.mate != null
            ? mateToCp(e.mate!)
            : (e.cp ?? 0).toDouble();
        cpWhite = side == 'w' ? sideCp : -sideCp;
      } else {
        cpWhite = materialCpWhite(fen);
      }
      timeline.add(cpToWinPct(cpWhite));
      final eMateWhite = e?.mate != null
          ? (side == 'w' ? e!.mate! : -e!.mate!)
          : null;
      evalTexts.add(formatWhiteEval(
        cp: e?.mate != null ? null : cpWhite.round(),
        mate: eMateWhite,
      ));
    }

    for (var i = 0; i < n; i++) {
      final fenBefore = historyFen[i];
      final fenAfter = historyFen[i + 1];
      final mover = sideToMove(fenBefore); // 'w' ou 'b'
      final e = raw[i];

      double bestSide;
      if (e != null && (e.cp != null || e.mate != null)) {
        bestSide =
            e.mate != null ? mateToCp(e.mate!) : (e.cp ?? 0).toDouble();
      } else {
        bestSide = mover == 'w'
            ? materialCpWhite(fenAfter)
            : -materialCpWhite(fenAfter);
      }

      final cpWhiteBefore = _whiteCp(e, fenBefore, mover);
      final wpBeforeWhite = cpToWinPct(cpWhiteBefore);
      final wpBeforeMover =
          mover == 'w' ? wpBeforeWhite : 100 - wpBeforeWhite;

      final cpWhiteAfter = _whiteCpAfter(raw, i, fenAfter);
      final wpAfterMover = mover == 'w'
          ? cpToWinPct(cpWhiteAfter)
          : 100 - cpToWinPct(cpWhiteAfter);
      final wpBestMover = mover == 'w'
          ? cpToWinPct(_whiteOfSide(bestSide, mover))
          : 100 - cpToWinPct(_whiteOfSide(bestSide, mover));

      final gain = wpAfterMover - wpBeforeMover;
      final bestGain = wpBestMover - wpBeforeMover;

      final isBook = _isBookMove(sans, i);
      final sacrificed = _isSacrifice(fenBefore, fenAfter, mover);

      // Quem já dá mate: mede a distância (mate em 5 após mate em 2 = lento).
      final kb = e?.mate;
      int? ka;
      final eAfter = raw[i + 1];
      if (eAfter?.mate != null) {
        final afterSide = sideToMove(fenAfter);
        ka = afterSide == mover ? eAfter!.mate! : -eAfter!.mate!;
      }

      MoveLabel label;
      double loss;
      if (kb != null && kb > 0 && ka != null && ka > 0) {
        loss = ((ka - kb).abs() * 2).clamp(0, 25).toDouble();
        label = loss <= 0.5
            ? (sacrificed ? MoveLabel.brilliant : MoveLabel.best)
            : (loss <= 7 ? MoveLabel.excellent : MoveLabel.good);
      } else if (isBook) {
        loss = (wpBestMover - wpAfterMover).clamp(0, 100).toDouble();
        label = MoveLabel.book;
      } else if (wpBeforeMover < 80 &&
          bestGain >= 18 &&
          gain >= -3 &&
          gain < 6) {
        loss = (wpBestMover - wpAfterMover).clamp(0, 100).toDouble();
        label = MoveLabel.miss;
      } else {
        loss = (wpBestMover - wpAfterMover).clamp(0, 100).toDouble();
        if (loss <= 0.5 && sacrificed) {
          label = MoveLabel.brilliant;
        } else if (loss <= 0.5 && gain >= 12) {
          label = MoveLabel.great;
        } else if (loss <= 0.5) {
          label = MoveLabel.best;
        } else if (loss <= 3) {
          label = MoveLabel.excellent;
        } else if (loss <= 7) {
          label = MoveLabel.good;
        } else if (loss <= 13) {
          label = MoveLabel.inaccuracy;
        } else if (loss <= 22) {
          label = MoveLabel.mistake;
        } else {
          label = MoveLabel.blunder;
        }
      }
      labels.add(label);

      final phase = _phaseOf(fenBefore, i);
      if (mover == 'w') {
        lossesWhite.add(loss);
        phaseLossWhite[phase]!.add(loss);
        if (bestGain >= 15) tacticLossWhite.add(loss);
      } else {
        lossesBlack.add(loss);
        phaseLossBlack[phase]!.add(loss);
        if (bestGain >= 15) tacticLossBlack.add(loss);
      }
    }

    double avg(List<double> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    double? phaseAcc(Map<String, List<double>> m, String k) =>
        m[k]!.isNotEmpty ? accuracyFromAvgLoss(avg(m[k]!)) : null;

    final avgWhite = avg(lossesWhite);
    final avgBlack = avg(lossesBlack);

    Map<MoveLabel, int> counts(List<MoveLabel> all, bool white) {
      final map = {for (final l in MoveLabel.values) l: 0};
      for (var i = 0; i < n; i++) {
        final isWhiteMove = i % 2 == 0;
        if ((white && isWhiteMove) || (!white && !isWhiteMove)) {
          map[all[i]] = (map[all[i]] ?? 0) + 1;
        }
      }
      return map;
    }

    final opening = OpeningBook.identify(sans);

    return GameReview(
      accuracyWhite: accuracyFromAvgLoss(avgWhite),
      accuracyBlack: accuracyFromAvgLoss(avgBlack),
      estWhite: estimateFromAvgLoss(avgWhite),
      estBlack: estimateFromAvgLoss(avgBlack),
      countsWhite: counts(labels, true),
      countsBlack: counts(labels, false),
      labels: labels,
      timeline: timeline,
      evalTexts: evalTexts,
      depth: depth,
      engineUsed: engineUsed,
      openingName: opening.name,
      openingKey: opening.key,
      skillsWhite: PhaseSkills(
        abertura: phaseAcc(phaseLossWhite, 'abertura'),
        meioJogo: phaseAcc(phaseLossWhite, 'meio'),
        finalJogo: phaseAcc(phaseLossWhite, 'final'),
        tatica: tacticLossWhite.isNotEmpty
            ? accuracyFromAvgLoss(avg(tacticLossWhite))
            : null,
      ),
      skillsBlack: PhaseSkills(
        abertura: phaseAcc(phaseLossBlack, 'abertura'),
        meioJogo: phaseAcc(phaseLossBlack, 'meio'),
        finalJogo: phaseAcc(phaseLossBlack, 'final'),
        tatica: tacticLossBlack.isNotEmpty
            ? accuracyFromAvgLoss(avg(tacticLossBlack))
            : null,
      ),
    );
  }

  /// Placar side-to-move da avaliação bruta (mate vira equivalente).
  static double _searchSideCp(EngineEval? e) {
    if (e == null) return 0;
    if (e.mate != null) return mateToCp(e.mate!);
    return (e.cp ?? 0).toDouble();
  }

  /// cp em perspectiva das brancas da posição [fen] usando o eval bruto [e].
  static double _whiteCp(EngineEval? e, String fen, String side) {
    if (e != null && (e.cp != null || e.mate != null)) {
      final s = _searchSideCp(e);
      return side == 'w' ? s : -s;
    }
    return materialCpWhite(fen);
  }

  /// cp branco depois do lance, preferindo o eval estático da posição real.
  static double _whiteCpAfter(
      List<EngineEval?> raw, int i, String fenAfter) {
    final eAfter = raw[i + 1];
    if (eAfter != null && (eAfter.cp != null || eAfter.mate != null)) {
      final afterSide = sideToMove(fenAfter);
      final s = _searchSideCp(eAfter);
      return afterSide == 'w' ? s : -s;
    }
    return materialCpWhite(fenAfter);
  }

  static double _whiteOfSide(double sideCp, String side) =>
      side == 'w' ? sideCp : -sideCp;

  static bool _isSacrifice(String fenBefore, String fenAfter, String mover) {
    try {
      final a = WinChance.materialOf(ch.Chess.fromFEN(fenBefore));
      final b = WinChance.materialOf(ch.Chess.fromFEN(fenAfter));
      final before = mover == 'w' ? a.white : a.black;
      final after = mover == 'w' ? b.white : b.black;
      return after < before;
    } catch (_) {
      return false;
    }
  }

  static String _phaseOf(String fen, int ply) {
    if (ply < 10) return 'abertura';
    try {
      final placement = fen.split(' ').first;
      final hasQueens = placement.contains('q') || placement.contains('Q');
      var pieces = 0;
      for (final c in placement.codeUnits) {
        final chStr = String.fromCharCode(c);
        if (RegExp(r'[pnbrqkPNBRQK]').hasMatch(chStr)) pieces++;
      }
      if (!hasQueens || pieces <= 12) return 'final';
    } catch (_) {}
    return 'meio';
  }

  static String _normalizeSan(String san) =>
      san.replaceAll(RegExp(r'[+#?!]+$'), '');

  static bool _isBookMove(List<String> sans, int ply) {
    if (ply >= 12) return false;
    final prefix = sans.take(ply + 1).toList();
    for (final line in OpeningBook.lines) {
      if (line.length > ply &&
          _prefixMatches(line, prefix)) {
        return true;
      }
    }
    return false;
  }

  static bool _prefixMatches(List<String> line, List<String> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (_normalizeSan(line[i]) != prefix[i]) return false;
    }
    return true;
  }
}

class PhaseSkills {
  const PhaseSkills(
      {this.abertura, this.meioJogo, this.finalJogo, this.tatica});

  final double? abertura;
  final double? meioJogo;
  final double? finalJogo;
  final double? tatica;
}

class GameReview {
  const GameReview({
    required this.accuracyWhite,
    required this.accuracyBlack,
    required this.estWhite,
    required this.estBlack,
    required this.countsWhite,
    required this.countsBlack,
    required this.labels,
    required this.timeline,
    required this.evalTexts,
    required this.depth,
    required this.engineUsed,
    required this.openingName,
    required this.openingKey,
    required this.skillsWhite,
    required this.skillsBlack,
  });

  final double accuracyWhite;
  final double accuracyBlack;
  final int estWhite;
  final int estBlack;
  final Map<MoveLabel, int> countsWhite;
  final Map<MoveLabel, int> countsBlack;
  final List<MoveLabel> labels;
  final List<double> timeline;
  final List<String> evalTexts;
  final int depth;
  final bool engineUsed;
  final String openingName;
  final String openingKey;
  final PhaseSkills skillsWhite;
  final PhaseSkills skillsBlack;
}

/// Micro-livro de aberturas embutido (offline): linhas comuns + nomes.
class OpeningBook {
  OpeningBook._();

  static const List<List<String>> lines = [
    ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'a6'],
    ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5', 'Nf6'],
    ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5'],
    ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5'],
    ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nf6'],
    ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4'],
    ['e4', 'e5', 'Nf3', 'Nc6', 'd4'],
    ['e4', 'e5', 'Nf3', 'd6'],
    ['e4', 'e5', 'Nf3', 'Nf6'],
    ['e4', 'e5', 'Nc3', 'Nf6'],
    ['e4', 'e5', 'Bc4'],
    ['e4', 'e5'],
    ['e4', 'c5', 'Nf3', 'd6', 'd4'],
    ['e4', 'c5', 'Nf3', 'Nc6'],
    ['e4', 'c5', 'Nf3'],
    ['e4', 'c5'],
    ['e4', 'e6', 'd4', 'd5'],
    ['e4', 'e6'],
    ['e4', 'c6', 'd4', 'd5'],
    ['e4', 'c6'],
    ['e4', 'd5'],
    ['e4', 'd6'],
    ['e4', 'g6'],
    ['e4', 'Nf6'],
    ['d4', 'd5', 'c4', 'e6'],
    ['d4', 'd5', 'c4', 'c6'],
    ['d4', 'd5', 'c4'],
    ['d4', 'd5', 'Bf4'],
    ['d4', 'd5', 'Nf3'],
    ['d4', 'd5'],
    ['d4', 'Nf6', 'c4', 'e6', 'Nc3', 'Bb4'],
    ['d4', 'Nf6', 'c4', 'e6'],
    ['d4', 'Nf6', 'c4', 'g6'],
    ['d4', 'Nf6', 'c4'],
    ['d4', 'Nf6', 'Bf4'],
    ['d4', 'Nf6'],
    ['d4', 'f5'],
    ['c4'],
    ['Nf3', 'd5'],
    ['Nf3'],
    ['g3'],
    ['b3'],
    ['f4'],
    ['Nc3'],
  ];

  static const Map<String, String> names = {
    'e4 e5 Nf3 Nc6 Bb5 a6': 'RUY LOPEZ: MORPHY',
    'e4 e5 Nf3 Nc6 Bb5 Nf6': 'RUY LOPEZ: BERLINESA',
    'e4 e5 Nf3 Nc6 Bb5': 'RUY LOPEZ',
    'e4 e5 Nf3 Nc6 Bc4 Bc5': 'ITALIANA: GIUOCO PIANO',
    'e4 e5 Nf3 Nc6 Bc4 Nf6': 'ITALIANA: DOIS CAVALOS',
    'e4 e5 Nf3 Nc6 Bc4': 'ITALIANA',
    'e4 e5 Nf3 Nc6 d4': 'ESCOCESA',
    'e4 e5 Nf3 d6': 'PHILIDOR',
    'e4 e5 Nf3 Nf6': 'PETROV',
    'e4 e5 Nc3 Nf6': 'VIENENSE',
    'e4 e5 Bc4': 'BISPO DO REI',
    'e4 e5': 'JOGO ABERTO',
    'e4 c5 Nf3 d6 d4': 'SICILIANA ABERTA',
    'e4 c5 Nf3 Nc6': 'SICILIANA: FECHADA?',
    'e4 c5 Nf3': 'SICILIANA',
    'e4 c5': 'SICILIANA',
    'e4 e6 d4 d5': 'FRANCESA',
    'e4 e6': 'FRANCESA',
    'e4 c6 d4 d5': 'CARO-KANN',
    'e4 c6': 'CARO-KANN',
    'e4 d5': 'ESCANDINAVA',
    'e4 d6': 'PIRC',
    'e4 g6': 'MODERNA',
    'e4 Nf6': "ALEKHINE",
    'd4 d5 c4 e6': 'GAMBITO DA DAMA DECLINADO',
    'd4 d5 c4 c6': 'GAMBITO DA DAMA: ESLAVA',
    'd4 d5 c4': 'GAMBITO DA DAMA',
    'd4 d5 Bf4': 'SISTEMA LONDRES',
    'd4 d5 Nf3': 'JOGO FECHADO',
    'd4 d5': 'JOGO FECHADO',
    'd4 Nf6 c4 e6 Nc3 Bb4': 'NIMZO-INDIA',
    'd4 Nf6 c4 e6': 'DEFESA INDIA',
    'd4 Nf6 c4 g6': 'INDIA DO REI',
    'd4 Nf6 c4': 'DEFESA INDIA',
    'd4 Nf6 Bf4': 'SISTEMA LONDRES',
    'd4 Nf6': 'DEFESA INDIA',
    'd4 f5': 'HOLANDESA',
    'c4': 'INGLESA',
    'Nf3 d5': 'RETI',
    'Nf3': 'RETI',
    'g3': "FIANCHETTO DO REI",
    'b3': 'LARSEN',
    'f4': 'BIRD',
    'Nc3': 'VAN GEET',
  };

  static ({String name, String key}) identify(List<String> sans) {
    final norm = sans.map(GameReviewService._normalizeSan).toList();
    var bestLen = 0;
    var bestKey = '';
    for (final entry in names.entries) {
      final line = entry.key.split(' ');
      if (line.length <= bestLen || line.length > norm.length) continue;
      var ok = true;
      for (var i = 0; i < line.length; i++) {
        if (GameReviewService._normalizeSan(line[i]) != norm[i]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        bestLen = line.length;
        bestKey = entry.key;
      }
    }
    if (bestKey.isEmpty) {
      return (name: 'FORA DO LIVRO', key: 'fora_do_livro');
    }
    final slug = bestKey
        .toLowerCase()
        .replaceAll(':', '')
        .replaceAll(RegExp(r'\s+'), '_');
    return (name: names[bestKey]!, key: slug);
  }
}
