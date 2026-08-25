import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/noir_theme.dart';
import '../../domain/entities/bot_profile.dart';
import '../credit_gate.dart';
import '../providers/play_controller.dart';
import '../providers/session_provider.dart';
import '../widgets/chess_board.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayController>().ensureEngine();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final controller = context.watch<PlayController>();

    return Scaffold(
      appBar: AppBar(title: const Text('PARTIDA VS BOT')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: BotRoster.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final bot = BotRoster.all[i];
                  final selected = controller.selectedBot == bot;
                  final canPick =
                      controller.phase == GamePhase.idle ||
                          controller.phase == GamePhase.finished;
                  return GestureDetector(
                    onTap: canPick ? () => controller.selectBot(bot) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white
                            : NoirPalette.surface,
                        border: Border.all(color: NoirPalette.border),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${bot.name} ${bot.elo}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                          color: selected ? Colors.black : NoirPalette.textDim,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _statusText(controller),
                style: const TextStyle(fontSize: 11, letterSpacing: 2),
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: ChessBoard(
                    fen: controller.game.fen,
                    orientation: controller.userColor,
                    interactiveColor: controller.isPlayerTurn
                        ? controller.userColor
                        : 'none',
                    enabled: controller.phase == GamePhase.playing,
                    lastMoveSquares: controller.lastMoveSquares,
                    onMove: (from, to, promo) {
                      if (!controller.humanMove(from, to)) {
                        showSnack(context, 'LANCE ILEGAL');
                      }
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('VOLTAR'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: session.premiumUnlocked ||
                              session.canStartActivity
                          ? () async {
                              final gateOk = await _maybeGate(context);
                              if (!gateOk || !context.mounted) return;
                              controller.startNewGame();
                            }
                          : null,
                      child: Text(controller.phase == GamePhase.idle ||
                              controller.phase == GamePhase.finished
                          ? 'NOVA PARTIDA'
                          : 'EM ANDAMENTO'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _maybeGate(BuildContext context) async {
    final session = context.read<SessionProvider>();
    if (session.premiumUnlocked || session.canStartActivity) return true;
    final wants = await showCreditGate(context);
    if (!wants) return false;
    if (!context.mounted) return false;
    final earned = await session.showRewardedFlow(context);
    if (!earned) return false;
    session.grantRewardCycle();
    if (!context.mounted) return false;
    showSnack(context, 'CREDITOS RENOVADOS');
    return true;
  }

  String _statusText(PlayController c) {
    switch (c.phase) {
      case GamePhase.idle:
        return 'ESCOLHA UM BOT E INICIE';
      case GamePhase.botThinking:
        return '${c.selectedBot.name} PENSANDO...';
      case GamePhase.finished:
        final label = switch (c.gameResult) {
          'win' => 'VITORIA',
          'loss' => 'DERROTA',
          _ => 'EMPATE',
        };
        return '$label - ELO ${c.eloDelta >= 0 ? '+' : ''}${c.eloDelta}';
      case GamePhase.playing:
        return c.isPlayerTurn ? 'SUA VEZ (${c.userColor == 'w' ? 'BRANCAS' : 'NEGRAS'})' : 'AGUARDE';
    }
  }
}
