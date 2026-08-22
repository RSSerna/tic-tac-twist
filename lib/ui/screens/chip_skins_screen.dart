import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/skin_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../services/purchase_service.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../widgets/chip_view.dart';
import '../widgets/panel_header.dart';

String _skinName(AppLocalizations l10n, GameSkin skin) => switch (skin.id) {
  'turned_wood' => l10n.skinTurnedWoodName,
  'nesting_dolls' => l10n.skinNestingDollsName,
  _ => skin.id,
};

String _skinDesc(AppLocalizations l10n, GameSkin skin) => switch (skin.id) {
  'turned_wood' => l10n.skinTurnedWoodDesc,
  'nesting_dolls' => l10n.skinNestingDollsDesc,
  _ => '',
};

/// The direct-purchase route design doc §2.2 names alongside "earned
/// through play" — null for skins (like the free default) that have no
/// purchase route at all, and always null on web (design doc §9:
/// in_app_purchase has no web implementation, so there's nothing to sell —
/// achievement-unlocking still works there, since it's just local storage).
ProductId? _productFor(GameSkin skin) {
  if (kIsWeb) return null;
  return switch (skin.id) {
    'nesting_dolls' => ProductId.skinNestingDolls,
    _ => null,
  };
}

/// Chip skin picker (roadmap Phase 8): the free default plus one premium set,
/// unlockable either by achievement (design doc §2.6 / product doc §3.1) or
/// direct purchase (product doc §2.2's other cosmetics route).
///
/// Reached from the Custom screen's "Skins" category — chips are one of
/// several things a player will be able to reskin.
class ChipSkinsScreen extends ConsumerWidget {
  const ChipSkinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final skinState = ref.watch(skinControllerProvider).value;
    final skinController = ref.read(skinControllerProvider.notifier);

    return Scaffold(
      backgroundColor: colors.ground,
      body: SafeArea(
        child: Column(
          children: [
            PanelHeader(
              closeKey: const Key('close-chip-skins'),
              icon: Icon(Icons.palette, size: 34, color: colors.neutral),
              title: l10n.categoryChips,
              subtitle: l10n.skinsTitle,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
                children: [
                  for (final skin in GameSkin.values) ...[
                    _SkinCard(
                      skin: skin,
                      unlocked:
                          skinState?.isUnlocked(skin) ??
                          skin.id == GameSkin.turnedWood.id,
                      selected: skinState?.selectedId == skin.id,
                      onSelect: () => skinController.selectSkin(skin),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinCard extends ConsumerWidget {
  const _SkinCard({
    required this.skin,
    required this.unlocked,
    required this.selected,
    required this.onSelect,
  });

  final GameSkin skin;
  final bool unlocked;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final styles = context.gameTextStyles;
    final elevations = context.gameElevations;
    final product = _productFor(skin);

    return Container(
      key: Key('skin-card-${skin.id}'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: elevations.resting,
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Opacity(
            opacity: unlocked ? 1 : 0.4,
            child: SizedBox(
              width: 56,
              height: 56,
              child: ChipView(
                color: colors.playerA,
                ringColor: colors.surface,
                level: 4,
                isFirstPerson: true,
                appearance: skin.appearance,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_skinName(l10n, skin), style: styles.cardTitle),
                const SizedBox(height: 4),
                Text(
                  unlocked ? _skinDesc(l10n, skin) : l10n.skinUnlockHint,
                  style: styles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (!unlocked) ...[
            Icon(
              Icons.lock,
              color: colors.neutral,
              semanticLabel: l10n.skinLocked,
            ),
            if (product != null) ...[
              const SizedBox(width: 8),
              FilledButton(
                key: Key('buy-skin-${skin.id}'),
                onPressed: () => ref.read(purchaseServiceProvider).buy(product),
                child: Text(l10n.skinBuyButton),
              ),
            ],
          ] else if (selected)
            Text(l10n.skinSelected, style: styles.label)
          else
            FilledButton(
              key: Key('select-skin-${skin.id}'),
              onPressed: onSelect,
              child: Text(l10n.skinSelect),
            ),
        ],
      ),
    );
  }
}
