import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../../core/noir_theme.dart';

Map<String, String> parseFENBoard(String fen) {
  final result = <String, String>{};
  final rows = fen.split(' ').first.split('/');
  const files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  for (var r = 0; r < 8; r++) {
    var fileIndex = 0;
    for (final charCode in rows[r].codeUnits) {
      final char = String.fromCharCode(charCode);
      if (int.tryParse(char) != null) {
        fileIndex += int.parse(char);
      } else {
        final square = '${files[fileIndex]}${8 - r}';
        result[square] = char;
        fileIndex++;
      }
    }
  }
  return result;
}

typedef BoardMoveCallback = void Function(
    String from, String to, String? promotion);

class ChessBoard extends StatefulWidget {
  const ChessBoard({
    required this.fen,
    required this.onMove,
    this.orientation = 'w',
    this.enabled = true,
    this.interactiveColor = 'both',
    this.lastMoveSquares = const [],
    super.key,
  });

  final String fen;
  final String orientation;
  final bool enabled;
  final String interactiveColor;
  final List<String> lastMoveSquares;
  final BoardMoveCallback onMove;

  @override
  State<ChessBoard> createState() => _ChessBoardState();
}

class _ChessBoardState extends State<ChessBoard> {
  String? _selected;
  final Map<String, bool> _legalTargets = {};
  late ch.Chess _position;

  @override
  void initState() {
    super.initState();
    _position = ch.Chess.fromFEN(widget.fen);
  }

  @override
  void didUpdateWidget(covariant ChessBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fen != widget.fen) {
      _position = ch.Chess.fromFEN(widget.fen);
      _clearSelection();
    }
  }

  void _clearSelection() {
    _selected = null;
    _legalTargets.clear();
  }

  bool _canInteractWith(String pieceCharCode) {
    if (!widget.enabled) return false;
    final isWhite = pieceCharCode.toUpperCase() == pieceCharCode;
    switch (widget.interactiveColor) {
      case 'w':
        return isWhite;
      case 'b':
        return !isWhite;
      default:
        return true;
    }
  }

  void _onSquareTap(String square) {
    if (!widget.enabled) return;

    if (_selected != null && _legalTargets.containsKey(square)) {
      final piece = _pieceAt(_selected!);
      String? promotion;
      if (piece != null && piece.toLowerCase() == 'p') {
        final rank = square[1];
        if ((piece == 'P' && rank == '8') || (piece == 'p' && rank == '1')) {
          promotion = 'q';
        }
      }
      final from = _selected!;
      _clearSelection();
      setState(() {});
      widget.onMove(from, square, promotion);
      return;
    }

    final piece = _pieceAt(square);
    if (piece == null || !_canInteractWith(piece)) {
      setState(_clearSelection);
      return;
    }

    _selected = square;
    _legalTargets.clear();
    for (final mv in _position
          .moves({'square': square, 'asObjects': true}).cast<ch.Move>()) {
      _legalTargets[mv.toAlgebraic] = mv.captured != null;
    }
    setState(() {});
  }

  String? _pieceAt(String square) => parseFENBoard(widget.fen)[square];

  List<String> get _files {
    const f = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
    return widget.orientation == 'w' ? f : f.reversed.toList();
  }

  List<int> get _ranks {
    final r = [8, 7, 6, 5, 4, 3, 2, 1];
    return widget.orientation == 'w' ? r : r.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          final squareSize = (side / 8).floorToDouble();
          final boardPixels = squareSize * 8;

          return Center(
            child: SizedBox(
              width: boardPixels,
              height: boardPixels,
              child: DecoratedBox(
                decoration:
                    BoxDecoration(border: Border.all(color: NoirPalette.border)),
                child: Column(
                  children: [
                    for (final rank in _ranks)
                      Row(
                        children: [
                          for (final file in _files)
                            _buildSquare('$file$rank', squareSize),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSquare(String square, double size) {
    final fileIndex = square.codeUnitAt(0) - 97;
    final rank = int.parse(square[1]);
    final isLight = (fileIndex + rank) % 2 == 0;

    final piece = _pieceAt(square);
    final isSelected = _selected == square;
    final isLastMove = widget.lastMoveSquares.contains(square);
    final targetInfo = _legalTargets[square];

    Widget content = const SizedBox.expand();

    if (targetInfo != null) {
      content = targetInfo
          ? Center(
              child: Container(
                key: ValueKey('ring_$square'),
                width: size * 0.86,
                height: size * 0.86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NoirPalette.highlightDot,
                    width: size * 0.07,
                  ),
                ),
              ),
            )
          : Center(
              child: Container(
                key: ValueKey('dot_$square'),
                width: size * 0.26,
                height: size * 0.26,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: NoirPalette.highlightDot,
                ),
              ),
            );
    }

    if (piece != null) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          if (targetInfo != null) content,
          _PieceGlyph(
            charCode: piece,
            size: size,
          ),
        ],
      );
    } else if (targetInfo != null) {
      content = content;
    }

    return GestureDetector(
      key: ValueKey('sq_$square'),
      onTap: () => _onSquareTap(square),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isLight ? NoirPalette.boardLight : NoirPalette.boardDark,
          border: isSelected
              ? Border.all(color: NoirPalette.textPrimary, width: 2.5)
              : null,
        ),
        child: Stack(
          children: [
            if (isLastMove)
              Container(color: NoirPalette.lastMoveTint),
            Positioned.fill(child: Center(child: content)),
          ],
        ),
      ),
    );
  }
}

class _PieceGlyph extends StatelessWidget {
  const _PieceGlyph({required this.charCode, required this.size});

  final String charCode;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isWhite = charCode.toUpperCase() == charCode;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PiecePainter(
          kind: charCode.toLowerCase(),
          isWhite: isWhite,
        ),
      ),
    );
  }
}

/// Peças desenhadas em vetor (ouro × madeira): independem da fonte do
/// aparelho, então ficam idênticas em qualquer celular.
class _PiecePainter extends CustomPainter {
  _PiecePainter({required this.kind, required this.isWhite});

  final String kind;
  final bool isWhite;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100;
    final fill = Paint()
      ..color =
          isWhite ? NoirPalette.pieceGold : NoirPalette.pieceWood;
    final edge = Paint()
      ..color = isWhite
          ? NoirPalette.pieceGoldEdge
          : NoirPalette.pieceWoodEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * u
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final detail = Paint()
      ..color = isWhite
          ? NoirPalette.pieceGoldEdge
          : NoirPalette.pieceWoodEdge;
    final slit = Paint()
      ..color = detail.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u
      ..strokeCap = StrokeCap.round;

    void shape(Path p) {
      canvas.drawPath(p, edge);
      canvas.drawPath(p, fill);
    }

    void ball(double x, double y, double r) {
      final c = Offset(x * u, y * u);
      canvas.drawCircle(c, r * u, edge);
      canvas.drawCircle(c, r * u, fill);
    }

    void bar(double x, double y, double w, double h) {
      final r = RRect.fromLTRBR(
        x * u,
        y * u,
        (x + w) * u,
        (y + h) * u,
        Radius.circular(3 * u),
      );
      canvas.drawRRect(r, edge);
      canvas.drawRRect(r, fill);
    }

    Path poly(List<(double, double)> pts) {
      final p = Path();
      p.moveTo(pts.first.$1 * u, pts.first.$2 * u);
      for (final pt in pts.skip(1)) {
        p.lineTo(pt.$1 * u, pt.$2 * u);
      }
      p.close();
      return p;
    }

    // Base comum.
    bar(24, 80, 52, 9);

    switch (kind) {
      case 'p':
        shape(poly([
          (38, 78),
          (44, 58),
          (56, 58),
          (62, 78),
        ]));
        bar(37, 70, 26, 7);
        ball(50, 44, 13);
      case 'r':
        shape(Path()
          ..moveTo(32 * u, 38 * u)
          ..lineTo(32 * u, 20 * u)
          ..lineTo(39 * u, 20 * u)
          ..lineTo(39 * u, 28 * u)
          ..lineTo(46 * u, 28 * u)
          ..lineTo(46 * u, 20 * u)
          ..lineTo(54 * u, 20 * u)
          ..lineTo(54 * u, 28 * u)
          ..lineTo(61 * u, 28 * u)
          ..lineTo(61 * u, 20 * u)
          ..lineTo(68 * u, 20 * u)
          ..lineTo(68 * u, 38 * u)
          ..close());
        shape(poly([
          (36, 40),
          (64, 40),
          (60, 76),
          (40, 76),
        ]));
        bar(38, 68, 24, 6);
      case 'n':
        shape(poly([
          (38, 78),
          (38, 60),
          (30, 52),
          (28, 44),
          (32, 40),
          (37, 41),
          (39, 30),
          (45, 24),
          (53, 25),
          (50, 31),
          (57, 35),
          (65, 41),
          (62, 49),
          (56, 47),
          (54, 58),
          (58, 78),
        ]));
        canvas.drawCircle(Offset(45 * u, 39 * u), 2.4 * u, detail);
      case 'b':
        ball(50, 17, 4.5);
        shape(Path()
          ..moveTo(50 * u, 26 * u)
          ..cubicTo(41 * u, 36 * u, 37 * u, 48 * u, 37 * u, 58 * u)
          ..lineTo(63 * u, 58 * u)
          ..cubicTo(63 * u, 48 * u, 59 * u, 36 * u, 50 * u, 26 * u)
          ..close());
        canvas.drawLine(
            Offset(50 * u, 34 * u), Offset(50 * u, 52 * u), slit);
        bar(39, 58, 22, 6);
        shape(poly([
          (42, 66),
          (58, 66),
          (62, 78),
          (38, 78),
        ]));
      case 'q':
        ball(32, 25, 4);
        ball(50, 19, 4.5);
        ball(68, 25, 4);
        shape(poly([
          (32, 54),
          (34, 31),
          (43, 43),
          (50, 29),
          (57, 43),
          (66, 31),
          (68, 54),
        ]));
        bar(37, 62, 26, 6);
        shape(poly([
          (40, 70),
          (60, 70),
          (62, 78),
          (38, 78),
        ]));
      case 'k':
        bar(46, 14, 8, 24);
        bar(38, 21, 24, 7);
        shape(poly([
          (34, 56),
          (37, 37),
          (45, 47),
          (50, 37),
          (55, 47),
          (63, 37),
          (66, 56),
        ]));
        bar(37, 62, 26, 6);
        shape(poly([
          (40, 70),
          (60, 70),
          (62, 78),
          (38, 78),
        ]));
    }
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) =>
      old.kind != kind || old.isWhite != isWhite;
}
