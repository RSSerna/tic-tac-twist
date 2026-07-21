import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/skin_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import '../widgets/chip_view.dart';

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

/// Skin picker (roadmap Phase 8): the free default plus one
/// achievement-unlocked premium set (design doc §2.6 / product doc §2.2).
/// Real purchases and the full chest system are Phase 9 — this phase only
/// wires the swap mechanism and an achievement-based unlock.
class SkinsScreen extends ConsumerWidget {
  const SkinsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final skinState = ref.watch(skinControllerProvider).value;
    final skinController = ref.read(skinControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.skinsTitle),
        backgroundColor: colors.ground,
        foregroundColor: colors.ink,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            for (final skin in GameSkin.values) ...[
              _SkinCard(
                skin: skin,
                unlocked: skinState?.isUnlocked(skin) ??
                    skin.id == GameSkin.turnedWood.id,
                selected: skinState?.selectedId == skin.id,
                onSelect: () => skinController.selectSkin(skin),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.gameColors;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      key: Key('skin-card-${skin.id}'),
      color: colors.surface,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
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
                  form: skin.chipForm,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_skinName(l10n, skin),
                      style: textTheme.titleMedium?.copyWith(color: colors.ink)),
                  const SizedBox(height: 4),
                  Text(
                    unlocked ? _skinDesc(l10n, skin) : l10n.skinUnlockHint,
                    style: textTheme.bodySmall?.copyWith(color: colors.neutral),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (!unlocked)
              Icon(Icons.lock, color: colors.neutral, semanticLabel: l10n.skinLocked)
            else if (selected)
              Text(l10n.skinSelected,
                  style: textTheme.labelLarge?.copyWith(color: colors.ink))
            else
              FilledButton(
                key: Key('select-skin-${skin.id}'),
                onPressed: onSelect,
                child: Text(l10n.skinSelect),
              ),
          ],
        ),
      ),
    );
  }
}
