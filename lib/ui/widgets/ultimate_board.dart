import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../engines/common/player.dart';
import '../../engines/ultimate/ultimate_engine.dart';
import '../../engines/ultimate/ultimate_move.dart';
import '../../l10n/generated/app_localizations.dart';
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
    final controller = ref.read(gameControllerProvider.notifier);
    final engine = session.engine as UltimateEngine;
    final colors = context.gameColors;
    final l10n = AppLocalizations.of(context);

    final playable = controller.ultimatePlayableBoards();
    final currentPerson = session.currentPerson;
    final currentColor = currentPerson == 1 ? colors.playerA : colors.playerB;
    final staged = session.stagedMove as UltimateMove?;

    Widget smallBoard(int board, {required bool interactive}) => _SmallBoard(
          engine: engine,
          board: board,
          playable: playable.contains(board),
          highlightColor: colors.highlightFor(currentColor),
          staged: staged?.board == board ? staged : null,
          currentPerson: currentPerson,
          currentColor: currentColor,
          personFor: session.personFor,
          onCellTap: interactive
              ? (cell) => controller.onUltimateCellTapped(board, cell)
              : null,
          onZoomTap: interactive ? null : () => _zoomTo(board),
        );

    final Widget content;
    if (_zoomedBoard == null) {
      content = GridView.count(
        key: const ValueKey('full'),
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (var board = 0; board < 9; board++)
            smallBoard(board, interactive: false),
        ],
      );
    } else {
      content = Column(
        key: ValueKey('zoomed-$_zoomedBoard'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              key: const Key('zoom-out'),
              onPressed: _zoomOut,
              icon: const Icon(Icons.arrow_back),
              tooltip: l10n.zoomOut,
              color: colors.ink,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: smallBoard(_zoomedBoard!, interactive: true),
            ),
          ),
        ],
      );
    }

    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
        child: content,
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
    required this.currentPerson,
    required this.currentColor,
    required this.personFor,
    required this.onCellTap,
    required this.onZoomTap,
  });

  final UltimateEngine engine;
  final int board;
  final bool playable;
  final Color highlightColor;
  final UltimateMove? staged;
  final int currentPerson;
  final Color currentColor;
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
              currentPerson: currentPerson,
              currentColor: currentColor,
              personFor: personFor,
              onTap: onCellTap == null ? null : () => onCellTap!(cell),
            ),
        ],
      ),
    );

    final claimant = result.claimant;
    final Widget boardContent = (claimant == null && result != BoardResult.drawn)
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
                  child: claimant == null
                      ? FractionallySizedBox(
                          widthFactor: 0.5,
                          heightFactor: 0.5,
                          child: CustomPaint(
                            painter: _MarkPainter(
                                color: colors.neutral, isX: false, filled: true),
                          ),
                        )
                      : FractionallySizedBox(
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
    required this.currentPerson,
    required this.currentColor,
    required this.personFor,
    required this.onTap,
  });

  final int board;
  final int cell;
  final Player? owner;
  final bool stagedHere;
  final int currentPerson;
  final Color currentColor;
  final int Function(Player) personFor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final cellContent = GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(2),
        ),
        child: owner == null && !stagedHere
            ? null
            : Padding(
                padding: const EdgeInsets.all(3),
                child: Opacity(
                  opacity: stagedHere ? 0.45 : 1,
                  child: CustomPaint(
                    painter: _MarkPainter(
                      color: stagedHere
                          ? currentColor
                          : personFor(owner!) == 1
                              ? colors.playerA
                              : colors.playerB,
                      isX: (stagedHere ? currentPerson : personFor(owner!)) == 1,
                    ),
                  ),
                ),
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
          center - Offset(arm, arm), center + Offset(arm, arm), paint);
      canvas.drawLine(
          center - Offset(arm, -arm), center + Offset(arm, -arm), paint);
    } else {
      canvas.drawCircle(center, radius * 0.62, paint);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.color != color || old.isX != isX || old.filled != filled;
}
