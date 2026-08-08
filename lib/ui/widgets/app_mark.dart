import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The app's logo mark: rounded squares nested inside one another around a
/// 3×3 grid — the game's two ideas (nesting, tic-tac-toe) in one glyph.
///
/// Painted rather than bundled as art, so it inherits the skin's `ink` and
/// stays crisp at any size. Swap in a PNG via `AppImages` if a designer
/// produces one; nothing else needs to change.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppMarkPainter(ink: colors.ink)),
    );
  }
}

class _AppMarkPainter extends CustomPainter {
  _AppMarkPainter({required this.ink});

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final centre = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.045
      ..color = ink;

    // Two nested outlines, each inset from the last by a constant fraction —
    // the same concentric logic the chips use.
    for (final inset in const [0.0, 0.14]) {
      final half = side * (0.5 - inset) - stroke.strokeWidth / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: half * 2, height: half * 2),
          Radius.circular(half * 0.42),
        ),
        stroke,
      );
    }

    // The board: 3×3 filled cells with a gap between them, drawn as negative
    // space the way the real board is (design system §2.4).
    final gridExtent = side * 0.42;
    final cell = gridExtent / 3;
    final gap = cell * 0.16;
    final origin = centre - Offset(gridExtent / 2, gridExtent / 2);
    final fill = Paint()..color = ink;

    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 3; col++) {
        final rect = Rect.fromLTWH(
          origin.dx + col * cell + gap / 2,
          origin.dy + row * cell + gap / 2,
          cell - gap,
          cell - gap,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.12)),
          fill,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AppMarkPainter oldDelegate) => oldDelegate.ink != ink;
}
