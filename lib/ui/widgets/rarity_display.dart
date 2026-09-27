import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../theme/rarity.dart';
import '../../theme/tokens.dart';

/// The localized display name for a rarity tier. Shared by [RarityLegend]
/// and the chest-reveal sheet so both name a tier the same way.
String rarityName(AppLocalizations l10n, Rarity tier) => switch (tier) {
  Rarity.common => l10n.rarityCommon,
  Rarity.rare => l10n.rarityRare,
  Rarity.epic => l10n.rarityEpic,
  Rarity.legendary => l10n.rarityLegendary,
};

/// The accent colour for a rarity tier (design doc §2.1b), for a pill
/// border/fill — never for text (see `GameColors.rarityCommon`'s doc
/// comment on the contrast bar that applies).
Color rarityColor(BuildContext context, Rarity tier) => switch (tier) {
  Rarity.common => context.gameColors.rarityCommon,
  Rarity.rare => context.gameColors.rarityRare,
  Rarity.epic => context.gameColors.rarityEpic,
  Rarity.legendary => context.gameColors.rarityLegendary,
};
