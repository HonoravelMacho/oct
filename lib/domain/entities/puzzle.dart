class Puzzle {
  const Puzzle({
    required this.id,
    required this.fen,
    required this.movesUci,
    required this.rating,
    required this.themes,
    required this.primaryTheme,
    this.premium = false,
  });

  final String id;
  final String fen;
  final List<String> movesUci;
  final int rating;
  final List<String> themes;
  final String primaryTheme;
  final bool premium;

  Map<String, Object?> toRow() => {
        'id': id,
        'fen': fen,
        'moves': movesUci.join(' '),
        'rating': rating,
        'themes': themes.join(','),
        'primary_theme': primaryTheme,
        'tier': premium ? 'premium' : 'free',
      };

  static Puzzle fromRow(Map<String, Object?> row) => Puzzle(
        id: row['id'] as String,
        fen: row['fen'] as String,
        movesUci: (row['moves'] as String).split(' ').where((m) => m.isNotEmpty).toList(),
        rating: row['rating'] as int,
        themes: (row['themes'] as String)
            .split(',')
            .where((t) => t.isNotEmpty)
            .toList(),
        primaryTheme: row['primary_theme'] as String,
        premium: (row['tier'] as String? ?? 'free') == 'premium',
      );

  static Puzzle? fromJsonMap(Map<String, dynamic> map) {
    final fen = map['fen'];
    final movesRaw = map['moves'];
    if (fen is! String || movesRaw is! String || fen.isEmpty) return null;
    final moves =
        movesRaw.split(' ').where((m) => m.length >= 4).toList();
    if (moves.isEmpty) return null;
    final themesRaw = map['themes'];
    final themes = (themesRaw is String && themesRaw.isNotEmpty)
        ? themesRaw.split(',')
        : <String>['misc'];
    return Puzzle(
      id: (map['id'] as String?) ?? 'p_${fen.hashCode}',
      fen: fen,
      movesUci: moves,
      rating: (map['rating'] as num?)?.toInt() ?? 1500,
      themes: themes,
      primaryTheme: PuzzleCatalog.primaryOf(themes),
      premium: map['tier'] == 'premium',
    );
  }
}

class ThemeProgress {
  const ThemeProgress({
    required this.theme,
    required this.total,
    required this.solved,
  });

  final String theme;
  final int total;
  final int solved;

  double get percent => total == 0 ? 0 : solved / total * 100;
}

class PuzzleCatalog {
  PuzzleCatalog._();

  static const Map<String, String> labels = {
    'mateIn1': 'Mate em 1',
    'mateIn2': 'Mate em 2',
    'mateIn3': 'Mate em 3',
    'mateIn4': 'Mate em 4',
    'mateIn5': 'Mate em 5',
    'backRankMate': 'Mate da última fileira',
    'smotheredMate': 'Mate sufocado',
    'fork': 'Garfo (Fork)',
    'pin': 'Cravada (Pin)',
    'skewer': 'Espeto (Skewer)',
    'discoveredAttack': 'Ataque à descoberta',
    'doubleCheck': 'Xeque duplo',
    'hangingPiece': 'Peça pendurada',
    'sacrifice': 'Sacrifício',
    'deflection': 'Desvio',
    'attraction': 'Atração',
    'promotion': 'Promoção',
    'underPromotion': 'Sub-promoção',
    'advancedPawn': 'Peão avançado',
    'kingsideAttack': 'Ataque no rei',
    'queensideAttack': 'Ataque na dama',
    'trappingPiece': 'Peça presa',
    'quietMove': 'Lance silencioso',
    'interception': 'Interceptação',
    'clearance': 'Liberação de casa',
    'enPassant': 'En passant',
    'castling': 'Roque',
    'endgame': 'Finais',
    'middlegame': 'Meio-jogo',
    'opening': 'Aberturas',
    'rookEndgame': 'Finais de torre',
    'pawnEndgame': 'Finais de peão',
    'bishopEndgame': 'Finais de bispo',
    'queenEndgame': 'Finais de dama',
    'knightEndgame': 'Finais de cavalo',
    'zugzwang': 'Zugzwang',
    'stalemate': 'Afogamento',
    'crushing': 'Vantagem decisiva',
    'master': 'Partidas de mestres',
  };

  static const List<String> priority = [
    'underPromotion',
    'smotheredMate',
    'backRankMate',
    'mateIn1',
    'mateIn2',
    'mateIn3',
    'mateIn4',
    'mateIn5',
    'doubleCheck',
    'discoveredAttack',
    'fork',
    'pin',
    'skewer',
    'hangingPiece',
    'sacrifice',
    'deflection',
    'attraction',
    'trappingPiece',
    'quietMove',
    'interception',
    'clearance',
    'promotion',
    'advancedPawn',
    'kingsideAttack',
    'queensideAttack',
    'enPassant',
    'castling',
    'zugzwang',
    'stalemate',
    'rookEndgame',
    'pawnEndgame',
    'bishopEndgame',
    'queenEndgame',
    'knightEndgame',
    'crushing',
    'endgame',
    'middlegame',
    'opening',
    'master',
  ];

  static String labelOf(String theme) => labels[theme] ?? theme;

  static String primaryOf(List<String> themes) {
    for (final p in priority) {
      if (themes.contains(p)) return p;
    }
    return themes.isEmpty ? 'misc' : themes.first;
  }
}
