import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_constants.dart';
import '../../core/noir_theme.dart';
import '../../data/download/premium_package_downloader.dart';
import '../credit_gate.dart';
import '../providers/premium_provider.dart';
import '../providers/session_provider.dart';

/// Tela "Versão completa": 100% gratuita. O usuário baixa a base massiva
/// de táticas quando estiver num Wi-Fi bom e usa tudo offline depois.
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
      appBar: AppBar(title: const Text('VERSAO COMPLETA')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration:
                BoxDecoration(border: Border.all(color: NoirPalette.border)),
            child: const Column(
              children: [
                Text('OCT COMPLETO',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4)),
                SizedBox(height: 6),
                Text('100% GRATUITO - PARA SEMPRE',
                    style: TextStyle(fontSize: 13, letterSpacing: 1.5)),
                Text('SEM ANUNCIOS - SEM PAGAMENTOS',
                    style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: NoirPalette.textDim)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _benefit('TODO O APP LIBERADO DE GRAÇA'),
          _benefit('BASE COMPLETA: ATE ${AppConstants.premiumTotalLabel} TATICAS'),
          _benefit('BAIXE NO WI-FI BOM E USE OFFLINE DEPOIS'),
          _benefit('PROGRESSO 100% EM TODOS OS TEMAS'),
          const SizedBox(height: 18),
          if (session.fullBaseInstalled)
            const Center(
              child: Text('VERSAO COMPLETA INSTALADA NESTE DISPOSITIVO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 2, color: Colors.white70)),
            )
          else
            const Center(
              child: Text('DICA: CONECTE-SE A UM WI-FI BOM ANTES DE BAIXAR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10, letterSpacing: 1.5, color: Colors.white70)),
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
                  session.fullBaseInstalled
                      ? 'PACOTE COMPLETO (${AppConstants.premiumTotalLabel} POSICOES) - PODE BAIXAR DE NOVO SE QUISER'
                      : 'PACOTE COMPLETO (${AppConstants.premiumTotalLabel} POSICOES) - GRATIS',
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
                  onPressed: !premium.downloading
                      ? () => _startDownload(context)
                      : null,
                  child: Text(
                    premium.downloadState.phase == DownloadPhase.done
                        ? 'BASE JA INSTALADA - BAIXAR NOVAMENTE'
                        : 'BAIXAR AGORA (USE WI-FI)',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'MODO TESTE: PACOTE DEMONSTRATIVO COMPACTO VALIDA O FLUXO COMPLETO '
            '(DOWNLOAD, DESCOMPRESSAO E INJECAO NO SQLITE). O PACOTE REAL DE '
            '6.000.000 SERA SERVIDO VIA URL NA PUBLICACAO.',
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
    final sub = premium.startDownloadAndTrack(
      PremiumPackageDownloader(
        insertPuzzles: (puzzles) => db.insertPuzzles(puzzles),
      ),
      onDone: (_) {
        if (!context.mounted) return;
        session.setFullBaseInstalled(true);
        showSnack(context, 'VERSAO COMPLETA INSTALADA - BOM TREINO!');
      },
    );
    _sub = sub;
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
