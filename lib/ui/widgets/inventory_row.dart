import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../theme/tokens.dart';
import 'chip_view.dart';

/// The current player's remaining chips, one button per level with a count.
/// Tapping selects that level; legal placements then highlight on the board.
class InventoryRow extends ConsumerWidget {
  const InventoryRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) return const SizedBox.shrink();
    final controller = ref.read(gameControllerProvider.notifier);
    final colors = context.gameColors;
    final remaining =
        controller.stackingEngine.remainingInventory(session.currentPlayer);
    final person = session.currentPerson;
    final color = person == 1 ? colors.playerA : colors.playerB;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var level = 1; level <= 4; level++)
          _InventoryChip(
            key: Key('inventory-$level'),
            level: level,
            count: remaining[level] ?? 0,
            color: color,
            surface: colors.surface,
            ink: colors.ink,
            neutral: colors.neutral,
            isFirstPerson: person == 1,
            selected: session.selectedLevel == level,
            onTap: () => controller.selectInventoryLevel(level),
          ),
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final depleted = count <= 0;
    return GestureDetector(
      onTap: depleted ? null : onTap,
      child: Container(
        width: 64,
        height: 76,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(4),
          border: selected ? Border.all(color: ink, width: 2) : null,
        ),
        child: Opacity(
          opacity: depleted ? 0.25 : 1,
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
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '×$count',
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
