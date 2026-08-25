class BotProfile {
  const BotProfile({
    required this.name,
    required this.elo,
    required this.uciElo,
    required this.skillLevel,
    required this.moveTimeMs,
  });

  final String name;
  final int elo;
  final int uciElo;
  final int skillLevel;
  final int moveTimeMs;
}

class BotRoster {
  BotRoster._();

  static const List<BotProfile> all = [
    BotProfile(name: 'PEAO', elo: 800, uciElo: 1320, skillLevel: 0, moveTimeMs: 200),
    BotProfile(name: 'CAVALO', elo: 1100, uciElo: 1350, skillLevel: 3, moveTimeMs: 250),
    BotProfile(name: 'BISPO', elo: 1400, uciElo: 1550, skillLevel: 7, moveTimeMs: 350),
    BotProfile(name: 'TORRE', elo: 1700, uciElo: 1850, skillLevel: 12, moveTimeMs: 500),
    BotProfile(name: 'DAMA', elo: 2000, uciElo: 2150, skillLevel: 16, moveTimeMs: 750),
    BotProfile(name: 'REI', elo: 2400, uciElo: 2850, skillLevel: 20, moveTimeMs: 1000),
  ];
}
