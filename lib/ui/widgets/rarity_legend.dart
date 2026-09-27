import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/rarity.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'rarity_display.dart';

/// The published key to the chest's rarity tiers and drop odds
/// (`03-PRODUCT.md` §3.2: "publish drop odds anyway").
///
/// `Rarity` is real now — a chest independently rolls one on every open
/// (`ChestController._grantOne`) and, when the pool pick lands on a
/// fragment-gated cosmetic, the rolled tier decides how many fragments that
/// grant is worth (`GameSkin.fragmentsRequired`). This legend still doesn't
/// *filter* anything — every cosmetic in the pool is equally likely to be
/// picked regardless of rarity — but the odds/fragment amounts it shows are
/// the real, load-bearing numbers `Rarity.roll` uses, not placeholders.
class RarityLegend extends StatelessWidget {
  const RarityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      // A single scrolling row, not a Wrap: wrapping made the legend two
      // rows deep in Spanish, and the extra height came out of the carousel.
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            for (final tier in Rarity.values)
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: rarityColor(context, tier),
                    width: 2,
                  ),
                  boxShadow: elevations.resting,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rarityName(l10n, tier).toUpperCase(),
                      style: styles.caption.copyWith(
                        color: colors.ink,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      l10n.rarityOdds(tier.weight, tier.fragments),
                      style: styles.caption.copyWith(
                        color: rarityColor(context, tier),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
