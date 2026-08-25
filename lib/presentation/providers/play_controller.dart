import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';

import '../../data/engine/chess_engine.dart';
import '../../domain/entities/bot_profile.dart';
import 'session_provider.dart';

enum GamePhase { idle, playing, botThinking, finished }

class PlayController extends ChangeNotifier {
  PlayController(this._session);

  final SessionProvider _session;
  final LocalFallbackBot _rescueBot = LocalFallbackBot();

  ch.Chess game = ch.Chess();
  BotProfile selectedBot = BotRoster.all.first;
  GamePhase phase = GamePhase.idle;
  String userColor = 'w';
  String? gameResult;
  int eloDelta = 0;
  List<String> historySan = <String>[];
  List<String> lastMoveSquares = <String>[];

  bool get isPlayerTurn =>
      phase == GamePhase.playing && _turnColor() == userColor;

  Future<void> ensureEngine() async {
    await _session.ensureEngine();
    notifyListeners();
  }

  void selectBot(BotProfile profile) {
    if (phase == GamePhase.playing || phase == GamePhase.botThinking) return;
    selectedBot = profile;
    notifyListeners();
  }

  void startNewGame() {
    game = ch.Chess();
    userColor = DateTime.now().millisecondsSinceEpoch % 2 == 0 ? 'w' : 'b';
    phase = GamePhase.playing;
    gameResult = null;
    eloDelta = 0;
    historySan.clear();
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

    historySan.add('$from$to${promotion ?? ''}');
    lastMoveSquares = [from, to];
    notifyListeners();

    if (_checkGameEnd()) return true;
    _runBotTurn();
    return true;
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
          historySan.add('$from$to$promo');
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
    eloDelta = delta.newRating - delta.oldRating;
    notifyListeners();
  }

  void resetToIdle() {
    phase = GamePhase.idle;
    gameResult = null;
    notifyListeners();
  }

  String _turnColor() => game.turn == ch.Color.WHITE ? 'w' : 'b';
}
