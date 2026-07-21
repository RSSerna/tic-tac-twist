import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Interstitial ads only (product doc §2.1) — rewarded video exists to
/// grant chests, and the full chest system is deferred past this phase (see
/// CLAUDE.md's Phase 9 decisions), so there's nothing for a rewarded ad to
/// reward yet.
///
/// Google's officially published, safe-to-ship-in-development test ad unit
/// IDs are used here (see each constant) — swap for real AdMob ad unit IDs
/// before release, alongside the app IDs in AndroidManifest.xml /
/// Info.plist.
abstract interface class AdsService {
  /// Configures the mixed-audience ad request (product doc §1: children only
  /// see non-personalised ads) and loads the first interstitial. Call once,
  /// after the age gate has answered.
  Future<void> initialize({required bool isChild});

  bool get isInterstitialReady;

  /// Shows the currently-loaded interstitial, if any, and starts loading the
  /// next one. No-ops silently if nothing is loaded — never blocks or
  /// delays the navigation it's called alongside (design doc §4's "never
  /// block on ___" principle, applied to ads instead of animation/audio).
  Future<void> showInterstitialIfLoaded();
}

/// google_mobile_ads has no real platform channel under `flutter_test`
/// (same situation `audioServiceProvider` documents) — default to a no-op
/// there; production gets the real implementation.
final adsServiceProvider = Provider<AdsService>((ref) {
  if (Platform.environment['FLUTTER_TEST'] == 'true') {
    return const _NullAdsService();
  }
  return GoogleMobileAdsService();
});

class GoogleMobileAdsService implements AdsService {
  static final String _interstitialAdUnitId = Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';

  InterstitialAd? _interstitial;

  @override
  Future<void> initialize({required bool isChild}) async {
    await MobileAds.instance.initialize();
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        tagForChildDirectedTreatment:
            isChild ? TagForChildDirectedTreatment.yes : TagForChildDirectedTreatment.no,
        maxAdContentRating: isChild ? MaxAdContentRating.g : null,
      ),
    );
    await _loadInterstitial();
  }

  Future<void> _loadInterstitial() async {
    await InterstitialAd.load(
      adUnitId: _interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        // A failed load just means the next showInterstitialIfLoaded() is a
        // no-op — never worth surfacing to the player.
        onAdFailedToLoad: (error) => _interstitial = null,
      ),
    );
  }

  @override
  bool get isInterstitialReady => _interstitial != null;

  @override
  Future<void> showInterstitialIfLoaded() async {
    final ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
    );
    await ad.show();
  }
}

class _NullAdsService implements AdsService {
  const _NullAdsService();

  @override
  Future<void> initialize({required bool isChild}) async {}

  @override
  bool get isInterstitialReady => false;

  @override
  Future<void> showInterstitialIfLoaded() async {}
}
