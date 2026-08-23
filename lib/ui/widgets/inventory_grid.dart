import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/skin_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'chip_view.dart';

/// The current player's remaining chips as a 2×2 block, one button per level
/// with a count. Tapping selects that level; legal placements then highlight
/// on the board.
class InventoryGrid extends ConsumerWidget {
  const InventoryGrid({super.key, this.compact = false});

  /// Shrinks the tiles for screens too short to seat the full-size block —
  /// an SE-class phone in portrait, where 220pt of chips would push the
  /// staging bar off the bottom.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) return const SizedBox.shrink();
    final controller = ref.read(gameControllerProvider.notifier);
    final colors = context.gameColors;
    final remaining = controller.stackingEngine.remainingInventory(
      session.currentPlayer,
    );
    final person = session.currentPerson;
    final color = person == 1 ? colors.playerA : colors.playerB;
    final appearance =
        ref.watch(skinControllerProvider).value?.selectedSkin.appearance ??
        const PaintedAppearance(ChipForm.rings);

    Widget chip(int level) => _InventoryChip(
      key: Key('inventory-$level'),
      level: level,
      count: remaining[level] ?? 0,
      color: color,
      surface: colors.surface,
      ink: colors.ink,
      neutral: colors.neutral,
      isFirstPerson: person == 1,
      selected: session.selectedLevel == level,
      appearance: appearance,
      compact: compact,
      onTap: () => controller.selectInventoryLevel(level),
    );

    // A fixed 2×2 block rather than a reflowing row. Four chips in a line
    // need ~400px, which a narrow landscape side panel doesn't have; two
    // columns need ~208 and, unlike a Wrap, the arrangement doesn't change
    // with the width — the chips stay where the player learned they were.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [chip(1), chip(2)]),
        Row(mainAxisSize: MainAxisSize.min, children: [chip(3), chip(4)]),
      ],
    );
  }
}

class _InventoryChip extends StatelessWidget {
  const _InventoryChip({
    super.key,
    required this.level,
    required this.count,
    required this.color,
    required this.surface,
    required this.ink,
    required this.neutral,
    required this.isFirstPerson,
    required this.selected,
    required this.appearance,
    required this.compact,
    required this.onTap,
  });

  final int level;
  final int count;
  final Color color;
  final Color surface;
  final Color ink;
  final Color neutral;
  final bool isFirstPerson;
  final bool selected;
  final ChipAppearance appearance;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final depleted = count <= 0;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.inventoryChipLabel(level, count),
      child: GestureDetector(
        onTap: depleted ? null : onTap,
        child: Container(
          width: compact ? 64 : 92,
          height: compact ? 76 : 104,
          margin: EdgeInsets.all(compact ? 4 : 6),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: selected ? Border.all(color: ink, width: 2) : null,
            boxShadow: context.gameElevations.raised,
          ),
          child: Opacity(
            opacity: depleted ? 0.25 : 1,
            child: ExcludeSemantics(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: ChipView(
                        color: depleted ? neutral : color,
                        ringColor: surface,
                        level: level,
                        isFirstPerson: isFirstPerson,
                        appearance: appearance,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '×$count',
                      // `ink` rather than the style's own colour: this row is
                      // handed its palette by the caller, not the theme.
                      style: context.gameTextStyles.dataSmall.copyWith(
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
