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

/// What a chest handed over, so the UI can name it. A chest only ever grants
/// **fragments** toward a fragment-gated cosmetic — never an instant unlock —
/// so every variant carries the rolled [rarity] that decided the amount,
/// the running total, and whether this grant just crossed the threshold.
@immutable
sealed class ChestReward {
  const ChestReward({
    required this.rarity,
    required this.totalAfter,
    required this.unlockedNow,
  });

  final Rarity rarity;
  int get amount => rarity.fragments;
  final int totalAfter;
  final bool unlockedNow;
}

class SkinFragmentReward extends ChestReward {
  const SkinFragmentReward({
    required this.skin,
    required super.rarity,
    required super.totalAfter,
    required super.unlockedNow,
  });
  final GameSkin skin;
}

class EmoteFragmentReward extends ChestReward {
  const EmoteFragmentReward({
    required this.emote,
    required super.rarity,
    required super.totalAfter,
    required super.unlockedNow,
  });
  final Emote emote;
}

class CelebrationFragmentReward extends ChestReward {
  const CelebrationFragmentReward({
    required this.celebration,
    required super.rarity,
    required super.totalAfter,
    required super.unlockedNow,
  });
  final Celebration celebration;
}

/// Which catalog a uniformly-random pool pick came from.
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
/// **A chest only grants fragments.** It picks one cosmetic uniformly from
/// every *fragment-gated* cosmetic the player doesn't own yet (across skins,
/// emotes and celebrations), independently rolls a [Rarity], and adds that
/// tier's fragment count toward the pick — unlocking it once the running
/// total reaches its `fragmentsRequired`. Cosmetics with any other route
/// (free, achievement-only like Nesting Dolls, purchase-only like Burger
/// Stack) are never in the pool. See `docs/09-DECISIONS-LOG.md`.
///
/// Chests are **never purchasable** (product doc §3.3 / `08-STORE-ITEMS.md`
/// §1) — the only way to open one is to play. Keep it that way: a paid
/// random box is the loot-box exposure the docs exist to avoid.
class ChestController {
  ChestController(this.ref, {Random? random}) : _random = random ?? Random();

  final Ref ref;
  final Random _random;

  /// Claims the day's reward and grants fragments toward one cosmetic.
  ///
  /// Returns null when there was nothing to claim (already taken, or the
  /// day's set isn't finished) or when every fragment-gated cosmetic is
  /// already unlocked — the caller distinguishes those two by asking the
  /// daily controller.
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

    final pool = <_PoolPick>[
      for (final skin in GameSkin.values)
        if (skin.isFragmentGated && !skins.isUnlocked(skin)) _SkinPick(skin),
      for (final emote in Emote.values)
        if (emote.isFragmentGated && !emotes.isUnlocked(emote))
          _EmotePick(emote),
      for (final celebration in Celebration.values)
        if (celebration.isFragmentGated &&
            !celebrations.isUnlocked(celebration))
          _CelebrationPick(celebration),
    ];
    if (pool.isEmpty) return null;

    final picked = pool[_random.nextInt(pool.length)];
    final rarity = Rarity.roll(_random);

    // Safe to force-unwrap each addFragments: the pool filter above is
    // exactly its own non-null conditions (fragment-gated, not unlocked).
    switch (picked) {
      case _SkinPick(:final skin):
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
