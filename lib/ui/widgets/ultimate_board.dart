import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../controllers/skin_controller.dart';
import '../../engines/common/player.dart';
import '../../engines/ultimate/ultimate_engine.dart';
import '../../engines/ultimate/ultimate_move.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../theme/skin.dart';
import '../../theme/tokens.dart';

/// The Ultimate board: 3×3 grid of 3×3 small boards, with tap-to-zoom
/// (design doc §3.4).
///
/// Unzoomed, a small board's cells are far under the 44pt tap-target
/// minimum, so tapping anywhere in a small board zooms it to fill the
/// screen rather than staging a move — staging only happens once zoomed
/// in. Zoom is presentation state private to this widget: it never touches
/// [GameSession]/serialisation, and never changes on its own when the
/// opponent moves (design doc: "do not auto-zoom on the opponent's move").
class UltimateBoard extends ConsumerStatefulWidget {
  const UltimateBoard({super.key});

  @override
  ConsumerState<UltimateBoard> createState() => _UltimateBoardState();
}

class _UltimateBoardState extends ConsumerState<UltimateBoard> {
  int? _zoomedBoard;

  void _zoomTo(int board) => setState(() => _zoomedBoard = board);
  void _zoomOut() => setState(() => _zoomedBoard = null);

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) return const SizedBox.shrink();

    // A committed move (human, AI, or a tutorial's scripted opponent) always
    // zooms back out to the full board — never stay zoomed into a small
    // board once play has moved on. This is what lets the design doc's
    // "highlight the board they've been sent to and let them choose"
    // actually work: the next player sees the full board with the send-rule
    // highlight, not a stale zoomed-in view of wherever the previous player
    // last tapped. Engine identity (not stagedMove) is the signal, since a
    // staged-then-cancelled move must NOT zoom out — only an actual move
    // changes the engine.
    ref.listen(gameControllerProvider, (previous, next) {
      if (_zoomedBoard == null) return;
      final previousEngine = previous?.engine;
      final nextEngine = next?.engine;
      if (previousEngine != null &&
          nextEngine != null &&
          !identical(previousEngine, nextEngine)) {
        setState(() => _zoomedBoard = null);
      }
    });

    final controller = ref.read(gameControllerProvider.notifier);
    final engine = session.engine as UltimateEngine;
    final colors = context.gameColors;
    final l10n = AppLocalizations.of(context);

    final playable = controller.ultimatePlayableBoards();
    final currentPerson = session.currentPerson;
    final currentColor = currentPerson == 1 ? colors.playerA : colors.playerB;
    final staged = session.stagedMove as UltimateMove?;
    final lastMove = session.lastMove as UltimateMove?;
    final appearance =
        ref.watch(skinControllerProvider).value?.selectedSkin.appearance ??
            const PaintedAppearance(ChipForm.rings);

    Widget smallBoard(int board, {required bool interactive}) => _SmallBoard(
      engine: engine,
      board: board,
      playable: playable.contains(board),
      highlightColor: colors.highlightFor(currentColor),
      staged: staged?.board == board ? staged : null,
      lastMoveCell: lastMove?.board == board ? lastMove!.cell : null,
      currentPerson: currentPerson,
      currentColor: currentColor,
      appearance: appearance,
      personFor: session.personFor,
      onCellTap: interactive
          ? (cell) => controller.onUltimateCellTapped(board, cell)
          : null,
      onZoomTap: interactive ? null : () => _zoomTo(board),
    );

    final Widget content;
    if (_zoomedBoard == null) {
      content = AspectRatio(
        aspectRatio: 1,
        child: GridView.count(
          key: const ValueKey('full'),
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [
            for (var board = 0; board < 9; board++)
              smallBoard(board, interactive: false),
          ],
        ),
      );
    } else {
      content = Column(
        key: ValueKey('zoomed-$_zoomedBoard'),
        children: [
          Row(
            children: [
              IconButton(
                key: const Key('zoom-out'),
                onPressed: _zoomOut,
                icon: const Icon(Icons.arrow_back),
                tooltip: l10n.zoomOut,
                color: colors.ink,
              ),
              const SizedBox(width: 8),
              _MiniMap(
                currentBoard: _zoomedBoard!,
                highlightColor: currentColor,
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: AspectRatio(
                aspectRatio: 1,
                child: smallBoard(_zoomedBoard!, interactive: true),
              ),
            ),
          ),
        ],
      );
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: content,
    );
  }
}

/// A small positional reference shown next to the back arrow while zoomed
/// in: which of the 9 boards this is, relative to the full board. Purely a
/// static indicator (not interactive) — the screen-reader label carries the
/// same "Board N" text already used for the unzoomed tap targets.
class _MiniMap extends StatelessWidget {
  const _MiniMap({required this.currentBoard, required this.highlightColor});

  final int currentBoard;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.ultimateSmallBoardLabel(currentBoard + 1),
      child: SizedBox(
        width: 28,
        height: 28,
        child: GridView.count(
          crossAxisCount: 3,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          children: [
            for (var board = 0; board < 9; board++)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: board == currentBoard
                      ? highlightColor
                      : colors.neutral,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SmallBoard extends StatelessWidget {
  const _SmallBoard({
    required this.engine,
    required this.board,
    required this.playable,
    required this.highlightColor,
    required this.staged,
    required this.lastMoveCell,
    required this.currentPerson,
    required this.currentColor,
    required this.appearance,
    required this.personFor,
    required this.onCellTap,
    required this.onZoomTap,
  });

  final UltimateEngine engine;
  final int board;
  final bool playable;
  final Color highlightColor;
  final UltimateMove? staged;

  /// Cell of the most recently committed move on this board, if any — the
  /// zoomed cell briefly highlights it (design: more visible where the AI
  /// just played, not just human taps the player already saw themselves).
  final int? lastMoveCell;
  final int currentPerson;
  final Color currentColor;

  /// How this skin draws move marks (painted vs. asset). Threaded down from
  /// the board so every cell shares one lookup.
  final ChipAppearance appearance;
  final int Function(Player) personFor;

  /// Null when unzoomed — cells don't respond to individual taps at that
  /// scale; the whole board responds via [onZoomTap] instead.
  final void Function(int cell)? onCellTap;

  /// Null when zoomed in — the board itself no longer toggles zoom; its
  /// cells handle taps via [onCellTap] instead.
  final VoidCallback? onZoomTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final result = engine.resultOf(board);

    final grid = DecoratedBox(
      decoration: BoxDecoration(
        color: playable ? highlightColor : colors.ground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        padding: const EdgeInsets.all(2),
        children: [
          for (var cell = 0; cell < 9; cell++)
            _UltimateCell(
              key: Key('ult-$board-$cell'),
              board: board,
              cell: cell,
              owner: engine.ownerOf(board, cell),
              stagedHere: staged?.cell == cell,
              isLastMove: lastMoveCell == cell,
              currentPerson: currentPerson,
              currentColor: currentColor,
              appearance: appearance,
              personFor: personFor,
              onTap: onCellTap == null ? null : () => onCellTap!(cell),
            ),
        ],
      ),
    );

    final claimant = result.claimant;
    final Widget boardContent =
        (claimant == null && result != BoardResult.drawn)
        ? grid
        : DecoratedBox(
            // Finished boards are out of play: dim them and stamp the
            // outcome. Claimed vs drawn differ by symbol, not colour alone
            // (design doc §6). The mark paints over a solid `surface`
            // backdrop (not straight over the dimmed grid) so its contrast
            // against whatever's behind it is the same tested-safe pairing
            // everywhere, not a translucency blend.
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(opacity: 0.3, child: grid),
                Center(
                  // The symbol resolving into place (design doc §4) — a
                  // small board only ever reaches this subtree once it has
                  // resolved, so AnimatedSwitcher's very first build already
                  // plays the entrance transition for whichever mark won.
                  child: AnimatedSwitcher(
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : context.gameAnimations.boardClaim,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                      child: child,
                    ),
                    child: claimant == null
                        ? FractionallySizedBox(
                            key: const ValueKey('drawn'),
                            widthFactor: 0.5,
                            heightFactor: 0.5,
                            child: CustomPaint(
                              painter: _MarkPainter(
                                color: colors.neutral,
                                isX: false,
                                filled: true,
                              ),
                            ),
                          )
                        : FractionallySizedBox(
                            key: ValueKey('claim-${claimant.name}'),
                            widthFactor: 0.7,
                            heightFactor: 0.7,
                            child: CustomPaint(
                              painter: _MarkPainter(
                                color: personFor(claimant) == 1
                                    ? colors.playerA
                                    : colors.playerB,
                                isX: personFor(claimant) == 1,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );

    if (onZoomTap == null) return boardContent;
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).ultimateSmallBoardLabel(board + 1),
      child: GestureDetector(
        onTap: onZoomTap,
        behavior: HitTestBehavior.opaque,
        child: IgnorePointer(child: boardContent),
      ),
    );
  }
}

class _UltimateCell extends StatelessWidget {
  const _UltimateCell({
    super.key,
    required this.board,
    required this.cell,
    required this.owner,
    required this.stagedHere,
    required this.isLastMove,
    required this.currentPerson,
    required this.currentColor,
    required this.appearance,
    required this.personFor,
    required this.onTap,
  });

  final int board;
  final int cell;
  final Player? owner;
  final bool stagedHere;

  /// Whether this cell is where the most recently committed move (any
  /// source) landed — briefly highlighted, distinct from the animated mark
  /// itself, so it stays visible even after the placement pop settles.
  final bool isLastMove;
  final int currentPerson;
  final Color currentColor;

  /// How this skin draws the move mark (painted X/O vs. a bundled asset).
  final ChipAppearance appearance;
  final int Function(Player) personFor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    // The person this mark represents: the current player while staging a
    // preview, otherwise whoever actually owns the cell.
    final markPerson = stagedHere ? currentPerson : (owner == null ? null : personFor(owner!));
    final mark = markPerson == null
        ? null
        : Padding(
            padding: const EdgeInsets.all(3),
            child: Opacity(
              opacity: stagedHere ? 0.45 : 1,
              child: _UltimateMark(
                appearance: appearance,
                isFirstPerson: markPerson == 1,
                color: stagedHere
                    ? currentColor
                    : personFor(owner!) == 1
                    ? colors.playerA
                    : colors.playerB,
              ),
            ),
          );
    // Only an actually-committed mark animates in (scale pop, same treatment
    // as StackingBoard's chips) — a staged ghost preview appears instantly,
    // same as it always has, since it isn't a real move yet.
    final animatedMark = owner == null
        ? mark
        : _AnimatedMark(
            animationKey: ValueKey('$board-$cell-${owner!.name}'),
            child: mark!,
          );

    final cellContent = GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ?animatedMark,
            // Keyed on board-cell-owner so a fresh highlight (and its
            // fade-out) restarts each time a *new* move lands here — not
            // just when this cell happens to rebuild for an unrelated
            // reason. Most useful for AI moves: they land with no tap of
            // the human's own to have already drawn their eye there.
            if (isLastMove)
              _LastMoveGlow(
                key: ValueKey('glow-$board-$cell-${owner?.name}'),
                color: personFor(owner!) == 1 ? colors.playerA : colors.playerB,
              ),
          ],
        ),
      ),
    );

    // Only a meaningful, independently-labelled target once zoomed in
    // (interactive) — when unzoomed the whole small board is one label
    // and these cells are hit-test-ignored anyway.
    if (onTap == null) return cellContent;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.ultimateCellLabel(board + 1, cell + 1),
      child: cellContent,
    );
  }
}

/// One player's move mark, drawn per the active skin's [ChipAppearance]:
/// procedurally (the X/O painter) for a [PaintedAppearance], or from a
/// bundled image for an [AssetAppearance] — the same painted-vs-asset flag
/// [ChipView] uses for stacking chips, so a future skin can supply art here
/// too. An asset that can't load falls back to the painter.
///
/// The outer [SizedBox.expand] is what keeps the mark full-size under the
/// loose constraints inside [_AnimatedMark]'s `AnimatedSwitcher`: a childless
/// `CustomPaint` (or an unsized `Image`) would otherwise collapse to a
/// zero-size dot in the cell centre.
class _UltimateMark extends StatelessWidget {
  const _UltimateMark({
    required this.appearance,
    required this.isFirstPerson,
    required this.color,
  });

  final ChipAppearance appearance;
  final bool isFirstPerson;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      painter: _MarkPainter(color: color, isX: isFirstPerson),
    );
    final Widget content = switch (appearance) {
      PaintedAppearance() => painted,
      AssetAppearance(:final resolve) => Image.asset(
          resolve(ChipAssetRequest(isFirstPerson: isFirstPerson)),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => painted,
        ),
    };
    return SizedBox.expand(child: content);
  }
}

/// A mark's entrance: a small scale-in pop, same treatment as
/// StackingBoard's `_AnimatedChip` (design doc §4's "moderate" animation
/// layer) — previously Ultimate placed marks with no animation at all.
/// Respects OS reduced-motion by collapsing to an instant swap.
class _AnimatedMark extends StatelessWidget {
  const _AnimatedMark({required this.animationKey, required this.child});

  final Key animationKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration =
        reduceMotion ? Duration.zero : context.gameAnimations.placement;

    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
/// same trick as the `AnimatedSwitcher`s elsewhere in this file.
class _LastMoveGlow extends StatelessWidget {
  const _LastMoveGlow({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: 0),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (context, opacity, child) => Opacity(
          opacity: opacity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

/// Person 1 marks X, person 2 marks O; a filled neutral disc stamps drawn
/// boards. Painted, not text, so it scales with cell size.
class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.color, required this.isX, this.filled = false});

  final Color color;
  final bool isX;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide * 0.14
      ..strokeCap = StrokeCap.round
      ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke;
    if (filled) {
      canvas.drawCircle(center, radius * 0.8, paint);
    } else if (isX) {
      final arm = radius * 0.62;
      canvas.drawLine(
        center - Offset(arm, arm),
        center + Offset(arm, arm),
        paint,
      );
      canvas.drawLine(
        center - Offset(arm, -arm),
        center + Offset(arm, -arm),
        paint,
      );
    } else {
      canvas.drawCircle(center, radius * 0.62, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.isX != isX || old.filled != filled;
}
