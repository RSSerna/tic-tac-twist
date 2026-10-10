import 'package:flutter/material.dart';

import '../../theme/board_skin.dart';

/// Draws an animated line through three winning cells of a 3×3 grid — used
/// for both the stacking board's own cells and Ultimate's big-board cells,
/// which share the same 0–8 indexing (design doc §4: "draw the line through
/// the winning squares rather than just ending the game"). Uses fractional
/// thirds rather than introspecting the board's actual `GridView` geometry
/// (spacing between cells is a few px against a 300+px board — imperceptible
/// to approximate, and far simpler than reverse-engineering grid layout).
class WinningLineOverlay extends StatelessWidget {
  const WinningLineOverlay({
    super.key,
    required this.line,
    required this.color,
    required this.duration,
    this.insets = BoardInsets.zero,
  });

  /// Where the 3×3 cells sit inside this widget's box. Zero unless a board
  /// skin's art insets them — the line has to run through the cells, not
  /// through the art's frame.
  final BoardInsets insets;

  final List<int> line;
  final Color color;
  final Duration duration;

  static Offset _centerOf(int cell) {
    final col = cell % 3;
    final row = cell ~/ 3;
    return Offset((col + 0.5) / 3, (row + 0.5) / 3);
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, t, _) => CustomPaint(
        painter: _WinningLinePainter(
          // The line's ends are the first/last of its three cells for every
          // row/column/diagonal the engines can produce (see
          // stacking_engine.dart / ultimate_engine.dart's `_lines`).
          start: _centerOf(line.first),
          end: _centerOf(line.last),
          progress: t,
          color: color,
          insets: insets,
        ),
      ),
    );
  }
}

class _WinningLinePainter extends CustomPainter {
  _WinningLinePainter({
    required this.start,
    required this.end,
    required this.progress,
    required this.color,
    required this.insets,
  });

  final BoardInsets insets;
  final Offset start;
  final Offset end;
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = insets.gridRect(size.width);
    Offset place(Offset f) =>
        Offset(grid.left + f.dx * grid.width, grid.top + f.dy * grid.height);
    final from = place(start);
    final to = place(end);
    final current = Offset.lerp(from, to, progress)!;
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.shortestSide * 0.02
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(from, current, paint);
  }

  @override
  bool shouldRepaint(_WinningLinePainter old) =>
      old.start != start ||
      old.end != end ||
      old.progress != progress ||
      old.color != color ||
      old.insets != insets;
}
