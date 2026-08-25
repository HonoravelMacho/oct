import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_constants.dart';
import '../../domain/services/elo_service.dart';
import '../../domain/services/usage_limit_service.dart';

class PrefsCounterStore implements CounterStore {
  PrefsCounterStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  int read(String key) => _prefs.getInt(key) ?? 0;

  @override
  void write(String key, int value) => _prefs.setInt(key, value);
}

class StatsRepository {
  StatsRepository(this._prefs);

  final SharedPreferences _prefs;

  late final UsageLimitService usage = UsageLimitService(
    PrefsCounterStore(_prefs),
    freeCycleLimit: AppConstants.freeCycleLimit,
    tacticsPerCredit: AppConstants.tacticsPerCredit,
  );

  void initializeDefaults() {
    if (!_prefs.containsKey(AppConstants.prefGameElo)) {
      _prefs.setInt(AppConstants.prefGameElo, EloService.startingElo);
    }
    if (!_prefs.containsKey(AppConstants.prefTacticElo)) {
      _prefs.setInt(AppConstants.prefTacticElo, EloService.startingElo);
    }
    usage.initializeIfNeeded();
  }

  int get gameElo => _prefs.getInt(AppConstants.prefGameElo) ?? EloService.startingElo;

  int get tacticElo =>
      _prefs.getInt(AppConstants.prefTacticElo) ?? EloService.startingElo;

  int get gamesPlayed => _prefs.getInt(AppConstants.prefGamesPlayed) ?? 0;

  int get tacticsSolvedTotal =>
      _prefs.getInt(AppConstants.prefTacticsSolved) ?? 0;

  bool get premiumUnlocked =>
      _prefs.getBool(AppConstants.prefPremiumUnlocked) ?? false;

  void setPremiumUnlocked(bool value) =>
      _prefs.setBool(AppConstants.prefPremiumUnlocked, value);

  ({int oldRating, int newRating}) applyGameResult({
    required int opponentRating,
    required bool userWon,
    required bool draw,
  }) {
    final current = gameElo;
    final score = EloService.scoreForResult(userWon: userWon, draw: draw);
    final next = EloService.updatedRating(
      currentRating: current,
      opponentRating: opponentRating,
      score: score,
      gamesPlayed: gamesPlayed,
    );
    _prefs.setInt(AppConstants.prefGameElo, next);
    _prefs.setInt(AppConstants.prefGamesPlayed, gamesPlayed + 1);
    return (oldRating: current, newRating: next);
  }

  ({int oldRating, int newRating}) applyTacticResult({
    required int puzzleRating,
    required bool solved,
  }) {
    final current = tacticElo;
    final next = EloService.updatedRating(
      currentRating: current,
      opponentRating: puzzleRating,
      score: solved ? 1 : 0,
      gamesPlayed: (tacticsSolvedTotal ~/ 3),
    );
    if (solved) {
      _prefs.setInt(AppConstants.prefTacticsSolved, tacticsSolvedTotal + 1);
    }
    _prefs.setInt(AppConstants.prefTacticElo, next);
    return (oldRating: current, newRating: next);
  }
}
