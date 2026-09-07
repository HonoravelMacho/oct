import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/noir_theme.dart';
import '../providers/play_controller.dart';
import '../widgets/chess_board.dart';

/// Análise pós-partida 100% local: resultado, evolução do rating OCT,
/// estatísticas da partida, gráfico de balanço de material e lista de lances.
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlayController>();
    if (c.historySan.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ANALISE')),
        body: const Center(child: Text('SEM PARTIDA PARA ANALISAR')),
      );
    }

    final resultLabel = switch (c.gameResult) {
      'win' => 'VITORIA',
      'loss' => 'DERROTA',
      _ => 'EMPATE',
    };
    final deltaTxt =
        '${c.eloDelta >= 0 ? '+' : ''}${c.eloDelta}';

    return Scaffold(
      appBar: AppBar(title: const Text('ANALISE DA PARTIDA')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border),
              color: NoirPalette.surface,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(resultLabel,
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
                const SizedBox(height: 6),
                Text(
                  'RATING OCT ${c.eloBefore} → ${c.eloAfter} ($deltaTxt)',
                  style: const TextStyle(
                      fontSize: 12, letterSpacing: 1.5, color: NoirPalette.textDim),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MiniScore(
                        label: c.userColor == 'w' ? 'VOCE (BRANCAS)' : 'VOCE (NEGRAS)',
                        value: '${c.eloAfter}'),
                    Container(width: 1, height: 30, color: NoirPalette.border),
                    _MiniScore(
                        label: '${c.selectedBot.name} (${c.selectedBot.elo})',
                        value: c.userColor == 'w' ? 'NEGRAS' : 'BRANCAS'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 1,
            child: ChessBoard(
              fen: c.game.fen,
              orientation: c.userColor,
              interactiveColor: 'none',
              enabled: false,
              lastMoveSquares: c.lastMoveSquares,
              onMove: (_, _, _) {},
            ),
          ),
          const SizedBox(height: 12),
          const _SectionTitle('BALANCO DE MATERIAL'),
          const SizedBox(height: 6),
          _MaterialStrip(timeline: c.materialTimeline()),
          const SizedBox(height: 12),
          const _SectionTitle('ESTATISTICAS'),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              _StatTile(label: 'LANCES', value: '${c.historySan.length}'),
              _StatTile(
                  label: 'CAPTURAS VOCE × BOT',
                  value: '${c.userCaptures} × ${c.botCaptures}'),
              _StatTile(
                  label: 'XEQUES VOCE × BOT',
                  value: '${c.userChecks} × ${c.botChecks}'),
              _StatTile(
                  label: 'MATERIAL FINAL',
                  value: c.userMaterialDiff == 0
                      ? 'IGUAL'
                      : '${c.userMaterialDiff > 0 ? '+' : ''}${c.userMaterialDiff} VOCE'),
              _StatTile(
                  label: 'ABERTURA',
                  value: c.historySan.take(4).join(' ')),
              _StatTile(
                  label: 'LANCE DECISIVO',
                  value: c.decisiveMoveNumber > 0
                      ? '${c.decisiveMoveNumber}. ${c.decisiveSan}'
                      : '-'),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionTitle('LANCES'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(border: Border.all(color: NoirPalette.border)),
            padding: const EdgeInsets.all(10),
            child: _MoveTable(history: c.historySan),
          ),
          const SizedBox(height: 14),
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
                  onPressed: () {
                    c.startNewGame();
                    Navigator.pop(context);
                  },
                  child: const Text('REVANCHE'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 8.5, letterSpacing: 1.5, color: NoirPalette.textDim)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 10, letterSpacing: 2.5, color: NoirPalette.textDim));
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: NoirPalette.border),
        color: NoirPalette.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 8.5, letterSpacing: 1.5, color: NoirPalette.textDim)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MaterialStrip extends StatelessWidget {
  const _MaterialStrip({required this.timeline});

  final List<int> timeline;

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) return const SizedBox.shrink();
    final maxAbs =
        timeline.map((e) => e.abs()).fold<int>(0, (a, b) => a > b ? a : b);
    final span = maxAbs == 0 ? 1 : maxAbs;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: NoirPalette.border)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: timeline.map((d) {
                final h = (d.abs() / span * 26).round();
                final up = d >= 0;
                return Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          height: up ? h.toDouble() : 0,
                          color: Colors.white),
                      Container(height: 1, color: NoirPalette.border),
                      Container(
                          height: up ? 0 : h.toDouble(),
                          color: NoirPalette.textDim),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 6),
          const Text('BRANCAS PARA CIMA × PRETAS PARA BAIXO',
              style: TextStyle(
                  fontSize: 8, letterSpacing: 1.5, color: NoirPalette.textDim)),
        ],
      ),
    );
  }
}

class _MoveTable extends StatelessWidget {
  const _MoveTable({required this.history});

  final List<String> history;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < history.length; i += 2) {
      final n = i ~/ 2 + 1;
      final w = history[i];
      final b = i + 1 < history.length ? history[i + 1] : '';
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
                width: 34,
                child: Text('$n.',
                    style: const TextStyle(
                        fontSize: 11, color: NoirPalette.textDim))),
            Expanded(
                child: Text(w,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600))),
            Expanded(
                child: Text(b,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600))),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}
