import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../core/noir_theme.dart';
import '../providers/session_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: const [
            Text(AppConstants.appName),
            Text(
              'LABORATORIO OFFLINE DE XADREZ',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 4,
                color: NoirPalette.textDim,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'CONFIGURAÇÕES',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(20),
            shrinkWrap: true,
            children: [
              _StatusHeader(session: session),
              const SizedBox(height: 18),
              if (!session.dbReady)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Column(
                    children: [
                      LinearProgressIndicator(minHeight: 3),
                      SizedBox(height: 8),
                      Text(
                        'PREPARANDO BASE DE TATICAS...',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: NoirPalette.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              _MenuButton(
                label: 'JOGAR VS BOT',
                subtitle: session.engineReady
                    ? 'MOTOR: ${session.engineName} · VALE RATING OFFLINE'
                    : 'INICIANDO MOTOR...',
                enabled: session.dbReady,
                onTap: () => Navigator.pushNamed(context, '/play'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'TREINAR TATICAS',
                subtitle: 'TEMAS - FORK, MATE EM 2 E MAIS',
                enabled: session.dbReady,
                onTap: () => Navigator.pushNamed(context, '/tactics'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'DASHBOARD',
                subtitle: 'PONTOS FORTES, FRACOS E O QUE ESTUDAR',
                enabled: true,
                onTap: () => Navigator.pushNamed(context, '/dashboard'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'PROGRESSO',
                subtitle: '% CONCLUIDO POR TEMA',
                enabled: session.dbReady,
                onTap: () => Navigator.pushNamed(context, '/progress'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: session.fullBaseInstalled
                    ? 'VERSAO COMPLETA INSTALADA'
                    : 'BAIXAR VERSAO COMPLETA',
                subtitle: session.fullBaseInstalled
                    ? 'BASE MASSIVA DISPONIVEL OFFLINE'
                    : 'GRATIS - BAIXE QUANDO TIVER UM WIFI BOM',
                enabled: true,
                onTap: () => Navigator.pushNamed(context, '/premium'),
              ),
              const SizedBox(height: 12),
              _MenuButton(
                label: 'CONFIGURACOES',
                subtitle: 'PREFERENCIAS DO LABORATORIO',
                enabled: true,
                onTap: () => Navigator.pushNamed(context, '/settings'),
              ),
              const SizedBox(height: 24),
              const Text(
                '100% GRATUITO - 100% OFFLINE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 3,
                  color: NoirPalette.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.session});

  final SessionProvider session;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: NoirPalette.border),
        color: NoirPalette.surface,
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatBadge(label: 'RATING JOGOS', value: '${session.gameElo}'),
          Container(width: 1, height: 36, color: NoirPalette.border),
          _StatBadge(label: 'RATING TATICAS', value: '${session.tacticElo}'),
          Container(width: 1, height: 36, color: NoirPalette.border),
          _StatBadge(
              label: 'PARTIDAS', value: '${session.stats.gamesPlayed}'),
        ],
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 8.5, letterSpacing: 1.5, color: NoirPalette.textDim)),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: NoirPalette.surface,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: NoirPalette.border)),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2)),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 1.5,
                              color: NoirPalette.textDim)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
