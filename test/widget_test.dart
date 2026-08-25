import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oct/presentation/widgets/chess_board.dart';
import 'package:oct/domain/entities/puzzle.dart';

const _startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  group('parseFENBoard', () {
    test('extrai as 32 peças da posição inicial', () {
      final board = parseFENBoard(_startFen);
      expect(board.length, 32);
      expect(board['e1'], 'K');
      expect(board['e8'], 'k');
      expect(board['a2'], 'P');
      expect(board['h7'], 'p');
      expect(board.containsKey('e4'), isFalse);
    });
  });

  group('ChessBoard widget', () {
    testWidgets('renderiza 64 casas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChessBoard(fen: _startFen, onMove: (_, _, _) {}),
          ),
        ),
      );
      for (final file in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
        for (final rank in [1, 2, 3, 4, 5, 6, 7, 8]) {
          expect(
            find.byKey(ValueKey('sq_$file$rank')),
            findsOneWidget,
            reason: 'casa $file$rank ausente',
          );
        }
      }
    });

    testWidgets('seleção mostra lances legais e emite lance válido',
        (tester) async {
      String? moveFrom;
      String? moveTo;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChessBoard(
              fen: _startFen,
              onMove: (from, to, promo) {
                moveFrom = from;
                moveTo = to;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('sq_e2')));
      await tester.pump();

      expect(find.byKey(const ValueKey('dot_e3')), findsOneWidget);
      expect(find.byKey(const ValueKey('dot_e4')), findsOneWidget);
      expect(find.byKey(const ValueKey('dot_e5')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('sq_e4')));
      await tester.pump();

      expect(moveFrom, 'e2');
      expect(moveTo, 'e4');
    });

    testWidgets('lance impossível não é emitido', (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChessBoard(
              fen: _startFen,
              onMove: (_, _, _) => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('sq_e2')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sq_e5')));
      await tester.pump();

      expect(called, isFalse);
    });

    testWidgets('peça adversária não selecionável quando cor travada',
        (tester) async {
      var called = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChessBoard(
              fen: _startFen,
              interactiveColor: 'w',
              enabled: true,
              onMove: (_, _, _) => called = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('sq_e7')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sq_e5')));
      await tester.pump();

      expect(called, isFalse);
    });
  });

  group('PuzzleCatalog', () {
    test('primaryOf prioriza mate sobre temas genéricos', () {
      expect(PuzzleCatalog.primaryOf(['endgame', 'mateIn2']), 'mateIn2');
      expect(PuzzleCatalog.primaryOf(['middlegame', 'fork', 'pin']),
          'fork');
      expect(PuzzleCatalog.primaryOf([]), 'misc');
    });

    test('labels PT-BR presentes para todos os temas prioritários', () {
      for (final theme in PuzzleCatalog.priority) {
        expect(PuzzleCatalog.labelOf(theme), isNot(theme),
            reason: 'sem label PT-BR para $theme');
      }
    });
  });
}
