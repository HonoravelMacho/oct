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

/// Avaliação de uma posição pelo motor (sempre relativa a quem tem a vez).
class EngineEval {
  const EngineEval({this.cp, this.mate, this.bestMove, required this.depth});

  /// Vantagem em centipawns (quando não há mate).
  final int? cp;

  /// Mate em N lances: positivo = quem tem a vez dá mate, negativo = recebe.
  final int? mate;

  /// Melhor lance (primeiro da PV) na notação UCI, quando disponível.
  final String? bestMove;
  final int depth;
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

  /// Lance uniformemente aleatório (comportamento de iniciante absoluto).
  Future<String?> randomMove(String fen) async {
    final game = ch.Chess.fromFEN(fen);
    final moves =
        game.moves({'asObjects': true}).cast<ch.Move>();
    if (moves.isEmpty) return null;
    return _toUci(moves[_rng.nextInt(moves.length)]);
  }

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
  Completer<EngineEval>? _evalCompleter;
  int _evalDepth = 0;
  int? _evalCp;
  int? _evalMate;
  String? _evalBestMove;

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
    } else if (l.startsWith('info ') && _evalCompleter != null) {
      _parseEvalInfo(l);
    } else if (l.startsWith('bestmove')) {
      final parts = l.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        _bestMoveCompleter?.complete(parts[1]);
        _bestMoveCompleter = null;
      }
      final evalCompleter = _evalCompleter;
      if (evalCompleter != null && !evalCompleter.isCompleted) {
        evalCompleter.complete(EngineEval(
          cp: _evalCp,
          mate: _evalMate,
          bestMove: _evalBestMove,
          depth: _evalDepth,
        ));
      }
      _evalCompleter = null;
    }
  }

  static final RegExp _depthRe = RegExp(r'\bdepth (\d+)\b');
  static final RegExp _scoreRe = RegExp(r'\bscore (cp|mate) (-?\d+)\b');
  static final RegExp _pvRe = RegExp(r'\bpv (\S+)');

  void _parseEvalInfo(String line) {
    final depthMatch = _depthRe.firstMatch(line);
    if (depthMatch == null || int.parse(depthMatch.group(1)!) != _evalDepth) {
      return;
    }
    final scoreMatch = _scoreRe.firstMatch(line);
    if (scoreMatch != null) {
      final value = int.parse(scoreMatch.group(2)!);
      if (scoreMatch.group(1) == 'cp') {
        _evalCp = value;
        _evalMate = null;
      } else {
        _evalMate = value;
        _evalCp = null;
      }
    }
    final pvMatch = _pvRe.firstMatch(line);
    if (pvMatch != null) _evalBestMove = pvMatch.group(1);
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

    _applyStrength(profile);
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

  /// Aplica a força do bot no motor (idempotente; o UCI processa em ordem).
  void setStrength(BotProfile profile) {
    if (_stockfish == null) return;
    _applyStrength(profile);
  }

  void _applyStrength(BotProfile profile) {
    _send('setoption name Skill Level value ${profile.skillLevel}');
    if (profile.uciElo >= 1320 && profile.uciElo <= 3190) {
      _send('setoption name UCI_LimitStrength value true');
      _send('setoption name UCI_Elo value ${profile.uciElo}');
    } else {
      _send('setoption name UCI_LimitStrength value false');
    }
  }

  /// Avalia [fen] com busca de profundidade fixa. Retorna o placar relativo
  /// a quem tem a vez + o melhor lance da PV. Null se o motor falhar.
  Future<EngineEval?> evaluate({required String fen, required int depth}) async {
    if (_stockfish == null) return null;
    final completer = Completer<EngineEval>();
    _evalCompleter = completer;
    _evalDepth = depth;
    _evalCp = null;
    _evalMate = null;
    _evalBestMove = null;

    _send('position fen $fen');
    _send('go depth $depth');

    try {
      final eval = await completer.future.timeout(
        const Duration(seconds: 12),
        onTimeout: () => EngineEval(cp: 0, depth: depth),
      );
      if (eval.cp == null && eval.mate == null) return null;
      return eval;
    } catch (_) {
      _evalCompleter = null;
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
