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

  /// Perfil ajustado pela barrinha de força (250 → 2500, passo 50).
  /// [name] é só a identidade visual; a força real vem de [elo].
  factory BotProfile.tuned({required String name, required int elo}) {
    final e = elo.clamp(250, 2500);
    final t = (e - 250) / 2250; // 0.0 → 1.0
    return BotProfile(
      name: name,
      elo: e,
      // UCI_Elo do Stockfish opera entre 1320 e 3190.
      uciElo: (e + 200).clamp(1320, 3190),
      skillLevel: (t * 20).round().clamp(0, 20),
      moveTimeMs: (150 + t * 850).round(),
    );
  }
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
