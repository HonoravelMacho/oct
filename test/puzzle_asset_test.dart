import 'dart:convert';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Garante a qualidade da base gratuita embarcada (dados reais do Lichess):
/// volume, posições únicas, cobertura de temas e lances jogáveis (amostra).
void main() {
  test('base gratuita: 20k táticas únicas, temáticas e jogáveis', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/data/puzzles_free.json');
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    expect(list.length, greaterThanOrEqualTo(19000));

    final fens = <String>{};
    final themes = <String>{};
    var bad = 0;
    for (var i = 0; i < list.length; i += 67) {
      final p = list[i];
      final fen = p['fen'] as String;
      fens.add(fen);
      themes.add(p['themes'] as String);
      final uci = (p['moves'] as String).split(' ').first;
      final game = ch.Chess.fromFEN(fen);
      final ok = game.move({
        'from': uci.substring(0, 2),
        'to': uci.substring(2, 4),
        'promotion': uci.length > 4 ? uci[4] : null,
      });
      if (!ok) bad++;
    }
    expect(bad, 0, reason: 'posições com 1º lance ilegal na amostra');
    expect(fens.length, greaterThan(list.length ~/ 67 - 5),
        reason: 'posições repetidas demais');
    expect(themes.length, greaterThanOrEqualTo(30),
        reason: 'temas sem cobertura');
  });
}
