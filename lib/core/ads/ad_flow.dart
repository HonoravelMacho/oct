import 'package:flutter/material.dart';

import '../app_constants.dart';

/// Fluxo de rewarded da Fase 1: 100% mock (tela `/reward_sim`).
///
/// O plugin nativo `google_mobile_ads` foi removido de propósito nesta fase:
/// além de não ser usado (`useRealAds == false`), ele puxa
/// `androidx.work:work-runtime`, que quebrava o app na abertura em release
/// (crash no `InitializationProvider` → `WorkDatabase` sob R8).
///
/// Fase 2 (Play Store): re-adicionar `google_mobile_ads` ao pubspec,
/// o meta-data `APPLICATION_ID` ao AndroidManifest e implementar
/// [_showRealRewarded] com `RewardedAd` real.
class AdFlow {
  AdFlow._();

  static Future<bool> showRewardedForCredits(BuildContext context) async {
    if (!AppConstants.useRealAds) {
      final result = await Navigator.of(context).pushNamed('/reward_sim');
      return result == true;
    }
    return _showRealRewarded(context);
  }

  static Future<bool> _showRealRewarded(BuildContext context) async {
    // Plugin nativo ausente na Fase 1: cai no simulado para nunca travar.
    if (!context.mounted) return false;
    final result = await Navigator.of(context).pushNamed('/reward_sim');
    return result == true;
  }
}
