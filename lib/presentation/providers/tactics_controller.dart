import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';

import '../../domain/entities/puzzle.dart';
import 'session_provider.dart';

enum TacticMode { themes, solving }

enum TacticFeedback { none, correct, correctContinue, wrong, solved, revealed, exhausted }

class TacticsController extends ChangeNotifier {
  TacticsController(this._session);

  final SessionProvider _session;

  TacticMode mode = TacticMode.themes;
  List<ThemeProgress> themeProgressList = [];
  ThemeProgress overall = const ThemeProgress(theme: 'ALL', total: 0, solved: 0);

  Puzzle? currentPuzzle;
  ch.Chess board = ch.Chess();
  int solutionIndex = 0;
  int wrongAttempts = 0;
  TacticFeedback feedback = TacticFeedback.none;
  String lastExpectedUci = '';
  String selectedTheme = '';
  int sessionSolved = 0;
  bool loadingNext = false;
  List<String> lastMoveSquares = <String>[];

  String? hintFrom;
  int hintsUsed = 0;
  bool autoSolving = false;
  int _solveGen = 0;

  /// Últimos exercícios exibidos: o PRÓXIMA nunca os repete em seguida.
  final List<String> _recentIds = [];
  static const int _recentCap = 50;

  List<String> lastMoveSquaresForBoard() => lastMoveSquares;

  bool get premiumUnlocked => _session.premiumUnlocked;

  Future<void> refreshProgress() async {
    final db = _session.db;
    if (db == null) return;
    themeProgressList = await db.themeProgress();
    overall = await db.overallProgress();
    notifyListeners();
  }

  Future<bool> openTheme(String theme) async {
    selectedTheme = theme;
    mode = TacticMode.solving;
    _recentIds.clear();
    notifyListeners();
    return loadNextPuzzle();
  }

  Future<bool> loadNextPuzzle() async {
    final db = _session.db;
    if (db == null) return false;
    loadingNext = true;
    feedback = TacticFeedback.none;
    hintFrom = null;
    autoSolving = false;
    _solveGen++;
    notifyListeners();

    final puzzle = await _pickFresh();
    loadingNext = false;
    if (puzzle == null) {
      currentPuzzle = null;
      feedback = TacticFeedback.exhausted;
      notifyListeners();
      return false;
    }

    _recentIds.add(puzzle.id);
    if (_recentIds.length > _recentCap) {
      _recentIds.removeRange(0, _recentIds.length - _recentCap);
    }
    currentPuzzle = puzzle;
    board = ch.Chess.fromFEN(puzzle.fen);
    solutionIndex = 0;
    wrongAttempts = 0;
    lastExpectedUci = puzzle.movesUci.isEmpty ? '' : puzzle.movesUci.first;
    feedback = TacticFeedback.none;
    notifyListeners();
    return true;
  }

  /// Sorteia evitando os recentes; em tema pequeno, evita ao menos o atual.
  Future<Puzzle?> _pickFresh() async {
    final db = _session.db;
    if (db == null) return null;
    final fresh = await db.pickPuzzle(
      theme: selectedTheme,
      excludeIds: _recentIds,
    );
    if (fresh != null) return fresh;
    final currentId = currentPuzzle?.id;
    return db.pickPuzzle(
      theme: selectedTheme,
      excludeIds: currentId == null ? const [] : [currentId],
    );
  }

  bool tryHumanMove(String from, String to, String? promotion) {
    final puzzle = currentPuzzle;
    if (puzzle == null || solutionIndex >= puzzle.movesUci.length) {
      return false;
    }
    if (autoSolving) return false;

    final expected = puzzle.movesUci[solutionIndex];
    final attemptUci = '$from$to${promotion ?? ''}'.toLowerCase();
    final expectedNorm = expected.toLowerCase();

    final legalTargets = <String>{};
    for (final mv in board
        .moves({'asObjects': true})
        .cast<ch.Move>()) {
      legalTargets.add('${mv.fromAlgebraic}${mv.toAlgebraic}');
    }
    if (!legalTargets.contains('$from$to')) return false;

    if (attemptUci.substring(0, 4) != expectedNorm.substring(0, 4)) {
      wrongAttempts++;
      feedback = TacticFeedback.wrong;
      notifyListeners();
      return false;
    }

    final promoChar =
        promotion ?? (expectedNorm.length > 4 ? expectedNorm[4] : 'q');
    final applied = applySolutionMove(from, to, promoChar);
    if (!applied) {
      wrongAttempts++;
      feedback = TacticFeedback.wrong;
      notifyListeners();
      return false;
    }
    solutionIndex++;
    lastMoveSquares = [from, to];

    if (solutionIndex >= puzzle.movesUci.length) {
      _onPuzzleCompleted(puzzle);
      return true;
    }

    feedback = TacticFeedback.correctContinue;
    notifyListeners();
    _scheduleOpponentReply(puzzle);
    return true;
  }

  bool applySolutionMove(String from, String to, String? promotion) {
    return board.move({
      'from': from,
      'to': to,
      'promotion': (promotion == null || promotion.isEmpty) ? 'q' : promotion,
    });
  }

  void _scheduleOpponentReply(Puzzle puzzle) {
    Timer(const Duration(milliseconds: 450), () {
      if (solutionIndex >= puzzle.movesUci.length ||
          currentPuzzle?.id != puzzle.id) {
        return;
      }
      final reply = puzzle.movesUci[solutionIndex];
      final applied = applySolutionMove(
        reply.substring(0, 2),
        reply.substring(2, 4),
        reply.length > 4 ? reply[4] : null,
      );
      if (applied) {
        lastMoveSquares = [reply.substring(0, 2), reply.substring(2, 4)];
        solutionIndex++;
        if (solutionIndex >= puzzle.movesUci.length) {
          _onPuzzleCompleted(puzzle);
          return;
        }
      }
      lastExpectedUci = puzzle.movesUci[solutionIndex];
      feedback = TacticFeedback.none;
      notifyListeners();
    });
  }

  void _onPuzzleCompleted(Puzzle puzzle) {
    feedback = TacticFeedback.solved;
    hintFrom = null;
    sessionSolved++;
    _session.db?.recordAttempt(puzzle.id, true);
    _session.applyTacticResult(puzzleRating: puzzle.rating, solved: true);
    _session.consumeTacticCredit();
    notifyListeners();
  }

  Future<void> skipPuzzle() async {
    final puzzle = currentPuzzle;
    if (puzzle != null && feedback != TacticFeedback.solved) {
      await _session.db?.recordAttempt(puzzle.id, false);
    }
    await loadNextPuzzle();
  }

  /// Dica: destaca a casa de origem do próximo lance da solução.
  void showHint() {
    final puzzle = currentPuzzle;
    if (puzzle == null || autoSolving) return;
    if (solutionIndex >= puzzle.movesUci.length) return;
    if (feedback == TacticFeedback.solved ||
        feedback == TacticFeedback.revealed) {
      return;
    }
    hintFrom = puzzle.movesUci[solutionIndex].substring(0, 2);
    hintsUsed++;
    notifyListeners();
  }

  /// Avança automaticamente até a resolução, mostrando a sequência.
  /// Não conta como resolvida: não dá ELO nem consome/gasta crédito.
  Future<void> autoSolve() async {
    final puzzle = currentPuzzle;
    if (puzzle == null || autoSolving || mode != TacticMode.solving) return;
    if (solutionIndex >= puzzle.movesUci.length) return;
    autoSolving = true;
    hintFrom = null;
    final myGen = _solveGen;
    notifyListeners();

    bool alive() => myGen == _solveGen && identical(currentPuzzle, puzzle);

    while (solutionIndex < puzzle.movesUci.length) {
      final mv = puzzle.movesUci[solutionIndex];
      final ok = applySolutionMove(
        mv.substring(0, 2),
        mv.substring(2, 4),
        mv.length > 4 ? mv[4] : null,
      );
      if (!ok || !alive()) {
        autoSolving = false;
        notifyListeners();
        return;
      }
      lastMoveSquares = [mv.substring(0, 2), mv.substring(2, 4)];
      solutionIndex++;
      lastExpectedUci = solutionIndex < puzzle.movesUci.length
          ? puzzle.movesUci[solutionIndex]
          : '';
      feedback = TacticFeedback.correctContinue;
      notifyListeners();
      if (solutionIndex >= puzzle.movesUci.length) break;
      await Future.delayed(const Duration(milliseconds: 550));
      if (!alive()) {
        autoSolving = false;
        return;
      }
    }

    await _session.db?.recordAttempt(puzzle.id, false);
    feedback = TacticFeedback.revealed;
    autoSolving = false;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!alive()) return;
    await loadNextPuzzle();
  }

  void backToThemes() {
    mode = TacticMode.themes;
    currentPuzzle = null;
    refreshProgress();
    notifyListeners();
  }

  double themePercent(String theme) {
    for (final tp in themeProgressList) {
      if (tp.theme == theme) return tp.percent;
    }
    return 0;
  }
}
