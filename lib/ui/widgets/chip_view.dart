import 'package:flutter/material.dart';

/// Renders a chip: flat disc in the owner's colour with `level` concentric
/// rings — level legible by size, ring count, and colour at once (design
/// doc §2.3). Persons are additionally told apart by a centre marker (dot
/// vs cross) so colour is never the only signal (§6).
class ChipView extends StatelessWidget {
  const ChipView({
    super.key,
    required this.color,
    required this.ringColor,
    required this.level,
    required this.isFirstPerson,
    this.ghost = false,
  });

  final Color color;
  final Color ringColor;
  final int level;
  final bool isFirstPerson;

  /// Translucent staged-preview rendering.
  final bool ghost;

  /// Diameter relative to the cell, by level: L1 smallest … L4 largest.
  static double sizeFactor(int level) => 0.38 + 0.14 * level;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: ghost ? 0.45 : 1,
      child: FractionallySizedBox(
        widthFactor: sizeFactor(level),
        heightFactor: sizeFactor(level),
        child: CustomPaint(
          painter: _ChipPainter(
            color: color,
            ringColor: ringColor,
            level: level,
            isFirstPerson: isFirstPerson,
          ),
        ),
      ),
    );
  }
}

class _ChipPainter extends CustomPainter {
  _ChipPainter({
    required this.color,
    required this.ringColor,
    required this.level,
    required this.isFirstPerson,
  });

  final Color color;
  final Color ringColor;
  final int level;
  final bool isFirstPerson;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawCircle(center, radius, Paint()..color = color);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07;
    for (var i = 0; i < level; i++) {
      canvas.drawCircle(center, radius * (0.9 - 0.16 * i), ringPaint);
    }

    if (isFirstPerson) {
      canvas.drawCircle(center, radius * 0.1, Paint()..color = ringColor);
    } else {
      final markPaint = Paint()
        ..color = ringColor
        ..strokeWidth = radius * 0.08
        ..strokeCap = StrokeCap.round;
      final arm = radius * 0.12;
      canvas.drawLine(center - Offset(arm, arm), center + Offset(arm, arm),
          markPaint);
      canvas.drawLine(center - Offset(arm, -arm), center + Offset(arm, -arm),
          markPaint);
    }
  }

  @override
  bool shouldRepaint(_ChipPainter old) =>
      old.color != color ||
      old.ringColor != ringColor ||
      old.level != level ||
      old.isFirstPerson != isFirstPerson;
}
