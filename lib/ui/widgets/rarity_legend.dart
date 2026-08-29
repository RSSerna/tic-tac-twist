import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// A static key to the rarity tiers.
///
/// Nothing carries a rarity yet — the tier list and drop odds are still
/// undecided (CLAUDE.md), and chests are deferred. This legend names the
/// tiers; it does not filter, because there is nothing to filter on.
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
            for (final tier in [
              l10n.rarityCommon,
              l10n.rarityRare,
              l10n.rarityEpic,
              l10n.rarityLegendary,
            ])
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: elevations.resting,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                child: Text(
                  tier.toUpperCase(),
                  style: styles.caption.copyWith(
                    color: colors.ink,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
