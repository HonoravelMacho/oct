import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/noir_theme.dart';
import '../../domain/entities/puzzle.dart';
import '../providers/session_provider.dart';
import '../providers/tactics_controller.dart';
import '../widgets/chess_board.dart';
import '../credit_gate.dart';

class TacticsScreen extends StatefulWidget {
  const TacticsScreen({super.key});

  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TacticsController>().refreshProgress();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TacticsController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.mode == TacticMode.themes
            ? 'TATICAS - TEMAS'
            : PuzzleCatalog.labelOf(controller.selectedTheme).toUpperCase()),
      ),
      body: controller.mode == TacticMode.themes
          ? _ThemeListView(controller: controller)
          : _SolverView(controller: controller),
    );
  }
}

class _ThemeListView extends StatelessWidget {
  const _ThemeListView({required this.controller});

  final TacticsController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.themeProgressList.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: controller.themeProgressList.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final tp = controller.themeProgressList[i];
        return Material(
          color: NoirPalette.surface,
          child: InkWell(
            onTap: () async {
              final ok = await controller.openTheme(tp.theme);
              if (!ok && context.mounted) {
                showSnack(context, 'NENHUM PUZZLE DISPONIVEL NESTE TEMA');
              }
            },
            child: Container(
              decoration:
                  BoxDecoration(border: Border.all(color: NoirPalette.border)),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          PuzzleCatalog.labelOf(tp.theme).toUpperCase(),
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5),
                        ),
                      ),
                      Text(
                        tp.total == 0
                            ? '0.00000%'
                            : '${tp.percent.toStringAsFixed(5)}%',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRect(
                    child: LinearProgressIndicator(
                      value: tp.total == 0 ? 0 : tp.solved / tp.total,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${tp.solved} / ${tp.total} RESOLVIDAS',
                    style: const TextStyle(
                        fontSize: 9, letterSpacing: 1, color: NoirPalette.textDim),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SolverView extends StatelessWidget {
  const _SolverView({required this.controller});

  final TacticsController controller;

  @override
  Widget build(BuildContext context) {
    final puzzle = controller.currentPuzzle;
    final session = context.read<SessionProvider>();

    String feedbackText;
    switch (controller.feedback) {
      case TacticFeedback.wrong:
        feedbackText = 'INCORRETO - TENTE OUTRO LANCE';
        break;
      case TacticFeedback.correctContinue:
        feedbackText = 'CORRETO! CONTINUE A SEQUENCIA';
        break;
      case TacticFeedback.solved:
        feedbackText = 'RESOLVIDA! +ELO';
        break;
      case TacticFeedback.revealed:
        feedbackText = 'SOLUCAO EXIBIDA - VALENDO ESTUDO';
        break;
      case TacticFeedback.exhausted:
        feedbackText = 'SEM MAIS PUZZLES DESTE TEMA';
        break;
      default:
        feedbackText =
            'LANCE DAS ${_sideLabel(puzzle?.fen ?? '')}';
    }
    if (controller.hintFrom != null &&
        controller.feedback != TacticFeedback.solved &&
        controller.feedback != TacticFeedback.revealed) {
      feedbackText = 'DICA: A PECA DE ${controller.hintFrom} SE MOVE';
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                puzzle == null
                    ? '-'
                    : 'RATING ${puzzle.rating}',
                style: const TextStyle(fontSize: 10, letterSpacing: 2),
              ),
              Text(
                session.premiumUnlocked ? 'PREMIUM' : 'GRATIS',
                style: const TextStyle(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: NoirPalette.textDim),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(feedbackText,
              style: const TextStyle(fontSize: 11.5, letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: ChessBoard(
                  key: ValueKey('board_${puzzle?.id}_${controller.wrongAttempts}'),
                  fen: controller.board.fen,
                  orientation: _solverOrientation(puzzle?.fen),
                  interactiveColor: _solverSide(puzzle?.fen),
                  enabled: puzzle != null &&
                      !controller.autoSolving &&
                      controller.feedback != TacticFeedback.solved &&
                      controller.feedback != TacticFeedback.revealed &&
                      controller.feedback != TacticFeedback.exhausted,
                  lastMoveSquares: [
                    if (controller.hintFrom != null) controller.hintFrom!,
                    ...controller.lastMoveSquaresForBoard(),
                  ],
                  onMove: (from, to, promo) =>
                      controller.tryHumanMove(from, to, promo),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: controller.autoSolving
                      ? null
                      : () => controller.showHint(),
                  child: Text(controller.hintsUsed > 0
                      ? 'DICA (${controller.hintsUsed})'
                      : 'DICA'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: controller.autoSolving
                      ? null
                      : () => controller.autoSolve(),
                  child: Text(controller.autoSolving
                      ? 'MOSTRANDO...'
                      : 'VER SOLUCAO'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.backToThemes(),
                  child: const Text('TEMAS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => controller.skipPuzzle(),
                  child: const Text('PROXIMA'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _sideLabel(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 2) return 'VOCE';
    return parts[1] == 'w' ? 'BRANCAS' : 'NEGRAS';
  }

  String _solverSide(String? fen) {
    final parts = (fen ?? '').split(' ');
    if (parts.length < 2) return 'w';
    return parts[1];
  }

  String _solverOrientation(String? fen) => _solverSide(fen);
}
