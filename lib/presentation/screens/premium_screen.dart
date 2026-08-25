import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../core/noir_theme.dart';
import '../../data/download/premium_package_downloader.dart';
import '../credit_gate.dart';
import '../providers/premium_provider.dart';
import '../providers/session_provider.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  StreamSubscription<DownloadState>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final premium = context.watch<PremiumProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('PREMIUM')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration:
                BoxDecoration(border: Border.all(color: NoirPalette.border)),
            child: Column(
              children: [
                const Text('OCT PREMIUM',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4)),
                const SizedBox(height: 6),
                const Text('R\$ 29,90 - PAGAMENTO UNICO',
                    style: TextStyle(fontSize: 13, letterSpacing: 1.5)),
                const Text('VITALICIO - SEM ASSINATURA',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: NoirPalette.textDim)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _benefit('SEM ANUNCIOS PARA SEMPRE'),
          _benefit('BASE COMPLETA: ATE ${AppConstants.premiumTotalLabel} TATICAS'),
          _benefit('DOWNLOAD EM SEGUNDO PLANO + OFFLINE'),
          _benefit('PROGRESSO 100% EM TODOS OS TEMAS'),
          const SizedBox(height: 18),
          if (!session.premiumUnlocked)
            ElevatedButton(
              onPressed: () {
                session.setPremiumUnlocked(true);
                showSnack(context, 'PREMIUM ATIVADO (MODO DEMO)');
              },
              child: const Text('COMPRAR (DEMONSTRACAO)'),
            )
          else
            const Center(
              child: Text('PREMIUM ATIVO NESTE DISPOSITIVO',
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 2, color: Colors.white70)),
            ),
          const SizedBox(height: 26),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: NoirPalette.border),
              color: NoirPalette.surface,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BAIXAR BASE MASSIVA DE TATICAS',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(
                  session.premiumUnlocked
                      ? 'PACOTE COMPLETO (${AppConstants.premiumTotalLabel} POSICOES)'
                      : 'REQUER PREMIUM ATIVO',
                  style: const TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1,
                      color: NoirPalette.textDim),
                ),
                const SizedBox(height: 12),
                ClipRect(
                  child: LinearProgressIndicator(
                    value: premium.downloadState.phase == DownloadPhase.idle
                        ? 0
                        : premium.downloadState.progress.clamp(0.0, 1.0),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  premium.statusText,
                  style: const TextStyle(
                      fontSize: 10, letterSpacing: 1, color: NoirPalette.textDim),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: session.premiumUnlocked &&
                          !premium.downloading
                      ? () => _startDownload(context)
                      : null,
                  child: Text(
                    premium.downloadState.phase == DownloadPhase.done
                        ? 'BASE JA INSTALADA - BAIXAR NOVAMENTE'
                        : 'INICIAR DOWNLOAD',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'MODO TESTE: PACOTE DEMONSTRATIVO COMPACTO VALIDA O FLUXO COMPLETO '
            '(DOWNLOAD, DESCOMPRESSAO E INJECAO NO SQLITE). O PACOTE REAL DE '
            '${AppConstants.premiumTotalLabel} SERA SERVIDO VIA URL NA PUBLICACAO.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 8.5, height: 1.5, color: Color(0xFF666666)),
          ),
        ],
      ),
    );
  }

  void _startDownload(BuildContext context) {
    final session = context.read<SessionProvider>();
    final premium = context.read<PremiumProvider>();
    final db = session.db;
    if (db == null) {
      showSnack(context, 'BANCO INDISPONIVEL');
      return;
    }
    _sub?.cancel();
    premium.startDownload(PremiumPackageDownloader(
      insertPuzzles: (puzzles) => db.insertPuzzles(puzzles),
    ));
  }

  Widget _benefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check, size: 14, color: Colors.white70),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}
