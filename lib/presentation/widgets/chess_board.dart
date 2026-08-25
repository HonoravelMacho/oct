import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';

import '../../core/noir_theme.dart';

const Map<String, String> _whiteGlyphs = {
  'k': '\u2654',
  'q': '\u2655',
  'r': '\u2656',
  'b': '\u2657',
  'n': '\u2658',
  'p': '\u2659',
};

const Map<String, String> _blackGlyphs = {
  'k': '\u265A',
  'q': '\u265B',
  'r': '\u265C',
  'b': '\u265D',
  'n': '\u265E',
  'p': '\u265F',
};

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
    final glyph =
        (isWhite ? _whiteGlyphs : _blackGlyphs)[charCode.toLowerCase()] ?? '?';
    final fontSize = size * 0.74;

    final strokeColor = isWhite ? Colors.black : NoirPalette.boardLight;
    final fillColor = isWhite ? Colors.white : const Color(0xFF0B0B0B);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            glyph,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.055
                ..color = strokeColor,
            ),
          ),
          Text(
            glyph,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              height: 1,
              color: fillColor,
            ),
          ),
        ],
      ),
    );
  }
}
