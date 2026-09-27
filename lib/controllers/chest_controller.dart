import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import '../theme/celebration.dart';
import '../theme/emote.dart';
import '../theme/rarity.dart';
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

/// Fragments granted toward a fragment-gated skin ([GameSkin.isFragmentGated])
/// instead of an instant unlock. [rarity] is what the chest rolled — it's
/// what decided [amount] — so the reveal UI can show it; [totalAfter] and
/// [unlockedNow] come straight from `SkinController.addFragments`.
class SkinFragmentReward extends ChestReward {
  const SkinFragmentReward({
    required this.skin,
    required this.rarity,
    required this.totalAfter,
    required this.unlockedNow,
  });
  final GameSkin skin;
  final Rarity rarity;
  int get amount => rarity.fragments;
  final int totalAfter;
  final bool unlockedNow;
}

/// Same shape as [SkinFragmentReward], for a fragment-gated emote.
class EmoteFragmentReward extends ChestReward {
  const EmoteFragmentReward({
    required this.emote,
    required this.rarity,
    required this.totalAfter,
    required this.unlockedNow,
  });
  final Emote emote;
  final Rarity rarity;
  int get amount => rarity.fragments;
  final int totalAfter;
  final bool unlockedNow;
}

/// Same shape as [SkinFragmentReward], for a fragment-gated celebration.
class CelebrationFragmentReward extends ChestReward {
  const CelebrationFragmentReward({
    required this.celebration,
    required this.rarity,
    required this.totalAfter,
    required this.unlockedNow,
  });
  final Celebration celebration;
  final Rarity rarity;
  int get amount => rarity.fragments;
  final int totalAfter;
  final bool unlockedNow;
}

/// Which catalog a uniformly-random pool pick came from. Kept separate from
/// the public [ChestReward] (which also has fragment variants) so
/// [ChestController._grantOne]'s dispatch switch stays exhaustive over
/// exactly the 3 shapes the pool can produce, rather than demanding branches
/// for fragment-reward outcomes that structurally can't come from a pool pick.
sealed class _PoolPick {
  const _PoolPick();
}

class _SkinPick extends _PoolPick {
  const _SkinPick(this.skin);
  final GameSkin skin;
}

class _EmotePick extends _PoolPick {
  const _EmotePick(this.emote);
  final Emote emote;
}

class _CelebrationPick extends _PoolPick {
  const _CelebrationPick(this.celebration);
  final Celebration celebration;
}

/// Opens the chest earned by finishing a day's challenges.
///
/// **The pool pick stays uniform.** One cosmetic is still chosen evenly from
/// everything the player doesn't own — no weighting by rarity. What's new is
/// an *independent* rarity roll on every open ([Rarity.roll]), consulted only
/// when the picked cosmetic turns out to be fragment-gated: it decides how
/// many fragments that grant is worth, rather than the picked cosmetic
/// unlocking outright. A non-fragment-gated pick is unaffected — instant
/// unlock, exactly as before — so the roll's outcome simply isn't surfaced
/// for that case. See `docs/09-DECISIONS-LOG.md` for the published odds.
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

    // purchaseOnly skins (e.g. Burger Stack) are excluded: a free chest
    // handing out a paid-only skin would contradict the one thing
    // "purchase-only" is supposed to mean. Fragment-gated cosmetics are NOT
    // excluded — they must stay pickable so fragments can accrue toward
    // them; see the class doc comment above for how that pick then resolves.
    final pool = <_PoolPick>[
      for (final skin in GameSkin.values)
        if (!skins.isUnlocked(skin) && !skin.purchaseOnly) _SkinPick(skin),
      for (final emote in Emote.values)
        if (!emotes.isUnlocked(emote)) _EmotePick(emote),
      for (final celebration in Celebration.values)
        if (!celebrations.isUnlocked(celebration))
          _CelebrationPick(celebration),
    ];
    if (pool.isEmpty) return null;

    final picked = pool[_random.nextInt(pool.length)];
    // Rolled on every open, independently of the pool pick above. Only
    // consulted below if the picked cosmetic is fragment-gated — an instant
    // whole-cosmetic unlock has no rarity of its own in this design.
    final rarity = Rarity.roll(_random);

    switch (picked) {
      case _SkinPick(:final skin):
        if (!skin.isFragmentGated) {
          await ref.read(skinControllerProvider.notifier).unlockSkin(skin);
          return SkinReward(skin);
        }
        // Safe to force-unwrap: `isFragmentGated` and "not yet unlocked"
        // (the pool filter above) are exactly addFragments's own
        // non-null conditions.
        final grant = (await ref
            .read(skinControllerProvider.notifier)
            .addFragments(skin, rarity.fragments))!;
        return SkinFragmentReward(
          skin: skin,
          rarity: rarity,
          totalAfter: grant.totalAfter,
          unlockedNow: grant.unlockedNow,
        );
      case _EmotePick(:final emote):
        if (!emote.isFragmentGated) {
          await ref.read(emoteControllerProvider.notifier).unlock(emote);
          return EmoteReward(emote);
        }
        final grant = (await ref
            .read(emoteControllerProvider.notifier)
            .addFragments(emote, rarity.fragments))!;
        return EmoteFragmentReward(
          emote: emote,
          rarity: rarity,
          totalAfter: grant.totalAfter,
          unlockedNow: grant.unlockedNow,
        );
      case _CelebrationPick(:final celebration):
        if (!celebration.isFragmentGated) {
          await ref
              .read(celebrationControllerProvider.notifier)
              .unlock(celebration);
          return CelebrationReward(celebration);
        }
        final grant = (await ref
            .read(celebrationControllerProvider.notifier)
            .addFragments(celebration, rarity.fragments))!;
        return CelebrationFragmentReward(
          celebration: celebration,
          rarity: rarity,
          totalAfter: grant.totalAfter,
          unlockedNow: grant.unlockedNow,
        );
    }
  }
}

final chestControllerProvider = Provider<ChestController>(
  ChestController.new,
);
