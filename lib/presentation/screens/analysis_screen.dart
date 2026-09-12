import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/noir_theme.dart';
import '../../domain/entities/puzzle.dart';
import '../../domain/services/game_review_service.dart';
import '../../domain/services/study_recommendation_service.dart';
import '../providers/play_controller.dart';
import '../providers/session_provider.dart';
import '../providers/tactics_controller.dart';
import '../widgets/chess_board.dart';

const Map<MoveLabel, Color> _labelColors = {
  MoveLabel.brilliant: Color(0xFF7DD3FC),
  MoveLabel.great: Color(0xFF86EFAC),
  MoveLabel.best: Color(0xFFE8B93C),
  MoveLabel.excellent: Color(0xFFBEF264),
  MoveLabel.good: Color(0xFFA8A29E),
  MoveLabel.book: Color(0xFFC08A4D),
  MoveLabel.inaccuracy: Color(0xFFFDE047),
  MoveLabel.mistake: Color(0xFFFB923C),
  MoveLabel.miss: Color(0xFFC084FC),
  MoveLabel.blunder: Color(0xFFF87171),
};

/// Análise pós-partida 100% local e navegável: toque num lance para ver
/// o frame do tabuleiro, use avançar/voltar, veja os piores lances com
/// profundidade e receba recomendações do que estudar.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  int? _selectedPly; // null = posição final

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlayController>().reviewGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PlayController>();
    final session = context.watch<SessionProvider>();
    if (c.historySan.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('ANALISE')),
        body: const Center(child: Text('SEM PARTIDA PARA ANALISAR')),
      );
    }

    final n = c.historySan.length;
    var ply = _selectedPly ?? n;
    ply = ply.clamp(0, n);
    final review = c.gameReview;
    final userWhite = c.userColor == 'w';

    final resultLabel = switch (c.gameResult) {
      'win' => 'VITORIA',
      'loss' => 'DERROTA',
      _ => 'EMPATE',
    };
    final deltaTxt = '${c.eloDelta >= 0 ? '+' : ''}${c.eloDelta}';

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
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3)),
                const SizedBox(height: 6),
                Text(
                  'RATING OFFLINE ${c.eloBefore} → ${c.eloAfter} ($deltaTxt)',
                  style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.5,
                      color: NoirPalette.textDim),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _MiniScore(
                        label: userWhite ? 'VOCE (BRANCAS)' : 'VOCE (NEGRAS)',
                        value: '${c.eloAfter}'),
                    Container(width: 1, height: 30, color: NoirPalette.border),
                    _MiniScore(
                        label: '${c.selectedBot.name} (${c.selectedBot.elo})',
                        value: userWhite ? 'NEGRAS' : 'BRANCAS'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final d in GameReviewService.depthOptions)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: d == GameReviewService.depthOptions.last
                            ? 0
                            : 8),
                    child: GestureDetector(
                      onTap: c.reviewing
                          ? null
                          : () => c.reviewGame(depth: d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.reviewDepthUsed == d && review != null
                              ? Colors.white
                              : NoirPalette.surface,
                          border:
                              Border.all(color: NoirPalette.border),
                        ),
                        child: Text(
                          '${_depthLabel(d)} $d',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: c.reviewDepthUsed == d &&
                                    review != null
                                ? Colors.black
                                : NoirPalette.textDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'PROFUNDA PENSA MAIS (PODE LEVAR MINUTOS) · TUDO OFFLINE',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 8, letterSpacing: 1.5, color: NoirPalette.textDim),
          ),
          const SizedBox(height: 8),
          _ReviewSection(
            controller: c,
            session: session,
            review: review,
            userWhite: userWhite,
          ),
          const SizedBox(height: 12),
          // ---- Navegador de lances ----
          const _SectionTitle('NAVEGAR PELA PARTIDA - TOQUE NUM LANCE'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border),
              color: NoirPalette.surface,
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ChessBoard(
                    fen: c.fenAtPly(ply),
                    orientation: c.userColor,
                    interactiveColor: 'none',
                    enabled: false,
                    lastMoveSquares: c.lastMoveAtPly(ply),
                    onMove: (_, _, _) {},
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ply == 0
                      ? 'POSIÇÃO INICIAL'
                      : '${(ply - 1) ~/ 2 + 1}.${(ply - 1) % 2 == 1 ? '..' : ''} ${c.historySan[ply - 1]}'
                          '${review != null && ply - 1 < review.labels.length ? ' · ${GameReviewService.labelNames[review.labels[ply - 1]]}' : ''}'
                          '${review != null && ply < review.evalTexts.length ? ' · ${review.evalTexts[ply]}' : ''}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ply > 0
                            ? () => setState(() => _selectedPly = 0)
                            : null,
                        child: const Text('|◀'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ply > 0
                            ? () => setState(() => _selectedPly = ply - 1)
                            : null,
                        child: const Text('◀'),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: Text('$ply / $n',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ply < n
                            ? () => setState(() => _selectedPly = ply + 1)
                            : null,
                        child: const Text('▶'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: ply < n
                            ? () => setState(() => _selectedPly = n)
                            : null,
                        child: const Text('▶|'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ---- Piores lances (análise profunda) ----
          if (review != null) ...[
            const _SectionTitle('SEUS PIORES LANCES (APROFUNDE AQUI)'),
            const SizedBox(height: 6),
            _WorstMoves(
              controller: c,
              review: review,
              userWhite: userWhite,
              onJump: (p) => setState(() => _selectedPly = p),
            ),
            const SizedBox(height: 12),
            const _SectionTitle('O QUE ESTUDAR DEPOIS DESTA PARTIDA'),
            const SizedBox(height: 6),
            _StudyAfterGame(review: review, userWhite: userWhite),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 4),
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
                  label: 'ABERTURA', value: c.historySan.take(4).join(' ')),
              _StatTile(
                  label: 'LANCE DECISIVO',
                  value: c.decisiveMoveNumber > 0
                      ? '${c.decisiveMoveNumber}. ${c.decisiveSan}'
                      : '-'),
            ],
          ),
          const SizedBox(height: 12),
          const _SectionTitle('TODOS OS LANCES (TOQUE P/ VER O FRAME)'),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: NoirPalette.border)),
            padding: const EdgeInsets.all(10),
            child: review == null
                ? const Text('AGUARDE A REVISÃO DO MOTOR...',
                    style: TextStyle(fontSize: 11, letterSpacing: 1))
                : _MoveTable(
                    history: c.historySan,
                    labels: review.labels,
                    evalTexts: review.evalTexts,
                    losses: review.losses,
                    selectedPly: ply,
                    onSelect: (p) => setState(() => _selectedPly = p),
                  ),
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

class _WorstMoves extends StatelessWidget {
  const _WorstMoves({
    required this.controller,
    required this.review,
    required this.userWhite,
    required this.onJump,
  });

  final PlayController controller;
  final GameReview review;
  final bool userWhite;
  final void Function(int ply) onJump;

  @override
  Widget build(BuildContext context) {
    final plies = controller.worstUserPlies(count: 3);
    if (plies.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: NoirPalette.border),
          color: NoirPalette.surface,
        ),
        padding: const EdgeInsets.all(12),
        child: const Text(
          'NENHUM ERRO GRAVE — PARTIDA SÓLIDA. VEJA O GRÁFICO E AS ETIQUETAS.',
          style: TextStyle(fontSize: 10.5, letterSpacing: 0.8),
        ),
      );
    }
    return Column(
      children: [
        for (final i in plies)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border),
              color: NoirPalette.surface,
            ),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${i ~/ 2 + 1}.${i % 2 == 1 ? '..' : ''} ${controller.historySan[i]}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _labelColors[review.labels[i]],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${GameReviewService.labelNames[review.labels[i]]} · '
                        'PERDEU ${review.losses[i].toStringAsFixed(1)}% · '
                        'AVAL ${review.evalTexts[i + 1]}',
                        style: const TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.5,
                            color: NoirPalette.textDim),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => onJump(i + 1),
                  child: const Text('VER'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StudyAfterGame extends StatelessWidget {
  const _StudyAfterGame({required this.review, required this.userWhite});

  final GameReview review;
  final bool userWhite;

  @override
  Widget build(BuildContext context) {
    final recs = StudyRecommendationService.fromReview(
      review,
      userWhite: userWhite,
    );
    return Column(
      children: [
        for (final r in recs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border),
              color: NoirPalette.surface,
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        PuzzleCatalog.labelOf(r.theme).toUpperCase(),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        r.reason,
                        style: const TextStyle(
                            fontSize: 9.5,
                            letterSpacing: 0.8,
                            color: NoirPalette.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    context.read<TacticsController>().openTheme(r.theme);
                    Navigator.pushNamed(context, '/tactics');
                  },
                  child: const Text('TREINAR'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.controller,
    required this.session,
    required this.review,
    required this.userWhite,
  });

  final PlayController controller;
  final SessionProvider session;
  final GameReview? review;
  final bool userWhite;

  @override
  Widget build(BuildContext context) {
    final r = review;
    if (controller.reviewing || r == null) {
      final done = controller.reviewDone;
      final total =
          controller.reviewTotal == 0 ? controller.historySan.length + 1 : controller.reviewTotal;
      final pct = total == 0 ? 0.0 : done / total;
      return Container(
        decoration: BoxDecoration(
          border: Border.all(color: NoirPalette.border),
          color: NoirPalette.surface,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              session.usingStockfish
                  ? 'ANALISANDO COM O MOTOR... $done/$total'
                  : 'PREPARANDO ANALISE...',
              style: const TextStyle(fontSize: 11, letterSpacing: 2),
            ),
            const SizedBox(height: 10),
            ClipRect(
              child: LinearProgressIndicator(value: pct, minHeight: 6),
            ),
          ],
        ),
      );
    }

    final accUser = userWhite ? r.accuracyWhite : r.accuracyBlack;
    final accBot = userWhite ? r.accuracyBlack : r.accuracyWhite;
    final estUser = userWhite ? r.estWhite : r.estBlack;
    final estBot = userWhite ? r.estBlack : r.estWhite;
    final countsUser = userWhite ? r.countsWhite : r.countsBlack;
    final skills = userWhite ? r.skillsWhite : r.skillsBlack;
    final stats = session.stats.openingStats(r.openingKey);
    final slowest = controller.humanSlowest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('REVISAO DO MOTOR'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: NoirPalette.border),
            color: NoirPalette.surface,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AccuracyDial(label: 'SUA PRECISAO', value: accUser),
                  Container(
                      width: 1, height: 64, color: NoirPalette.border),
                  _AccuracyDial(label: 'PRECISAO DO BOT', value: accBot),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MiniScore(
                      label: 'SEU NIVEL NA PARTIDA', value: '$estUser'),
                  Container(
                      width: 1, height: 30, color: NoirPalette.border),
                  _MiniScore(
                      label: 'NIVEL DO BOT NA PARTIDA', value: '$estBot'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.engineUsed
                    ? 'MOTOR STOCKFISH · PROFUNDIDADE ${r.depth}'
                    : 'MODO LEVE · SEM MOTOR (ESTIMATIVA POR MATERIAL)',
                style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 1.5,
                    color: NoirPalette.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('SUAS HABILIDADES'),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.8,
          children: [
            _StatTile(label: 'ABERTURA', value: _skillTxt(skills.abertura)),
            _StatTile(label: 'MEIO-JOGO', value: _skillTxt(skills.meioJogo)),
            _StatTile(label: 'FINAL', value: _skillTxt(skills.finalJogo)),
            _StatTile(label: 'TATICA', value: _skillTxt(skills.tatica)),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionTitle('SEUS LANCES'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final l in MoveLabel.values)
              if ((countsUser[l] ?? 0) > 0)
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: NoirPalette.border)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 5),
                  child: Text(
                    '${GameReviewService.labelEmojis[l]} ${countsUser[l]} ${GameReviewService.labelNames[l]}',
                    style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: _labelColors[l]),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 12),
        const _SectionTitle('ABERTURA'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: NoirPalette.border),
            color: NoirPalette.surface,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.openingName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(
                'SEU HISTORICO NESSA LINHA: '
                '${stats.w}V ${stats.d}E ${stats.l}D',
                style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: NoirPalette.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('GRAFICO DE AVALIACAO'),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border)),
          padding: const EdgeInsets.all(10),
          child: Column(
            children: [
              SizedBox(
                height: 96,
                width: double.infinity,
                child: CustomPaint(
                  painter: _EvalChartPainter(timeline: r.timeline),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('FINAL: ${r.evalTexts.last}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  const Text('VALORES PARA AS BRANCAS',
                      style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.5,
                          color: NoirPalette.textDim)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('SEU RITMO'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: NoirPalette.border),
            color: NoirPalette.surface,
          ),
          padding: const EdgeInsets.all(12),
          child: Text(
            'MEDIA ${controller.humanAvgSeconds.toStringAsFixed(1)}s POR LANCE'
            '${slowest.moveNumber > 0 ? ' · MAIS LONGO ${slowest.seconds.toStringAsFixed(1)}s NO LANCE ${slowest.moveNumber}' : ''}',
            style: const TextStyle(fontSize: 11, letterSpacing: 1),
          ),
        ),
      ],
    );
  }

  String _skillTxt(double? v) =>
      v == null ? 'SEM DADOS' : v.toStringAsFixed(0);
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

class _AccuracyDial extends StatelessWidget {
  const _AccuracyDial({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value.toStringAsFixed(1),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                fontSize: 8.5, letterSpacing: 1.5, color: NoirPalette.textDim)),
        const SizedBox(height: 6),
        SizedBox(
          width: 110,
          child: ClipRect(
            child: LinearProgressIndicator(
                value: (value / 100).clamp(0, 1).toDouble(), minHeight: 5),
          ),
        ),
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

String _depthLabel(int depth) {
  if (depth <= 8) return 'RAPIDA';
  if (depth >= 15) return 'PROFUNDA';
  return 'PADRAO';
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
                          height: up ? h.toDouble() : 0, color: Colors.white),
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

class _EvalChartPainter extends CustomPainter {
  _EvalChartPainter({required this.timeline});

  final List<double> timeline;

  @override
  void paint(Canvas canvas, Size size) {
    if (timeline.isEmpty) return;
    final axisPaint = Paint()
      ..color = const Color(0xFF2E2E2E)
      ..strokeWidth = 1;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axisPaint);

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < timeline.length; i++) {
      final x = timeline.length == 1
          ? size.width / 2
          : i / (timeline.length - 1) * size.width;
      final y = size.height - (timeline[i] / 100) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    final last = timeline.last;
    final lx = size.width;
    final ly = size.height - (last / 100) * size.height;
    canvas.drawCircle(
        Offset(lx - 2, ly), 3, Paint()..color = NoirPalette.pieceGold);
  }

  @override
  bool shouldRepaint(covariant _EvalChartPainter old) =>
      old.timeline != timeline;
}

class _MoveTable extends StatelessWidget {
  const _MoveTable({
    required this.history,
    required this.labels,
    required this.evalTexts,
    required this.losses,
    required this.selectedPly,
    required this.onSelect,
  });

  final List<String> history;
  final List<MoveLabel> labels;
  final List<String> evalTexts;
  final List<double> losses;
  final int selectedPly;
  final void Function(int ply) onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < history.length; i += 2) {
      final n = i ~/ 2 + 1;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 30,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('$n.',
                      style: const TextStyle(
                          fontSize: 11, color: NoirPalette.textDim)),
                )),
            Expanded(
                child: _MoveCell(
              san: history[i],
              label: labels[i],
              evalTxt: evalTexts[i + 1],
              loss: losses.length > i ? losses[i] : 0,
              selected: selectedPly == i + 1,
              onTap: () => onSelect(i + 1),
            )),
            if (i + 1 < history.length)
              Expanded(
                  child: _MoveCell(
                san: history[i + 1],
                label: labels[i + 1],
                evalTxt: evalTexts[i + 2],
                loss: losses.length > i + 1 ? losses[i + 1] : 0,
                selected: selectedPly == i + 2,
                onTap: () => onSelect(i + 2),
              ))
            else
              const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ));
    }
    return Column(children: rows);
  }
}

class _MoveCell extends StatelessWidget {
  const _MoveCell({
    required this.san,
    required this.label,
    required this.evalTxt,
    required this.loss,
    required this.selected,
    required this.onTap,
  });

  final String san;
  final MoveLabel label;
  final String evalTxt;
  final double loss;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _labelColors[label] ?? Colors.white;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
              color: selected ? Colors.white : Colors.transparent, width: 1),
          color: selected ? NoirPalette.surfaceHigh : Colors.transparent,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${GameReviewService.labelEmojis[label]} $san',
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
            Text(
                '${GameReviewService.labelNames[label]} · $evalTxt${loss > 7 ? ' · -${loss.toStringAsFixed(0)}%' : ''}',
                style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 0.5,
                    color: NoirPalette.textDim)),
          ],
        ),
      ),
    );
  }
}
