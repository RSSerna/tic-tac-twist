import 'dart:math';

/// A chest's independent rarity roll (product doc §3.2: "publish drop odds
/// anyway"). Order is deliberately least → most rare: the chest-reveal
/// animation's cycle (`ChestRevealController`) relies on [Rarity.values]
/// being in this order.
///
/// Rolled on every chest open (`ChestController._grantOne`), independently
/// of which cosmetic the uniform pool pick lands on. Only consulted when
/// that pick turns out to be fragment-gated (`GameSkin.isFragmentGated` and
/// its `Emote`/`Celebration` equivalents) — an instant whole-cosmetic unlock
/// has no rarity of its own.
enum Rarity {
  common(weight: 60, fragments: 1),
  rare(weight: 25, fragments: 5),
  epic(weight: 12, fragments: 10),
  legendary(weight: 3, fragments: 25);

  const Rarity({required this.weight, required this.fragments});

  /// Out of [totalWeight] — the published drop odds (03-PRODUCT.md §3.2).
  final int weight;

  /// Fragments awarded when this tier lands on a fragment-gated cosmetic.
  final int fragments;

  /// Sum of every tier's [weight]. Pinned by `test/theme/rarity_test.dart`
  /// so [roll]'s weighted scan can't silently drift out of sync with the
  /// published odds.
  static const totalWeight = 100;

  /// A weighted-random draw. Takes the caller's own [Random] (rather than
  /// creating one) so `ChestController` can pass its single, seedable
  /// `_random` and stay deterministic under test — the same reason
  /// `ChestController(ref, random: Random(1))` exists.
  static Rarity roll(Random random) {
    final n = random.nextInt(totalWeight);
    var acc = 0;
    for (final tier in Rarity.values) {
      acc += tier.weight;
      if (n < acc) return tier;
    }
    // Unreachable if every tier's weight is accounted for above — totalWeight
    // is the sum of all of them, guarded by the rarity_test.dart pin.
    return Rarity.legendary;
  }
}
