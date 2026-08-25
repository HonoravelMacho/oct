import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../app_constants.dart';

class AdFlow {
  AdFlow._();

  static bool _mobileAdsInitialized = false;

  static Future<bool> showRewardedForCredits(BuildContext context) async {
    if (!AppConstants.useRealAds) {
      final result = await Navigator.of(context).pushNamed('/reward_sim');
      return result == true;
    }
    return _showRealRewarded();
  }

  static Future<bool> _showRealRewarded() async {
    if (!_mobileAdsInitialized) {
      await MobileAds.instance.initialize();
      _mobileAdsInitialized = true;
    }
    final completer = CompleterAdGate();
    RewardedAd.load(
      adUnitId: AppConstants.admobTestRewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              completer.complete(false);
            },
          );
          ad.show(
            onUserEarnedReward: (_, _) => completer.complete(true),
          );
        },
        onAdFailedToLoad: (error) {
          completer.complete(false);
        },
      ),
    );
    return completer.future;
  }
}

class CompleterAdGate {
  final completer = Completer<bool>();
  Future<bool> get future => completer.future;
  void complete(bool v) {
    if (!completer.isCompleted) completer.complete(v);
  }
}
