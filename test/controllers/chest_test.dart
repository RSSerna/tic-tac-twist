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
import 'package:nested_game/theme/rarity.dart';
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

  test('a finished day grants one fragment reward, once', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await finishToday(container.read(dailyChallengeServiceProvider));

    final reward = await container.read(chestControllerProvider).claimDaily();
    expect(reward, isNotNull);
    // A fresh install has no progress, so the running total is exactly what
    // the rolled tier was worth.
    expect(reward!.totalAfter, reward.amount);

    // The day is spent — a second claim grants nothing more.
    expect(await container.read(chestControllerProvider).claimDaily(), isNull);
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
    expect(reward, isA<EmoteFragmentReward>());
    expect((reward! as EmoteFragmentReward).emote, Emote.star);
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

  group('fragments', () {
    /// Unlocks everything except [GameSkin.fragmentShard], so a claim's
    /// uniform pool pick has exactly one possible answer.
    Future<void> unlockEverythingExceptFragmentShard(
      ProviderContainer container,
    ) async {
      for (final skin in GameSkin.values.where(
        (s) => s != GameSkin.fragmentShard,
      )) {
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
    }

    test(
      'a claim on a fragment-gated pick grants fragments, not an unlock',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await finishToday(container.read(dailyChallengeServiceProvider));
        await unlockEverythingExceptFragmentShard(container);

        final reward = await container
            .read(chestControllerProvider)
            .claimDaily();

        expect(reward, isA<SkinFragmentReward>());
        final fragmentReward = reward! as SkinFragmentReward;
        expect(fragmentReward.skin, GameSkin.fragmentShard);
        expect(
          fragmentReward.totalAfter,
          isIn(Rarity.values.map((r) => r.fragments)),
        );
        expect(fragmentReward.unlockedNow, isFalse);

        final skins = await container.read(skinControllerProvider.future);
        expect(skins.isUnlocked(GameSkin.fragmentShard), isFalse);
      },
    );

    test(
      'addFragments auto-unlocks exactly on the grant that crosses the '
      'threshold',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(skinControllerProvider.notifier);

        // 4 grants of 25 = 100, the exact threshold.
        for (var i = 0; i < 3; i++) {
          final grant = await notifier.addFragments(
            GameSkin.fragmentShard,
            25,
          );
          expect(grant!.unlockedNow, isFalse);
          expect(grant.totalAfter, 25 * (i + 1));
          expect(
            (await container.read(skinControllerProvider.future)).isUnlocked(
              GameSkin.fragmentShard,
            ),
            isFalse,
          );
        }

        final crossing = await notifier.addFragments(
          GameSkin.fragmentShard,
          25,
        );
        expect(crossing!.unlockedNow, isTrue);
        expect(crossing.totalAfter, 100);
        expect(
          (await container.read(skinControllerProvider.future)).isUnlocked(
            GameSkin.fragmentShard,
          ),
          isTrue,
        );
      },
    );

    test('addFragments on an already-unlocked skin no-ops', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(skinControllerProvider.notifier);
      await notifier.unlockSkin(GameSkin.fragmentShard);

      expect(
        await notifier.addFragments(GameSkin.fragmentShard, 25),
        isNull,
      );
      final skins = await container.read(skinControllerProvider.future);
      expect(skins.fragmentCounts[GameSkin.fragmentShard.id], isNull);
    });

    test('addFragments on a non-fragment-gated skin no-ops', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(skinControllerProvider.notifier);

      expect(
        await notifier.addFragments(GameSkin.nestingDolls, 25),
        isNull,
      );
    });
  });
}
