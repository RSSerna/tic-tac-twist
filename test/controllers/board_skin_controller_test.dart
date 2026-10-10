import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/board_skin_controller.dart';
import 'package:nested_game/controllers/monetization_controller.dart';
import 'package:nested_game/services/ads_service.dart';
import 'package:nested_game/services/board_skin_service.dart';
import 'package:nested_game/services/purchase_service.dart';
import 'package:nested_game/theme/board_skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  BoardSkinController notifier() =>
      container.read(boardSkinControllerProvider.notifier);

  test('starts on classic with nothing purchased', () async {
    final state = await container.read(boardSkinControllerProvider.future);
    expect(state.selected, BoardSkin.classic);
    expect(state.isUnlocked(BoardSkin.sandstone), isTrue);
    expect(state.isUnlocked(BoardSkin.rock), isFalse);
  });

  test('selecting a free board persists it', () async {
    await container.read(boardSkinControllerProvider.future);
    await notifier().select(BoardSkin.sandstone);

    expect(
      container.read(boardSkinControllerProvider).value!.selected,
      BoardSkin.sandstone,
    );
    expect(
      await SharedPreferencesBoardSkinService().selectedId(),
      'sandstone',
    );
  });

  test('a locked board cannot be selected — the controller is the gate', () async {
    await container.read(boardSkinControllerProvider.future);
    await notifier().select(BoardSkin.rock);

    expect(
      container.read(boardSkinControllerProvider).value!.selected,
      BoardSkin.classic,
    );
    expect(await SharedPreferencesBoardSkinService().selectedId(), 'classic');
  });

  test('unlocking makes a board selectable, and survives a restart', () async {
    await container.read(boardSkinControllerProvider.future);
    expect(await notifier().unlock(BoardSkin.rock), isTrue);
    expect(await notifier().unlock(BoardSkin.rock), isFalse); // already owned
    await notifier().select(BoardSkin.rock);

    final reloaded = ProviderContainer();
    addTearDown(reloaded.dispose);
    final state = await reloaded.read(boardSkinControllerProvider.future);
    expect(state.isUnlocked(BoardSkin.rock), isTrue);
    expect(state.selected, BoardSkin.rock);
  });

  test('an unknown saved id falls back to classic', () async {
    SharedPreferences.setMockInitialValues({
      'nested_game.board.selected': 'retired_board',
    });
    final state = await container.read(boardSkinControllerProvider.future);
    expect(state.selected, BoardSkin.classic);
  });

  test('a saved board that is not unlocked never renders', () async {
    // e.g. a refunded purchase: the choice outlives the ownership.
    SharedPreferences.setMockInitialValues({
      'nested_game.board.selected': 'rock',
    });
    final state = await container.read(boardSkinControllerProvider.future);
    expect(state.selected, BoardSkin.classic);
  });

  test('a completed Rock purchase unlocks the Rock board', () async {
    final purchases = FakePurchaseService();
    final scoped = ProviderContainer(
      overrides: [
        adsServiceProvider.overrideWithValue(FakeAdsService()),
        purchaseServiceProvider.overrideWithValue(purchases),
      ],
    );
    addTearDown(scoped.dispose);
    addTearDown(purchases.dispose);

    scoped.read(monetizationControllerProvider); // builds the subscription
    purchases.completePurchase(ProductId.boardRock);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final state = await scoped.read(boardSkinControllerProvider.future);
    expect(state.isUnlocked(BoardSkin.rock), isTrue);
  });
}
