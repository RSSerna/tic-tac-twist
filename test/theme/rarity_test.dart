import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/theme/rarity.dart';

void main() {
  test('weights sum to totalWeight', () {
    final sum = Rarity.values.fold<int>(0, (a, tier) => a + tier.weight);
    expect(sum, Rarity.totalWeight);
  });

  test('roll observed frequencies land near their published weight', () {
    const trials = 20000;
    final counts = {for (final tier in Rarity.values) tier: 0};
    final random = Random();
    for (var i = 0; i < trials; i++) {
      final tier = Rarity.roll(random);
      counts[tier] = counts[tier]! + 1;
    }
    for (final tier in Rarity.values) {
      final expected = trials * tier.weight / Rarity.totalWeight;
      // Generous tolerance — this is a sanity check on the weighting, not a
      // precise statistical test; ±25% keeps it stable across CI runs even
      // for the smallest bucket (legendary, ~3% of trials).
      expect(
        counts[tier],
        closeTo(expected, expected * 0.25 + 20),
        reason: '${tier.name}: expected ~$expected, got ${counts[tier]}',
      );
    }
  });

  test('roll is deterministic for a fixed seed', () {
    final a = Rarity.roll(Random(7));
    final b = Rarity.roll(Random(7));
    expect(a, b);
  });
}
