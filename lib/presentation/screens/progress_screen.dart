import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../core/noir_theme.dart';
import '../../domain/entities/puzzle.dart';
import '../providers/session_provider.dart';
import '../providers/tactics_controller.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
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
    final session = context.watch<SessionProvider>();
    final overall = controller.overall;

    return Scaffold(
      appBar: AppBar(title: const Text('PROGRESSO')),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overall.total == 0
                              ? '0.00000%'
                              : '${overall.percent.toStringAsFixed(5)}%',
                          style: const TextStyle(
                              fontSize: 34, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BASE ${session.premiumUnlocked ? 'COMPLETA' : 'GRATUITA'}',
                          style: const TextStyle(
                              fontSize: 9,
                              letterSpacing: 2.5,
                              color: NoirPalette.textDim),
                        ),
                      ],
                    ),
                    Text(
                      '${overall.solved} / ${overall.total}',
                      style: const TextStyle(
                          fontSize: 13, color: NoirPalette.textDim),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRect(
                  child: LinearProgressIndicator(
                    value: overall.total == 0 ? 0 : overall.solved / overall.total,
                    minHeight: 8,
                  ),
                ),
                if (!session.premiumUnlocked) ...[
                  const SizedBox(height: 10),
                  Text(
                    'BASE GRATIS: ${AppConstants.freeBaseTarget} TATICAS - '
                    'PREMIUM LIBERA ATE ${AppConstants.premiumTotalLabel}',
                    style: const TextStyle(
                        fontSize: 9, letterSpacing: 1, color: NoirPalette.textDim),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...controller.themeProgressList.map((tp) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ThemeProgressTile(tp: tp),
              )),
        ],
      ),
    );
  }
}

class _ThemeProgressTile extends StatelessWidget {
  const _ThemeProgressTile({required this.tp});

  final ThemeProgress tp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: NoirPalette.border),
        color: NoirPalette.surface,
      ),
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5),
                ),
              ),
              Text('${tp.percent.toStringAsFixed(5)}%',
                  style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRect(
            child: LinearProgressIndicator(
              value: tp.total == 0 ? 0 : tp.solved / tp.total,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}
