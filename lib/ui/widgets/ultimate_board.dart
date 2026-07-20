import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/game_controller.dart';
import '../../engines/common/player.dart';
import '../../engines/ultimate/ultimate_engine.dart';
import '../../engines/ultimate/ultimate_move.dart';
import '../../theme/tokens.dart';

/// The Ultimate board: 3×3 grid of 3×3 small boards. Playable boards carry
/// the always-on send-rule highlight — on a free move that is every open
/// board, the rule players most often forget (design doc §3.3).
class UltimateBoard extends ConsumerWidget {
  const UltimateBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (session == null) return const SizedBox.shrink();
    final controller = ref.read(gameControllerProvider.notifier);
    final engine = session.engine as UltimateEngine;
    final colors = context.gameColors;

    final playable = controller.ultimatePlayableBoards();
    final currentPerson = session.currentPerson;
    final currentColor = currentPerson == 1 ? colors.playerA : colors.playerB;
    final staged = session.stagedMove as UltimateMove?;

    return AspectRatio(
      aspectRatio: 1,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        children: [
          for (var board = 0; board < 9; board++)
            _SmallBoard(
              engine: engine,
              board: board,
              playable: playable.contains(board),
              highlightColor: colors.highlightFor(currentColor),
              staged: staged?.board == board ? staged : null,
              currentPerson: currentPerson,
              currentColor: currentColor,
              personFor: session.personFor,
              onCellTap: (cell) => controller.onUltimateCellTapped(board, cell),
            ),
        ],
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
  });

  final UltimateEngine engine;
  final int board;
  final bool playable;
  final Color highlightColor;
  final UltimateMove? staged;
  final int currentPerson;
  final Color currentColor;
  final int Function(Player) personFor;
  final void Function(int cell) onCellTap;

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
              owner: engine.ownerOf(board, cell),
              stagedHere: staged?.cell == cell,
              currentPerson: currentPerson,
              currentColor: currentColor,
              personFor: personFor,
              onTap: () => onCellTap(cell),
            ),
        ],
      ),
    );

    final claimant = result.claimant;
    if (claimant == null && result != BoardResult.drawn) return grid;

    // Finished boards are out of play: dim them and stamp the outcome.
    // Claimed vs drawn differ by symbol, not colour alone (design doc §6).
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: 0.3, child: grid),
        Center(
          child: claimant == null
              ? FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 0.5,
                  child: CustomPaint(
                    painter: _MarkPainter(color: colors.neutral, isX: false,
                        filled: true),
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
    );
  }
}

class _UltimateCell extends StatelessWidget {
  const _UltimateCell({
    super.key,
    required this.owner,
    required this.stagedHere,
    required this.currentPerson,
    required this.currentColor,
    required this.personFor,
    required this.onTap,
  });

  final Player? owner;
  final bool stagedHere;
  final int currentPerson;
  final Color currentColor;
  final int Function(Player) personFor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    return GestureDetector(
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
