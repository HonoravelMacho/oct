import 'dart:async';
import 'dart:math' as math;

import 'package:chess/chess.dart' as ch;

import '../../domain/entities/bot_profile.dart';

abstract class ChessEngine {
  String get engineName;
  Future<bool> start();
  Future<String?> bestMove({required String fen, required BotProfile profile});
  void dispose();
}

class LocalFallbackBot implements ChessEngine {
  final math.Random _rng = math.Random();

  @override
  String get engineName => 'BOT LOCAL';

  @override
  Future<bool> start() async => true;

  @override
  Future<String?> bestMove({
    required String fen,
    required BotProfile profile,
  }) async {
    final game = ch.Chess.fromFEN(fen);
    final moves =
        game.moves({'asObjects': true}).cast<ch.Move>();
    if (moves.isEmpty) return null;

    final blunderChance =
        ((2400 - profile.elo) / 2400).clamp(0.05, 0.75).toDouble();
    if (_rng.nextDouble() < blunderChance) {
      final m = moves[_rng.nextInt(moves.length)];
      return _toUci(m);
    }

    ch.Move? best;
    int bestScore = -1;
    for (final m in moves) {
      int score = 0;
      if (m.captured != null) {
        score += _pieceValue(m.captured!) * 10;
      }
      if (m.promotion != null) score += 80;
      game.move(m);
      if (game.in_checkmate) {
        game.undo_move();
        return _toUci(m);
      }
      if (game.in_check) score += 5;
      game.undo_move();
      score += _rng.nextInt(6);
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return best == null ? null : _toUci(best);
  }

  int _pieceValue(ch.PieceType pieceType) {
    switch (pieceType) {
      case ch.Chess.PAWN:
        return 1;
      case ch.Chess.KNIGHT:
        return 3;
      case ch.Chess.BISHOP:
        return 3;
      case ch.Chess.ROOK:
        return 5;
      case ch.Chess.QUEEN:
        return 9;
      default:
        return 0;
    }
  }

  String _toUci(ch.Move m) =>
      '${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ''}';

  @override
  void dispose() {}
}

class StockfishUciEngine implements ChessEngine {
  StockfishUciEngine({this.startupTimeout = const Duration(seconds: 8)});

  final Duration startupTimeout;
  dynamic _stockfish;
  StreamSubscription<String>? _stdoutSub;
  Completer<void>? _uciOkCompleter;
  Completer<String>? _bestMoveCompleter;

  @override
  String get engineName => 'STOCKFISH';

  @override
  Future<bool> start() async {
    try {
      final dynamic instance = await _createStockfish();
      _stockfish = instance;

      _stdoutSub = (instance.stdout as Stream<String>).listen(_onLine);

      final uciOk = Completer<void>();
      _uciOkCompleter = uciOk;
      _send('uci');

      await uciOk.future.timeout(startupTimeout, onTimeout: () {
        throw TimeoutException('stockfish uciok timeout');
      });

      _send('isready');
      _send('setoption name Threads value 2');
      _send('setoption name Hash value 32');
      return true;
    } catch (_) {
      dispose();
      return false;
    }
  }

  Future<dynamic> _createStockfish() async {
    final result = _stockfishFactory();
    if (result is Future) return await result;
    return result;
  }

  dynamic Function() _stockfishFactory = _defaultFactory;

  static dynamic _defaultFactory() {
    throw UnsupportedError(
        'Stockfish plugin unavailable; wire factory in bootstrap.');
  }

  void bindFactory(dynamic Function() factory) {
    _stockfishFactory = factory;
  }

  void _onLine(String line) {
    final l = line.trim();
    if (l.startsWith('uciok')) {
      _uciOkCompleter?.complete();
      _uciOkCompleter = null;
    } else if (l.startsWith('readyok')) {
      // handshake concluído
    } else if (l.startsWith('bestmove')) {
      final parts = l.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        _bestMoveCompleter?.complete(parts[1]);
        _bestMoveCompleter = null;
      }
    }
  }

  void _send(String command) {
    final instance = _stockfish;
    if (instance == null) return;
    instance.stdin = command;
  }

  @override
  Future<String?> bestMove({
    required String fen,
    required BotProfile profile,
  }) async {
    if (_stockfish == null) return null;
    final completer = Completer<String>();
    _bestMoveCompleter = completer;

    _send('setoption name Skill Level value ${profile.skillLevel}');
    if (profile.uciElo >= 1320 && profile.uciElo <= 2850) {
      _send('setoption name UCI_LimitStrength value true');
      _send('setoption name UCI_Elo value ${profile.uciElo}');
    } else {
      _send('setoption name UCI_LimitStrength value false');
    }
    _send('position fen $fen');
    _send('go movetime ${profile.moveTimeMs}');

    try {
      return await completer.future.timeout(
        Duration(milliseconds: profile.moveTimeMs + 4000),
        onTimeout: () => '',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _stdoutSub?.cancel();
    try {
      _stockfish?.dispose();
    } catch (_) {}
    _stockfish = null;
  }
}
