import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/monetization_controller.dart';
import 'package:nested_game/controllers/age_gate_controller.dart';
import 'package:nested_game/controllers/skin_controller.dart';
import 'package:nested_game/services/ads_service.dart';
import 'package:nested_game/services/age_gate_service.dart';
import 'package:nested_game/services/purchase_service.dart';
import 'package:nested_game/theme/skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeAdsService ads;
  late FakePurchaseService purchases;
  late ProviderContainer container;

  setUp(() {
    ads = FakeAdsService();
    purchases = FakePurchaseService();
    container = ProviderContainer(overrides: [
      adsServiceProvider.overrideWithValue(ads),
      purchaseServiceProvider.overrideWithValue(purchases),
    ]);
    addTearDown(container.dispose);
    addTearDown(purchases.dispose);
  });

  group('interstitial frequency cap', () {
    test('shows nothing before the cap is reached', () async {
      final controller = container.read(monetizationControllerProvider.notifier);
      for (var i = 0; i < interstitialEveryNGames - 1; i++) {
        await controller.onReturnedToMenuAfterGame();
      }
      expect(ads.showCount, 0);
    });

    test('shows exactly once every Nth return to the menu', () async {
      final controller = container.read(monetizationControllerProvider.notifier);
      for (var i = 0; i < interstitialEveryNGames; i++) {
        await controller.onReturnedToMenuAfterGame();
      }
      expect(ads.showCount, 1);

      for (var i = 0; i < interstitialEveryNGames - 1; i++) {
        await controller.onReturnedToMenuAfterGame();
      }
      expect(ads.showCount, 1); // not due again yet

      await controller.onReturnedToMenuAfterGame();
      expect(ads.showCount, 2);
    });

    test('ads removed suppresses every interstitial', () async {
      purchases.removed = true;
      final controller = container.read(monetizationControllerProvider.notifier);
      for (var i = 0; i < interstitialEveryNGames * 3; i++) {
        await controller.onReturnedToMenuAfterGame();
      }
      expect(ads.showCount, 0);
    });
  });

  group('purchases', () {
    test('a completed remove-ads purchase marks ads removed', () async {
      container.read(monetizationControllerProvider); // build the controller/subscription
      purchases.completePurchase(ProductId.removeAds);
      await settle();

      expect(purchases.removed, isTrue);
    });

    test('a completed skin-pack purchase unlocks the Burger Stack skin', () async {
      container.read(monetizationControllerProvider);
      purchases.completePurchase(ProductId.skinBurgerStack);
      await settle();

      final skins = await container.read(skinControllerProvider.future);
      expect(skins.isUnlocked(GameSkin.burgerStack), isTrue);
    });
  });

  group('initialize', () {
    test('passes the age gate answer through to the ads service', () async {
      await SharedPreferencesAgeGateService().setIsChild(true);
      await container.read(ageGateControllerProvider.future);

      await container.read(monetizationControllerProvider.notifier).initialize();

      expect(ads.lastIsChild, isTrue);
    });
  });
}
