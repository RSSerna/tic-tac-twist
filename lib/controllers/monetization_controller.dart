import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ads_service.dart';
import '../services/purchase_service.dart';
import '../theme/board_skin.dart';
import '../theme/skin.dart';
import 'age_gate_controller.dart';
import 'board_skin_controller.dart';
import 'skin_controller.dart';

/// Interstitials only every few games (product doc §2.1: "frequency-capped")
/// — never on every single game, and never at all once ads are removed.
const int interstitialEveryNGames = 3;

/// Orchestrates ads + purchases: initialising the ad SDK with the
/// mixed-audience config once the age gate has answered, reacting to
/// completed purchases (remove-ads suppresses future interstitials; the
/// skin pack unlocks through the same [SkinController] the achievement
/// route uses), and the between-games frequency cap.
class MonetizationController extends Notifier<void> {
  static const _gamesSinceAdKey = 'nested_game.ads.games_since_interstitial';

  StreamSubscription<ProductId>? _purchaseSubscription;

  @override
  void build() {
    _purchaseSubscription =
        ref.read(purchaseServiceProvider).purchases.listen(_onPurchased);
    ref.onDispose(() {
      _purchaseSubscription?.cancel();
    });
  }

  Future<void> _onPurchased(ProductId product) async {
    switch (product) {
      case ProductId.removeAds:
        await ref.read(purchaseServiceProvider).markRemoved();
      case ProductId.skinBurgerStack:
        await ref.read(skinControllerProvider.notifier).unlockSkin(GameSkin.burgerStack);
      case ProductId.boardRock:
        await ref.read(boardSkinControllerProvider.notifier).unlock(BoardSkin.rock);
    }
  }

  /// Call once the age gate has answered — never before, since the ad
  /// request configuration (product doc §1: non-personalised ads for
  /// children) depends on it.
  Future<void> initialize() async {
    final isChild = ref.read(ageGateControllerProvider).value ?? true;
    await ref.read(adsServiceProvider).initialize(isChild: isChild);
  }

  /// Call when the player returns to the menu after a finished game — never
  /// mid-game, and never between the rematch tap and the new game (design
  /// doc §3.5: "never place an ad... between the tap and the new game").
  Future<void> onReturnedToMenuAfterGame() async {
    if (await ref.read(purchaseServiceProvider).isRemoved()) return;

    final prefs = await SharedPreferences.getInstance();
    final gamesSinceAd = (prefs.getInt(_gamesSinceAdKey) ?? 0) + 1;
    if (gamesSinceAd < interstitialEveryNGames) {
      await prefs.setInt(_gamesSinceAdKey, gamesSinceAd);
      return;
    }
    await prefs.setInt(_gamesSinceAdKey, 0);
    await ref.read(adsServiceProvider).showInterstitialIfLoaded();
  }
}

final monetizationControllerProvider =
    NotifierProvider<MonetizationController, void>(MonetizationController.new);
