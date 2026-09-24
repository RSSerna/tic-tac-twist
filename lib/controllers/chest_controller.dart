import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../theme/celebration.dart';
import '../theme/emote.dart';
import '../theme/skin.dart';
import 'celebration_controller.dart';
import 'daily_challenge_controller.dart';
import 'emote_controller.dart';
import 'skin_controller.dart';

/// What a chest handed over, so the UI can name it.
@immutable
sealed class ChestReward {
  const ChestReward();
}

class SkinReward extends ChestReward {
  const SkinReward(this.skin);
  final GameSkin skin;
}

class EmoteReward extends ChestReward {
  const EmoteReward(this.emote);
  final Emote emote;
}

class CelebrationReward extends ChestReward {
  const CelebrationReward(this.celebration);
  final Celebration celebration;
}

/// Opens the chest earned by finishing a day's challenges.
///
/// **Deliberately uniform.** Rarity tiers and drop tables are still
/// undecided (`CLAUDE.md`), so this picks evenly from everything the player
/// doesn't own rather than inventing weights that would then have to be
/// unpicked. The rarity legend in the pickers is a legend precisely because
/// this doesn't consult one yet.
///
/// Chests are **never purchasable** (product doc §3.3 / `08-STORE-ITEMS.md`
/// §1) — the only way to open one is to play. Keep it that way: a paid
/// random box is the loot-box exposure the docs exist to avoid.
class ChestController {
  ChestController(this.ref, {Random? random}) : _random = random ?? Random();

  final Ref ref;
  final Random _random;

  /// Claims the day's reward and grants one locked cosmetic.
  ///
  /// Returns null when there was nothing to claim (already taken, or the
  /// day's set isn't finished) or when everything is already unlocked — the
  /// caller distinguishes those two by asking the daily controller.
  Future<ChestReward?> claimDaily() async {
    final claimed = await ref
        .read(dailyChallengeControllerProvider.notifier)
        .claim();
    if (!claimed) return null;
    return _grantOne();
  }

  Future<ChestReward?> _grantOne() async {
    final skins = await ref.read(skinControllerProvider.future);
    final emotes = await ref.read(emoteControllerProvider.future);
    final celebrations = await ref.read(celebrationControllerProvider.future);

    final pool = <ChestReward>[
      // purchaseOnly skins (e.g. Burger Stack) are excluded: a free chest
      // handing out a paid-only skin would contradict the one thing
      // "purchase-only" is supposed to mean.
      for (final skin in GameSkin.values)
        if (!skins.isUnlocked(skin) && !skin.purchaseOnly) SkinReward(skin),
      for (final emote in Emote.values)
        if (!emotes.isUnlocked(emote)) EmoteReward(emote),
      for (final celebration in Celebration.values)
        if (!celebrations.isUnlocked(celebration))
          CelebrationReward(celebration),
    ];
    if (pool.isEmpty) return null;

    final reward = pool[_random.nextInt(pool.length)];
    switch (reward) {
      case SkinReward(:final skin):
        await ref.read(skinControllerProvider.notifier).unlockSkin(skin);
      case EmoteReward(:final emote):
        await ref.read(emoteControllerProvider.notifier).unlock(emote);
      case CelebrationReward(:final celebration):
        await ref
            .read(celebrationControllerProvider.notifier)
            .unlock(celebration);
    }
    return reward;
  }
}

final chestControllerProvider = Provider<ChestController>(
  ChestController.new,
);
