import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';

import '../../core/app_constants.dart';
import '../../data/engine/chess_engine.dart';
import '../../domain/entities/bot_profile.dart';
import '../../domain/services/elo_service.dart';
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
  }

  void _runBotTurn() {
    phase = GamePhase.botThinking;
    notifyListeners();

    if (phase != GamePhase.botThinking) return;
    _botTurnAsync(game.fen, selectedBot);
  }

  Future<void> _botTurnAsync(String fen, BotProfile bot) async {
    var uci =
          await _session.activeEngine?.bestMove(fen: fen, profile: bot);
      if (uci == null || uci.isEmpty) {
        uci = await _rescueBot.bestMove(fen: fen, profile: bot);
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

  String _turnColor() => game.turn == ch.Color.WHITE ? 'w' : 'b';
}
