import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
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
    final canPick = controller.phase == GamePhase.idle ||
        controller.phase == GamePhase.finished;

    return Scaffold(
      appBar: AppBar(title: const Text('PARTIDA VS BOT')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: BotRoster.all.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final bot = BotRoster.all[i];
                  final selected = controller.botBaseName == bot.name;
                  return GestureDetector(
                    onTap: canPick
                        ? () => controller.selectBot(bot.name)
                        : null,
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
                        bot.name,
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
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: NoirPalette.border),
                color: NoirPalette.surface,
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('FORCA DO BOT',
                          style: TextStyle(
                              fontSize: 9,
                              letterSpacing: 2,
                              color: NoirPalette.textDim)),
                      Text('${controller.botRating}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  Slider(
                    value: controller.botRating.toDouble(),
                    min: AppConstants.minBotElo.toDouble(),
                    max: AppConstants.maxBotElo.toDouble(),
                    divisions: (AppConstants.maxBotElo -
                            AppConstants.minBotElo) ~/
                        AppConstants.botEloStep,
                    label: '${controller.botRating}',
                    onChanged: canPick
                        ? (v) => controller.setBotRating(v.round())
                        : null,
                  ),
                  Text(
                    'MOTOR SKILL ${controller.selectedBot.skillLevel} · '
                    'LIMITE ~${controller.selectedBot.uciElo}'
                    '${controller.botRating < 1100 ? ' + LANCES CASUAIS' : ''}',
                    style: const TextStyle(
                        fontSize: 8.5,
                        letterSpacing: 1.5,
                        color: NoirPalette.textDim),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: NoirPalette.border),
                color: NoirPalette.surface,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _OctStat(
                      label: 'SEU RATING OCT',
                      value: '${session.gameElo}'),
                  Container(width: 1, height: 32, color: NoirPalette.border),
                  _OctStat(
                      label: 'EXPECTATIVA',
                      value:
                          '${controller.expectedScorePct.toStringAsFixed(0)}%'),
                  Container(width: 1, height: 32, color: NoirPalette.border),
                  _OctStat(
                      label: 'PARTIDAS',
                      value: '${session.stats.gamesPlayed}'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (controller.phase == GamePhase.playing ||
                controller.phase == GamePhase.botThinking ||
                controller.phase == GamePhase.finished)
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: NoirPalette.border),
                  color: NoirPalette.surface,
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('SUAS CHANCES',
                            style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 2,
                                color: NoirPalette.textDim)),
                        Text(
                          '${controller.userWinChance.toStringAsFixed(1)}%',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRect(
                      child: LinearProgressIndicator(
                        value: controller.userWinChance / 100,
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'VANTAGEM MATERIAL: ${_materialLabel(controller.userMaterialDiff)}',
                      style: const TextStyle(
                          fontSize: 8.5,
                          letterSpacing: 1.5,
                          color: NoirPalette.textDim),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _statusText(controller),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, letterSpacing: 2),
              ),
            ),
            AspectRatio(
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
            const SizedBox(height: 10),
            if (controller.phase == GamePhase.finished)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/analysis'),
                    child: const Text('VER ANALISE DA PARTIDA'),
                  ),
                ),
              ),
            Row(
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
          ],
        ),
      ),
    );
  }

  String _materialLabel(int diff) {
    if (diff == 0) return 'IGUAL';
    return '${diff > 0 ? '+' : ''}$diff PARA VOCE';
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
        return 'AJUSTE A FORCA E INICIE';
      case GamePhase.botThinking:
        return '${c.selectedBot.name} ${c.selectedBot.elo} PENSANDO...';
      case GamePhase.finished:
        final label = switch (c.gameResult) {
          'win' => 'VITORIA',
          'loss' => 'DERROTA',
          _ => 'EMPATE',
        };
        return '$label - OCT ${c.eloBefore} → ${c.eloAfter} (${c.eloDelta >= 0 ? '+' : ''}${c.eloDelta})';
      case GamePhase.playing:
        return c.isPlayerTurn ? 'SUA VEZ (${c.userColor == 'w' ? 'BRANCAS' : 'NEGRAS'})' : 'AGUARDE';
    }
  }
}

class _OctStat extends StatelessWidget {
  const _OctStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 8, letterSpacing: 1.2, color: NoirPalette.textDim)),
      ],
    );
  }
}
