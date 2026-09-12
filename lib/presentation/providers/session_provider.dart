import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ads/ad_flow.dart';
import '../../data/db/oct_database.dart';
import '../../data/datasources/puzzle_asset_source.dart';
import '../../data/engine/chess_engine.dart';
import '../../data/engine/stockfish_bootstrap.dart';
import '../../data/repositories/stats_repository.dart';
import '../../domain/entities/bot_profile.dart';
import '../../domain/services/game_review_service.dart';

class SessionProvider extends ChangeNotifier {
  SessionProvider(this._prefs) {
    _stats = StatsRepository(_prefs);
    _stats.initializeDefaults();
  }

  final SharedPreferences _prefs;
  late final StatsRepository _stats;

  OctDatabase? _db;
  bool dbReady = false;
  String dbStatusMessage = 'Preparando banco de taticas...';

  ChessEngine? _engine;
  ChessEngine? get activeEngine => _engine;
  bool get engineReady => _engine != null;
  String get engineName => _engine?.engineName ?? '...';

  StatsRepository get stats => _stats;

  /// App 100% gratuito: sem créditos, sem anúncios, sem paywall.
  /// [premiumUnlocked] virou apelido de "versão completa instalada".
  bool get premiumUnlocked => _stats.fullBaseInstalled;
  bool get fullBaseInstalled => _stats.fullBaseInstalled;
  int get creditsRemaining => -1;
  bool get canStartActivity => true;
  int get gameElo => _stats.gameElo;
  int get tacticElo => _stats.tacticElo;

  Future<void> initDatabase() async {
    if (dbReady) return;
    try {
      final db = await OctDatabase.open();
      _db = db;
      if (!await db.isFreeSeeded()) {
        final puzzles =
            await const PuzzleAssetSource().loadFreePuzzles();
        await db.insertPuzzles(puzzles);
        await db.markFreeSeeded();
      }
      dbReady = true;
      dbStatusMessage = 'Base gratuita pronta';
    } catch (e) {
      dbStatusMessage = 'Erro ao preparar banco: $e';
    }
    notifyListeners();
  }

  Future<void> ensureEngine() async {
    if (_engine != null) return;
    final sf = createStockfishEngine();
    final ok = await sf.start();
    _engine = ok ? sf : createFallbackEngine();
    notifyListeners();
  }

  bool get usingStockfish => _engine is StockfishUciEngine;

  /// Garante a força do bot no motor antes da busca (ordem preservada no UCI).
  Future<void> configureEngine(BotProfile profile) async {
    final engine = _engine;
    if (engine is StockfishUciEngine) {
      engine.setStrength(profile);
      await Future<void>.delayed(Duration.zero);
    }
  }

  /// Avaliação pontual para a revisão da partida. Null sem Stockfish.
  Future<EngineEval?> evaluatePosition(String fen, int depth) {
    final engine = _engine;
    if (engine is StockfishUciEngine) {
      return engine.evaluate(fen: fen, depth: depth);
    }
    return Future.value(null);
  }

  OctDatabase? get db => _db;

  /// Injeção apenas para testes de fluxo (evita o caminho do singleton).
  @visibleForTesting
  void setDbForTesting(OctDatabase db) {
    _db = db;
    dbReady = true;
  }

  bool consumeGameCredit() {
    // 100% gratuito: nunca bloqueia.
    return true;
  }

  void grantRewardCycle() {
    _stats.usage.grantRewardCycle();
    notifyListeners();
  }

  void setPremiumUnlocked(bool value) {
    _stats.setFullBaseInstalled(value);
    notifyListeners();
  }

  void setFullBaseInstalled(bool value) {
    _stats.setFullBaseInstalled(value);
    notifyListeners();
  }

  void recordGameReview({
    required bool userWhite,
    required GameReview review,
  }) {
    try {
      _stats.recordGameReview(userWhite: userWhite, review: review);
    } catch (_) {}
    notifyListeners();
  }

  ({int oldRating, int newRating}) applyGameResult({
    required int opponentRating,
    required bool userWon,
    required bool draw,
  }) {
    final result = _stats.applyGameResult(
      opponentRating: opponentRating,
      userWon: userWon,
      draw: draw,
    );
    notifyListeners();
    return result;
  }

  ({int oldRating, int newRating}) applyTacticResult({
    required int puzzleRating,
    required bool solved,
  }) {
    final result = _stats.applyTacticResult(
      puzzleRating: puzzleRating,
      solved: solved,
    );
    notifyListeners();
    return result;
  }

  bool consumeTacticCredit() {
    // 100% gratuito: táticas nunca consomem crédito.
    return false;
  }

  void refresh() => notifyListeners();

  Future<bool> showRewardedFlow(BuildContext context) {
    return AdFlow.showRewardedForCredits(context);
  }

  @override
  void dispose() {
    _engine?.dispose();
    super.dispose();
  }
}
