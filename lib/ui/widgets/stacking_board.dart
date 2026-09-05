import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/skin_controller.dart';
import '../../engines/common/player.dart';
import '../../engines/stacking/stacking_engine.dart';
import '../../engines/stacking/stacking_move.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';
import 'chip_view.dart';

/// The 3×3 stacking board. Renders only public information: the topmost
/// chip of each square and how deep its stack is. What is buried — owner
/// or level — is never shown anywhere (CLAUDE.md, design doc §2.5).
class StackingBoard extends ConsumerWidget {
  const StackingBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) return const SizedBox.shrink();
    final controller = ref.read(gameControllerProvider.notifier);
    final engine = session.engine as StackingEngine;
    final colors = context.gameColors;
    // The pair, not one appearance: which skin draws a chip depends on whose
    // chip it is, and that's only known at the individual cell.
    final skins = ref.watch(skinControllerProvider).value?.pair ??
        SkinPair.fallback;

    final highlights = controller.stackingHighlightTargets();
    final staged = session.stagedMove;
    final (stagedCell, stagedLevel, stagedFrom) = switch (staged) {
      PlaceMove(:final cell, :final level) => (cell, level, null),
      RelocateMove(:final from, :final to) => (
        to,
        engine.topChipAt(from)?.level,
        from,
      ),
      _ => (null, null, null),
    };
    final currentPerson = session.currentPerson;
    final currentColor = currentPerson == 1 ? colors.playerA : colors.playerB;
    final lastMoveCell = switch (session.lastMove) {
      PlaceMove(:final cell) => cell,
      RelocateMove(:final to) => to,
      _ => null,
    };

    return AspectRatio(
      aspectRatio: 1,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          for (var cell = 0; cell < 9; cell++)
            _StackingCell(
              key: Key('cell-$cell'),
              engine: engine,
              cell: cell,
              highlighted: highlights.contains(cell),
              highlightColor: colors.highlightFor(currentColor),
              isSelectedOrigin: session.selectedCell == cell,
              stagedLevel: stagedCell == cell ? stagedLevel : null,
              stagedOrigin: stagedFrom == cell,
              isLastMove: lastMoveCell == cell,
              currentPersonIsFirst: currentPerson == 1,
              currentColor: currentColor,
              personFor: session.personFor,
              skins: skins,
              onTap: () => controller.onStackingCellTapped(cell),
            ),
        ],
      ),
    );
  }
}

class _StackingCell extends StatelessWidget {
  const _StackingCell({
    super.key,
    required this.engine,
    required this.cell,
    required this.highlighted,
    required this.highlightColor,
    required this.isSelectedOrigin,
    required this.stagedLevel,
    required this.stagedOrigin,
    required this.isLastMove,
    required this.currentPersonIsFirst,
    required this.currentColor,
    required this.personFor,
    required this.skins,
    required this.onTap,
  });

  final StackingEngine engine;
  final int cell;
  final bool highlighted;
  final Color highlightColor;
  final bool isSelectedOrigin;

  /// Level of the staged chip previewed on this cell, if any.
  final int? stagedLevel;

  /// Whether the staged relocation departs from this cell.
  final bool stagedOrigin;

  /// Whether this cell is where the most recently committed move (any
  /// source) landed — briefly highlighted, most useful for the AI's turn
  /// where no human tap already drew the eye there.
  final bool isLastMove;
  final bool currentPersonIsFirst;
  final Color currentColor;
  final int Function(Player) personFor;
  final SkinPair skins;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final top = engine.topChipAt(cell);
    final depth = engine.stackDepthAt(cell);
    final l10n = AppLocalizations.of(context);

    // Screen-reader label: public information only — the buried count
    // (never who or what level) matches exactly what's visible on screen
    // (design doc §2.5, §6).
    final occupancy = top == null
        ? l10n.stackingCellEmpty
        : l10n.stackingCellOccupied(personFor(top.owner), top.level);
    final buried = depth > 1 ? ' ${l10n.stackingCellBuried(depth - 1)}' : '';
    final label = '${l10n.stackingCellLabel(cell + 1)}, $occupancy$buried';

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(4),
            border: isSelectedOrigin
                ? Border.all(color: colors.ink, width: 2)
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (highlighted)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: highlightColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              if (top != null)
                Center(
                  child: _AnimatedChip(
                    // Depth > 1 means something was already there — a cover,
                    // the signature moment of the stacking modes (design doc
                    // §4), gets a weightier animation than a plain placement.
                    // Depth itself makes the key unique per top-chip change:
                    // it only ever moves in the direction that produced a
                    // genuinely new top chip (placement, cover, or a
                    // relocation revealing what's underneath).
                    animationKey: ValueKey(
                      '$cell-$depth-${top.owner.name}-${top.level}',
                    ),
                    isCover: depth > 1,
                    child: Opacity(
                      // The origin chip of a staged relocation dims: it is
                      // leaving, but nothing beneath is revealed until commit.
                      opacity: stagedOrigin ? 0.35 : 1,
                      child: ChipView(
                        color: personFor(top.owner) == 1
                            ? colors.playerA
                            : colors.playerB,
                        ringColor: colors.surface,
                        level: top.level,
                        isFirstPerson: personFor(top.owner) == 1,
                        appearance: skins.appearanceFor(
                          isFirstPerson: personFor(top.owner) == 1,
                        ),
                      ),
                    ),
                  ),
                ),
              if (stagedLevel != null)
                Center(
                  child: ChipView(
                    color: currentColor,
                    ringColor: colors.surface,
                    level: stagedLevel!,
                    isFirstPerson: currentPersonIsFirst,
                    appearance: skins.appearanceFor(
                      isFirstPerson: currentPersonIsFirst,
                    ),
                    ghost: true,
                  ),
                ),
              // Buried collar: shows THAT chips are buried and how many —
              // never whose or what level (design doc §2.5).
              if (depth > 1)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < depth - 1; i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: colors.neutral,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              // Keyed on the top chip's identity so a fresh highlight (and
              // its fade-out) restarts each time a *new* move lands here.
              // Most useful for the AI's turn: unlike a human's own tap,
              // nothing has already drawn the player's eye to this cell.
              if (isLastMove && top != null)
                _LastMoveGlow(
                  key: ValueKey('glow-$cell-$depth-${top.owner.name}'),
                  color: personFor(top.owner) == 1
                      ? colors.playerA
                      : colors.playerB,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip's entrance: a plain placement pops in quickly; a cover — something
/// was already there — settles in weightier, with a little overshoot (design
/// doc §4: "covering has weight... instantly distinguishable from a normal
/// placement"). Respects OS reduced-motion by collapsing to an instant swap.
class _AnimatedChip extends StatelessWidget {
  const _AnimatedChip({
    required this.animationKey,
    required this.isCover,
    required this.child,
  });

  final Key animationKey;
  final bool isCover;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animations = context.gameAnimations;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : (isCover ? animations.cover : animations.placement);

    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: isCover ? Curves.easeOutBack : Curves.easeOut,
        ),
        child: child,
      ),
      child: KeyedSubtree(key: animationKey, child: child),
    );
  }
}

/// A brief highlighted ring on the cell the most recent move landed on,
/// fading out on its own. Most valuable for the AI's turn: unlike a human's
/// own tap, nothing has already drawn the player's eye to where it played.
/// Restarts whenever [key] changes identity (a fresh move on this cell),
/// same trick as [_AnimatedChip].
class _LastMoveGlow extends StatelessWidget {
  const _LastMoveGlow({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (context, opacity, child) => Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
