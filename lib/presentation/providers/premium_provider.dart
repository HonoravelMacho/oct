import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/download/premium_package_downloader.dart';

class PremiumProvider extends ChangeNotifier {
  DownloadState downloadState = const DownloadState();
  StreamSubscription<DownloadState>? _subscription;

  bool get downloading =>
      downloadState.phase == DownloadPhase.downloading ||
      downloadState.phase == DownloadPhase.extracting ||
      downloadState.phase == DownloadPhase.importing;

  String get statusText {
    switch (downloadState.phase) {
      case DownloadPhase.idle:
        return 'AGUARDANDO INICIO';
      case DownloadPhase.downloading:
        final pct = (downloadState.progress * 100).toStringAsFixed(0);
        return '${downloadState.message} ($pct%)';
      case DownloadPhase.extracting:
        return downloadState.message;
      case DownloadPhase.importing:
        return '${downloadState.message} ${downloadState.importedCount} POSICOES';
      case DownloadPhase.done:
        return 'CONCLUIDO: +${downloadState.importedCount} TATICAS NO BANCO LOCAL';
      case DownloadPhase.error:
        return 'ERRO: ${downloadState.message}';
    }
  }

  void startDownload(PremiumPackageDownloader downloader) {
    startDownloadAndTrack(downloader, onDone: (_) {});
  }

  StreamSubscription<DownloadState> startDownloadAndTrack(
    PremiumPackageDownloader downloader, {
    void Function(DownloadState state)? onDone,
  }) {
    _subscription?.cancel();
    _subscription = downloader.run().listen(
          (state) {
            downloadState = state;
            notifyListeners();
            if (state.phase == DownloadPhase.done) {
              onDone?.call(state);
            }
          },
        );
    return _subscription!;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
