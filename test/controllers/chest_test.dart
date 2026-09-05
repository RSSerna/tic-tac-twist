import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/controllers/celebration_controller.dart';
import 'package:nested_game/controllers/chest_controller.dart';
import 'package:nested_game/controllers/emote_controller.dart';
import 'package:nested_game/controllers/skin_controller.dart';
import 'package:nested_game/engines/common/game_mode.dart';
import 'package:nested_game/services/daily_challenge_service.dart';
import 'package:nested_game/theme/celebration.dart';
import 'package:nested_game/theme/emote.dart';
import 'package:nested_game/theme/skin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fills today's set so the chest is claimable.
Future<void> finishToday(DailyChallengeService service) async {
  final today = DateTime.now();
  await service.record(DailyChallenge.playTwoGames, today, amount: 2);
  await service.record(DailyChallenge.winOneGame, today);
  await service.record(DailyChallenge.beatToughAi, today);
  for (final mode in GameMode.values) {
    await service.recordModePlayed(mode, today);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('an unfinished day grants nothing', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(await container.read(chestControllerProvider).claimDaily(), isNull);
    // And nothing was unlocked as a side effect.
    final emotes = await container.read(emoteControllerProvider.future);
    expect(emotes.unlockedIds, isEmpty);
  });

  test('a finished day grants exactly one locked cosmetic, once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await finishToday(container.read(dailyChallengeServiceProvider));

    final reward = await container.read(chestControllerProvider).claimDaily();
    expect(reward, isNotNull);

    final unlockedCount =
        (await container.read(
          skinControllerProvider.future,
        )).unlockedIds.length +
        (await container.read(
          emoteControllerProvider.future,
        )).unlockedIds.length +
        (await container.read(
          celebrationControllerProvider.future,
        )).unlockedIds.length;
    expect(unlockedCount, 1);

    // The day is spent — a second claim grants nothing more.
    expect(await container.read(chestControllerProvider).claimDaily(), isNull);
    expect(unlockedCount, 1);
  });

  test('the reward is one the player did not already own', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await finishToday(container.read(dailyChallengeServiceProvider));

    // Unlock everything except a single emote, so the draw has one answer.
    final skins = container.read(skinControllerProvider.notifier);
    for (final skin in GameSkin.values) {
      await skins.unlockSkin(skin);
    }
    final emotes = container.read(emoteControllerProvider.notifier);
    for (final emote in Emote.values.where((e) => e != Emote.star)) {
      await emotes.unlock(emote);
    }
    final celebrations = container.read(celebrationControllerProvider.notifier);
    for (final celebration in Celebration.values) {
      await celebrations.unlock(celebration);
    }

    final reward = await container.read(chestControllerProvider).claimDaily();
    expect(reward, isA<EmoteReward>());
    expect((reward! as EmoteReward).emote, Emote.star);
  });

  test(
    'claiming with everything unlocked returns null rather than throwing',
    () async {
      final container = ProviderContainer(
        overrides: [
          chestControllerProvider.overrideWith(
            (ref) => ChestController(ref, random: Random(1)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await finishToday(container.read(dailyChallengeServiceProvider));

      for (final skin in GameSkin.values) {
        await container.read(skinControllerProvider.notifier).unlockSkin(skin);
      }
      for (final emote in Emote.values) {
        await container.read(emoteControllerProvider.notifier).unlock(emote);
      }
      for (final celebration in Celebration.values) {
        await container
            .read(celebrationControllerProvider.notifier)
            .unlock(celebration);
      }

      expect(
        await container.read(chestControllerProvider).claimDaily(),
        isNull,
      );
    },
  );
}
