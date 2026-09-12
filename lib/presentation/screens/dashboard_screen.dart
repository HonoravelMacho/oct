import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/noir_theme.dart';
import '../../domain/entities/puzzle.dart';
import '../../domain/services/game_review_service.dart';
import '../../domain/services/study_recommendation_service.dart';
import '../providers/session_provider.dart';
import '../providers/tactics_controller.dart';

/// Dashboard do laboratório: status do usuário com base em TODOS os
/// jogos contra o bot — pontos fortes/fracos, o que estudar, coisas
/// boas e a melhorar.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final stats = session.stats;
    final wins = stats.wins;
    final losses = stats.losses;
    final draws = stats.draws;
    final total = wins + losses + draws;
    final avgAcc = stats.avgAccuracy;
    final bestAcc = stats.bestAccuracy;
    final skills = stats.skillAverages();
    final labels = stats.labelTotals();
    final history = stats.ratingHistory;

    final recs = StudyRecommendationService.fromDashboard(
      abertura: skills.abertura,
      meio: skills.meio,
      fim: skills.fim,
      tatica: skills.tatica,
      labels: labels,
    );

    final strengths = _strengths(skills, labels);
    final weaknesses = _weaknesses(skills, labels);

    return Scaffold(
      appBar: AppBar(title: const Text('DASHBOARD')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Rating + evolução
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border),
              color: NoirPalette.surface,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SEU RATING OFFLINE (VS BOT)',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        color: NoirPalette.textDim)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${session.gameElo}',
                        style: const TextStyle(
                            fontSize: 38, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${stats.gamesPlayed} PARTIDAS · ${session.tacticElo} TATICAS',
                          style: const TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 1.2,
                              color: NoirPalette.textDim),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (history.length >= 2)
                  SizedBox(
                    height: 64,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _RatingPainter(history: history),
                    ),
                  )
                else
                  const Text(
                    'JOGUE 2+ PARTIDAS PARA VER SUA EVOLUÇÃO AQUI.',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.5,
                        color: NoirPalette.textDim),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // W/D/L + precisão
          Row(
            children: [
              Expanded(
                  child: _Tile(
                      label: 'VITÓRIAS',
                      value: '$wins',
                      sub: total == 0
                          ? '-'
                          : '${(wins / total * 100).toStringAsFixed(0)}%')),
              const SizedBox(width: 8),
              Expanded(
                  child: _Tile(label: 'EMPATES', value: '$draws', sub: '')),
              const SizedBox(width: 8),
              Expanded(
                  child: _Tile(
                      label: 'DERROTAS',
                      value: '$losses',
                      sub: total == 0
                          ? '-'
                          : '${(losses / total * 100).toStringAsFixed(0)}%')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _Tile(
                      label: 'PRECISÃO MÉDIA',
                      value: stats.reviewsCount == 0
                          ? '-'
                          : avgAcc.toStringAsFixed(1),
                      sub: '${stats.reviewsCount} ANÁLISES')),
              const SizedBox(width: 8),
              Expanded(
                  child: _Tile(
                      label: 'MELHOR PRECISÃO',
                      value:
                          bestAcc == 0 ? '-' : bestAcc.toStringAsFixed(1),
                      sub: 'SUA MARCA')),
            ],
          ),
          const SizedBox(height: 12),
          const _Section('COISAS BOAS (CONTINUE!)'),
          const SizedBox(height: 6),
          if (strengths.isEmpty)
            const _EmptyLine(
                text: 'JOGUE E ANALISE PARTIDAS PARA DESCOBRIR SEUS PONTOS FORTES.')
          else
            ...strengths.map((s) => _Bullet(text: s, good: true)),
          const SizedBox(height: 12),
          const _Section('PARA MELHORAR'),
          const SizedBox(height: 6),
          if (weaknesses.isEmpty)
            const _EmptyLine(
                text: 'SEM SINAL DE FRAQUEZA POR ENQUANTO. BOM TRABALHO!')
          else
            ...weaknesses.map((s) => _Bullet(text: s, good: false)),
          const SizedBox(height: 12),
          const _Section('HABILIDADES POR FASE'),
          const SizedBox(height: 6),
          _SkillBar(label: 'ABERTURA', value: skills.abertura),
          _SkillBar(label: 'MEIO-JOGO', value: skills.meio),
          _SkillBar(label: 'FINAIS', value: skills.fim),
          _SkillBar(label: 'TÁTICA', value: skills.tatica),
          const SizedBox(height: 12),
          const _Section('O QUE ESTUDAR AGORA'),
          const SizedBox(height: 6),
          if (total == 0 && stats.reviewsCount == 0)
            const _EmptyLine(
                text:
                    'JOGUE UMA PARTIDA CONTRA O BOT E ABRA A ANÁLISE. SUAS RECOMENDAÇÕES APARECEM AQUI.')
          else
            ...recs.map((r) => _StudyTile(rec: r)),
        ],
      ),
    );
  }

  List<String> _strengths(
      ({double? abertura, double? meio, double? fim, double? tatica}) s,
      Map<String, int> labels) {
    final out = <String>[];
    void good(String name, double? v) {
      if (v != null && v >= 82) {
        out.add('$name SÓLIDO (${v.toStringAsFixed(0)}) — MANTENHA O RITMO');
      }
    }

    good('ABERTURA', s.abertura);
    good('MEIO-JOGO', s.meio);
    good('FINAIS', s.fim);
    good('TÁTICA', s.tatica);
    final brilliant = (labels[MoveLabel.brilliant.name] ?? 0) +
        (labels[MoveLabel.great.name] ?? 0) +
        (labels[MoveLabel.best.name] ?? 0);
    if (brilliant >= 5) {
      out.add('$brilliant GRANDES LANCES NO TOTAL — VISÃO AFIADA');
    }
    return out.take(4).toList();
  }

  List<String> _weaknesses(
      ({double? abertura, double? meio, double? fim, double? tatica}) s,
      Map<String, int> labels) {
    final out = <String>[];
    void bad(String name, double? v) {
      if (v != null && v < 78) {
        out.add('$name FRACO (${v.toStringAsFixed(0)}) — PRIORIDADE DE ESTUDO');
      }
    }

    bad('ABERTURA', s.abertura);
    bad('MEIO-JOGO', s.meio);
    bad('FINAIS', s.fim);
    bad('TÁTICA', s.tatica);
    final bl = labels[MoveLabel.blunder.name] ?? 0;
    final mi = labels[MoveLabel.mistake.name] ?? 0;
    final miss = labels[MoveLabel.miss.name] ?? 0;
    if (bl > 0) out.add('$bl DESASTRE(S) NO TOTAL — CALCULE 2X ANTES DE JOGAR');
    if (mi >= 3) out.add('$mi ERROS — REVISE SEGURANÇA DAS PEÇAS');
    if (miss > 0) {
      out.add('$miss CHANCE(S) PERDIDA(S) — TREINE PADRÕES TÁTICOS');
    }
    return out.take(5).toList();
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 10, letterSpacing: 2.5, color: NoirPalette.textDim));
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.sub});
  final String label;
  final String value;
  final String sub;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: NoirPalette.border),
        color: NoirPalette.surface,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1.5,
                  color: NoirPalette.textDim)),
          if (sub.isNotEmpty)
            Text(sub,
                style: const TextStyle(
                    fontSize: 8,
                    letterSpacing: 1,
                    color: NoirPalette.textDim)),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.good});
  final String text;
  final bool good;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        border: Border.all(color: NoirPalette.border),
        color: NoirPalette.surface,
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Text(good ? '✓' : '!',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: good ? Colors.white : NoirPalette.textDim)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: NoirPalette.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Text(text,
          style: const TextStyle(
              fontSize: 10, letterSpacing: 0.5, color: NoirPalette.textDim)),
    );
  }
}

class _SkillBar extends StatelessWidget {
  const _SkillBar({required this.label, required this.value});
  final String label;
  final double? value;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
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
              Text(label,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              Text(value == null ? 'SEM DADOS' : value!.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRect(
            child: LinearProgressIndicator(
              value: value == null ? 0 : (value! / 100).clamp(0, 1).toDouble(),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StudyTile extends StatelessWidget {
  const _StudyTile({required this.rec});
  final StudyRecommendation rec;
  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text(PuzzleCatalog.labelOf(rec.theme).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(rec.reason,
                    style: const TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.8,
                        color: NoirPalette.textDim)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () {
              final tactics = context.read<TacticsController>();
              tactics.openTheme(rec.theme);
              Navigator.pushNamed(context, '/tactics');
            },
            child: const Text('TREINAR'),
          ),
        ],
      ),
    );
  }
}

class _RatingPainter extends CustomPainter {
  _RatingPainter({required this.history});
  final List<int> history;
  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) return;
    final minV = history.reduce((a, b) => a < b ? a : b).toDouble();
    final maxV = history.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < history.length; i++) {
      final x = i / (history.length - 1) * size.width;
      final y = size.height - ((history[i] - minV) / span) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RatingPainter old) =>
      old.history != history;
}
