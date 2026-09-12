import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/noir_theme.dart';
import '../providers/session_provider.dart';

/// Configurações do laboratório offline.
/// Por enquanto é um esqueleto com "EM DESENVOLVIMENTO" para definirmos
/// juntos o que entra aqui (orientação do tabuleiro, som, profundidade
/// do motor, reset de estatísticas, etc).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('CONFIGURACOES')),
      body: ListView(
        padding: const EdgeInsets.all(16),
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
                const Text('LABORATORIO OFFLINE',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(
                  'RATING JOGOS ${session.gameElo} · RATING TATICAS ${session.tacticElo} · '
                  '${session.stats.gamesPlayed} PARTIDAS VS BOT',
                  style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      color: NoirPalette.textDim),
                ),
                const SizedBox(height: 6),
                const Text(
                  'SEU RATING É CALCULADO 100% OFFLINE A CADA PARTIDA '
                  'CONTRA O BOT (SISTEMA ELO: K=40/20/10).',
                  style: TextStyle(
                      fontSize: 9,
                      letterSpacing: 1,
                      color: NoirPalette.textDim),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _comingTile(
            icon: Icons.tune_outlined,
            title: 'PREFERÊNCIAS DE TREINO',
            subtitle: 'EM DESENVOLVIMENTO',
          ),
          _comingTile(
            icon: Icons.grid_on_outlined,
            title: 'TABULEIRO E SOM',
            subtitle: 'EM DESENVOLVIMENTO',
          ),
          _comingTile(
            icon: Icons.memory_outlined,
            title: 'MOTOR E PROFUNDIDADE',
            subtitle: 'EM DESENVOLVIMENTO',
          ),
          _comingTile(
            icon: Icons.delete_outline,
            title: 'APAGAR ESTATÍSTICAS',
            subtitle: 'EM DESENVOLVIMENTO',
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border),
            ),
            padding: const EdgeInsets.all(14),
            child: const Text(
              'EM DESENVOLVIMENTO\n\nEstamos decidindo o que entra aqui: orientação do tabuleiro, sons, nível padrão do bot, profundidade da análise, exportar PGN, zerar rating, etc. Volte em breve.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, height: 1.6, letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comingTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: NoirPalette.border),
        color: NoirPalette.surface,
      ),
      child: Opacity(
        opacity: 0.55,
        child: ListTile(
          leading: Icon(icon, size: 20),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
          subtitle: Text(subtitle,
              style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 2,
                  color: NoirPalette.textDim)),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: null,
        ),
      ),
    );
  }
}
