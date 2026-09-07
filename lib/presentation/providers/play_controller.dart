import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

import '../../core/app_constants.dart';
import '../../data/engine/chess_engine.dart';
import '../../domain/entities/bot_profile.dart';
import '../../domain/services/elo_service.dart';
import '../../domain/services/game_review_service.dart';
import '../../domain/services/win_chance_service.dart';
import 'session_provider.dart';

enum GamePhase { idle, playing, botThinking, finished }

class PlayController extends ChangeNotifier {
  PlayController(this._session);

  final SessionProvider _session;
  final LocalFallbackBot _rescueBot = LocalFallbackBot();

  ch.Chess game = ch.Chess();
  String botBaseName = BotRoster.all.first.name;
  int botRating = AppConstants.defaultBotElo;
  GamePhase phase = GamePhase.idle;
  String userColor = 'w';
  String? gameResult;
  int eloDelta = 0;
  int eloBefore = EloService.startingElo;
  int eloAfter = EloService.startingElo;
  List<String> historySan = <String>[];
  List<String> historyFen = <String>[];
  List<String> lastMoveSquares = <String>[];
  List<int> plyDurationsMs = <int>[];
  DateTime? _turnStart;

  bool reviewing = false;
  int reviewDone = 0;
  int reviewTotal = 0;
  int reviewDepthUsed = GameReviewService.reviewDepth;
  GameReview? gameReview;

  /// Chance de lance puramente casual (nível iniciante de verdade).
  /// 250 → 65% aleatório; 800 → ~27%; 1100+ → 0% (só motor limitado).
  static double casualChance(int elo) =>
      ((1100 - elo) / 1100).clamp(0, 0.65).toDouble();

  BotProfile get selectedBot =>
      BotProfile.tuned(name: botBaseName, elo: botRating);

  bool get isPlayerTurn =>
      phase == GamePhase.playing && _turnColor() == userColor;

  /// Chance de vitória do usuário (0..100) pelo material atual.
  double get userWinChance =>
      WinChance.probability(WinChance.materialDiff(game, userColor));

  /// Diferença de material do ponto de vista do usuário.
  int get userMaterialDiff => WinChance.materialDiff(game, userColor);

  /// Expectativa pré-partida (ELO OCT do usuário vs ELO do bot), 0..100.
  double get expectedScorePct =>
      EloService.expectedScore(_session.gameElo, selectedBot.elo) * 100;

  Future<void> ensureEngine() async {
    await _session.ensureEngine();
    notifyListeners();
  }

  void selectBot(String name) {
    if (phase == GamePhase.playing || phase == GamePhase.botThinking) return;
    botBaseName = name;
    notifyListeners();
  }

  void setBotRating(int elo) {
    if (phase == GamePhase.playing || phase == GamePhase.botThinking) return;
    final stepped =
        ((elo - AppConstants.minBotElo) ~/ AppConstants.botEloStep) *
                AppConstants.botEloStep +
            AppConstants.minBotElo;
    botRating = stepped.clamp(AppConstants.minBotElo, AppConstants.maxBotElo);
    notifyListeners();
  }

  void startNewGame() {
    game = ch.Chess();
    userColor = DateTime.now().millisecondsSinceEpoch % 2 == 0 ? 'w' : 'b';
    phase = GamePhase.playing;
    gameResult = null;
    eloDelta = 0;
    eloBefore = _session.gameElo;
    eloAfter = eloBefore;
    historySan.clear();
    historyFen = [game.fen];
    lastMoveSquares.clear();
    plyDurationsMs.clear();
    gameReview = null;
    reviewing = false;
    reviewDone = 0;
    reviewTotal = 0;
    _turnStart = DateTime.now();
    _session.consumeGameCredit();
    notifyListeners();

    if (_turnColor() != userColor) {
      _runBotTurn();
    }
  }

  bool humanMove(String from, String to) {
    if (!isPlayerTurn) return false;

    final piece = game.get(from);
    String? promotion;
    if (piece != null && piece.type == ch.Chess.PAWN) {
      final targetRank = to[1];
      if ((userColor == 'w' && targetRank == '8') ||
          (userColor == 'b' && targetRank == '1')) {
        promotion = 'q';
      }
    }

    final applied = game.move({'from': from, 'to': to, 'promotion': promotion});
    if (!applied) return false;

    _recordPly();
    lastMoveSquares = [from, to];
    notifyListeners();

    if (_checkGameEnd()) return true;
    _runBotTurn();
    return true;
  }

  void _recordPly() {
    final h = game.getHistory();
    historySan.add(h.isNotEmpty ? '${h.last}' : '?');
    historyFen.add(game.fen);
    final now = DateTime.now();
    if (_turnStart != null) {
      plyDurationsMs.add(now.difference(_turnStart!).inMilliseconds);
    } else {
      plyDurationsMs.add(0);
    }
    _turnStart = now;
  }

  void _runBotTurn() {
    phase = GamePhase.botThinking;
    notifyListeners();

    if (phase != GamePhase.botThinking) return;
    _botTurnAsync(game.fen, selectedBot);
  }

  Future<void> _botTurnAsync(String fen, BotProfile bot) async {
    await _session.configureEngine(bot);

    String? uci;
    if (math.Random().nextDouble() < casualChance(bot.elo)) {
      uci = await _rescueBot.randomMove(fen);
    } else {
      uci = await _session.activeEngine?.bestMove(fen: fen, profile: bot);
      if (uci == null || uci.isEmpty) {
        uci = await _rescueBot.bestMove(fen: fen, profile: bot);
      }
    }

      if (phase != GamePhase.botThinking) return;

      if (uci != null && uci.length >= 4) {
        final from = uci.substring(0, 2);
        final to = uci.substring(2, 4);
        final promo = uci.length > 4 ? uci[4] : null;
        final applied =
            game.move({'from': from, 'to': to, 'promotion': promo});
        if (applied) {
          _recordPly();
          lastMoveSquares = [from, to];
        }
      }
      if (_checkGameEnd()) return;
      phase = GamePhase.playing;
      notifyListeners();
  }

  bool _checkGameEnd() {
    if (!game.game_over) return false;
    finishGame();
    return true;
  }

  void finishGame() {
    if (phase == GamePhase.finished) return;
    phase = GamePhase.finished;

    String result;
    if (game.in_checkmate) {
      result = _turnColor() == userColor ? 'win' : 'loss';
    } else {
      result = 'draw';
    }
    gameResult = result;

    final delta = _session.applyGameResult(
      opponentRating: selectedBot.elo,
      userWon: result == 'win',
      draw: result == 'draw',
    );
    eloBefore = delta.oldRating;
    eloAfter = delta.newRating;
    eloDelta = delta.newRating - delta.oldRating;

    final opening = OpeningBook.identify(historySan);
    _session.stats.recordOpening(
      opening.key,
      result == 'win' ? 'w' : (result == 'loss' ? 'l' : 'd'),
    );
    notifyListeners();
  }

  void resetToIdle() {
    phase = GamePhase.idle;
    gameResult = null;
    notifyListeners();
  }

  // ---------- Análise pós-partida ----------

  int _capturesOf(String color) {
    var n = 0;
    for (var i = 0; i < historySan.length; i++) {
      final isWhiteMove = i % 2 == 0;
      if ((color == 'w') != isWhiteMove) continue;
      if (historySan[i].contains('x')) n++;
    }
    return n;
  }

  int _checksOf(String color) {
    var n = 0;
    for (var i = 0; i < historySan.length; i++) {
      final isWhiteMove = i % 2 == 0;
      if ((color == 'w') != isWhiteMove) continue;
      if (historySan[i].contains('+') || historySan[i].contains('#')) n++;
    }
    return n;
  }

  int get capturesWhite => _capturesOf('w');
  int get capturesBlack => _capturesOf('b');
  int get checksWhite => _checksOf('w');
  int get checksBlack => _checksOf('b');

  int get userCaptures => userColor == 'w' ? capturesWhite : capturesBlack;
  int get botCaptures => userColor == 'w' ? capturesBlack : capturesWhite;
  int get userChecks => userColor == 'w' ? checksWhite : checksBlack;
  int get botChecks => userColor == 'w' ? checksBlack : checksWhite;

  /// Índice do lance decisivo: último xeque-mate ou última captura.
  int get decisivePly {
    for (var i = historySan.length - 1; i >= 0; i--) {
      if (historySan[i].contains('#')) return i;
    }
    for (var i = historySan.length - 1; i >= 0; i--) {
      if (historySan[i].contains('x')) return i;
    }
    return historySan.isEmpty ? -1 : historySan.length - 1;
  }

  String get decisiveSan =>
      decisivePly >= 0 && decisivePly < historySan.length
          ? historySan[decisivePly]
          : '-';

  int get decisiveMoveNumber =>
      decisivePly >= 0 ? decisivePly ~/ 2 + 1 : 0;

  /// Balanço de material (brancas − pretas) ao longo dos lances, para o gráfico.
  List<int> materialTimeline() {
    final out = <int>[];
    for (final fen in historyFen) {
      try {
        final pos = ch.Chess.fromFEN(fen);
        final m = WinChance.materialOf(pos);
        out.add(m.white - m.black);
      } catch (_) {
        out.add(out.isEmpty ? 0 : out.last);
      }
    }
    return out;
  }

  // ---------- Ritmo de jogo ----------

  List<int> _pliesOf(bool human) {
    final out = <int>[];
    for (var i = 0; i < plyDurationsMs.length; i++) {
      final isWhiteMove = i % 2 == 0;
      final isHumanMove = (userColor == 'w') == isWhiteMove;
      if (isHumanMove == human) out.add(plyDurationsMs[i]);
    }
    return out;
  }

  double get humanAvgSeconds {
    final xs = _pliesOf(true);
    if (xs.isEmpty) return 0;
    return xs.reduce((a, b) => a + b) / xs.length / 1000;
  }

  ({int moveNumber, double seconds}) get humanSlowest {
    var best = 0;
    var bestIdx = -1;
    for (var i = 0; i < plyDurationsMs.length; i++) {
      final isWhiteMove = i % 2 == 0;
      if ((userColor == 'w') != isWhiteMove) continue;
      if (plyDurationsMs[i] > best) {
        best = plyDurationsMs[i];
        bestIdx = i;
      }
    }
    return (
      moveNumber: bestIdx >= 0 ? bestIdx ~/ 2 + 1 : 0,
      seconds: best / 1000
    );
  }

  // ---------- Revisão com o motor ----------

  Future<void> reviewGame({int? depth}) async {
    final d = depth ?? GameReviewService.reviewDepth;
    if (reviewing || historySan.isEmpty) return;
    if (gameReview != null && reviewDepthUsed == d) return;
    reviewing = true;
    reviewDone = 0;
    reviewTotal = historySan.length + 1;
    notifyListeners();

    Future<EngineEval?> evalFn(String fen) async {
      EngineEval? e;
      try {
        e = await _session.evaluatePosition(fen, d);
      } catch (_) {
        e = null;
      }
      reviewDone++;
      notifyListeners();
      return e;
    }

    try {
      gameReview = await GameReviewService.analyze(
        historySan: historySan,
        historyFen: historyFen,
        evalFn: evalFn,
        depth: d,
      );
      reviewDepthUsed = d;
    } catch (_) {
      gameReview = null;
    }
    reviewing = false;
    notifyListeners();
  }

  String _turnColor() => game.turn == ch.Color.WHITE ? 'w' : 'b';
}
