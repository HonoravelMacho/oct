import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_constants.dart';
import '../../domain/services/elo_service.dart';
import '../../domain/services/game_review_service.dart';
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

  /// Versão completa = base massiva baixada (antes chamado "premium").
  /// Mantido o nome do getter legado como apelido para não quebrar telas.
  bool get fullBaseInstalled =>
      _prefs.getBool(AppConstants.prefFullBaseInstalled) ??
      premiumUnlocked;

  void setPremiumUnlocked(bool value) {
    _prefs.setBool(AppConstants.prefPremiumUnlocked, value);
    _prefs.setBool(AppConstants.prefFullBaseInstalled, value);
  }

  void setFullBaseInstalled(bool value) {
    _prefs.setBool(AppConstants.prefFullBaseInstalled, value);
    if (value) _prefs.setBool(AppConstants.prefPremiumUnlocked, true);
  }

  /// Histórico pessoal por abertura (chave slug): vitórias/empates/derrotas.
  void recordOpening(String key, String result) {
    final suffix = result == 'w' ? 'w' : (result == 'l' ? 'l' : 'd');
    final pref = 'opening_${key}_$suffix';
    _prefs.setInt(pref, (_prefs.getInt(pref) ?? 0) + 1);
  }

  ({int w, int d, int l}) openingStats(String key) => (
        w: _prefs.getInt('opening_${key}_w') ?? 0,
        d: _prefs.getInt('opening_${key}_d') ?? 0,
        l: _prefs.getInt('opening_${key}_l') ?? 0,
      );

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
    // Resultado agregado para o dashboard.
    if (draw) {
      _prefs.setInt(_kDraws, draws + 1);
    } else if (userWon) {
      _prefs.setInt(_kWins, wins + 1);
    } else {
      _prefs.setInt(_kLosses, losses + 1);
    }
    // Histórico de rating (últimas 60 partidas) para gráfico/evolução.
    final hist = ratingHistory;
    hist.add(next);
    while (hist.length > 60) {
      hist.removeAt(0);
    }
    _prefs.setStringList(_kRatingHist, hist.map((e) => '$e').toList());
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

  // ---------- Dashboard / laboratório offline ----------

  static const String _kWins = 'dash_wins';
  static const String _kLosses = 'dash_losses';
  static const String _kDraws = 'dash_draws';
  static const String _kRatingHist = 'dash_rating_hist';
  static const String _kAccSum = 'dash_acc_sum';
  static const String _kAccN = 'dash_acc_n';
  static const String _kBestAcc = 'dash_best_acc';
  static const String _kReviews = 'dash_reviews';

  int get wins => _prefs.getInt(_kWins) ?? 0;
  int get losses => _prefs.getInt(_kLosses) ?? 0;
  int get draws => _prefs.getInt(_kDraws) ?? 0;
  int get reviewsCount => _prefs.getInt(_kReviews) ?? 0;

  List<int> get ratingHistory {
    final raw = _prefs.getStringList(_kRatingHist) ?? const [];
    return [for (final s in raw) int.tryParse(s) ?? EloService.startingElo];
  }

  double get avgAccuracy {
    final n = _prefs.getInt(_kAccN) ?? 0;
    if (n == 0) return 0;
    final sum = _prefs.getDouble(_kAccSum) ?? 0;
    return sum / n;
  }

  double get bestAccuracy => _prefs.getDouble(_kBestAcc) ?? 0;

  /// Contadores agregados de etiquetas dos lances do usuário.
  Map<String, int> labelTotals() {
    final out = <String, int>{};
    for (final l in MoveLabel.values) {
      out[l.name] = _prefs.getInt('dash_label_${l.name}') ?? 0;
    }
    return out;
  }

  /// Médias agregadas por fase (0..100). Null = sem dados.
  ({double? abertura, double? meio, double? fim, double? tatica})
      skillAverages() {
    double? avg(String sumK, String nK) {
      final n = _prefs.getInt(nK) ?? 0;
      if (n == 0) return null;
      return ((_prefs.getDouble(sumK) ?? 0) / n);
    }

    return (
      abertura: avg('dash_skill_ab_sum', 'dash_skill_ab_n'),
      meio: avg('dash_skill_meio_sum', 'dash_skill_meio_n'),
      fim: avg('dash_skill_fim_sum', 'dash_skill_fim_n'),
      tatica: avg('dash_skill_tat_sum', 'dash_skill_tat_n'),
    );
  }

  /// Chamado ao concluir a revisão de uma partida: acumula precisão,
  /// etiquetas e habilidades do usuário para o dashboard.
  void recordGameReview({
    required bool userWhite,
    required GameReview review,
  }) {
    final acc = userWhite ? review.accuracyWhite : review.accuracyBlack;
    final counts = userWhite ? review.countsWhite : review.countsBlack;
    final skills = userWhite ? review.skillsWhite : review.skillsBlack;

    final n = (_prefs.getInt(_kAccN) ?? 0) + 1;
    _prefs.setInt(_kAccN, n);
    _prefs.setDouble(_kAccSum, (_prefs.getDouble(_kAccSum) ?? 0) + acc);
    final best = bestAccuracy;
    if (acc > best) _prefs.setDouble(_kBestAcc, acc);
    _prefs.setInt(_kReviews, reviewsCount + 1);

    for (final e in counts.entries) {
      final k = 'dash_label_${e.key.name}';
      _prefs.setInt(k, (_prefs.getInt(k) ?? 0) + e.value);
    }
    void accSkill(String sumK, String nK, double? v) {
      if (v == null) return;
      _prefs.setDouble(sumK, (_prefs.getDouble(sumK) ?? 0) + v);
      _prefs.setInt(nK, (_prefs.getInt(nK) ?? 0) + 1);
    }

    accSkill('dash_skill_ab_sum', 'dash_skill_ab_n', skills.abertura);
    accSkill('dash_skill_meio_sum', 'dash_skill_meio_n', skills.meioJogo);
    accSkill('dash_skill_fim_sum', 'dash_skill_fim_n', skills.finalJogo);
    accSkill('dash_skill_tat_sum', 'dash_skill_tat_n', skills.tatica);
  }
}
