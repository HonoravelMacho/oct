class AppConstants {
  AppConstants._();

  static const int freeCycleLimit = 5;
  static const int tacticsPerCredit = 5;

  static const String appName = 'OCT';
  static const String appTagline = 'Offline Chess Training';
  static const String appTaglineUpper = 'OFFLINE CHESS TRAINING';

  static const bool useRealAds = false;

  static const String admobTestAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String admobTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';

  static const String lichessPuzzleDbUrl =
      'https://database.lichess.org/lichess_db_puzzle.csv.zst';

  static const int freeBaseTarget = 20000;
  static const String premiumTotalLabel = '6.000.000';

  static const String prefGameElo = 'stat_game_elo';
  static const String prefTacticElo = 'stat_tactic_elo';
  static const String prefGamesPlayed = 'stat_games_played';
  static const String prefTacticsSolved = 'stat_tactics_solved';
  static const String prefPremiumUnlocked = 'premium_unlocked';
}
