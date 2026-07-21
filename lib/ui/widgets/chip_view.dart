import 'package:flutter/material.dart';

import '../../theme/skin.dart';

/// Renders a chip: a flat shape in the owner's colour with `level`
/// concentric bands — level legible by size, band count, and colour at once
/// (design doc §2.3). Persons are additionally told apart by a centre
/// marker (dot vs cross) so colour is never the only signal (§6).
///
/// [form] is the one thing a skin may vary here (design doc §2.6: "chip
/// form (rings → dolls...)"). The band-count mechanic itself, and every
/// value [sizeFactor] returns, stay identical across forms — those are
/// gameplay-critical, not decorative (CLAUDE.md: skins may never alter chip
/// size relationships or level legibility).
class ChipView extends StatelessWidget {
  const ChipView({
    super.key,
    required this.color,
    required this.ringColor,
    required this.level,
    required this.isFirstPerson,
    required this.form,
    this.ghost = false,
  });

  final Color color;
  final Color ringColor;
  final int level;
  final bool isFirstPerson;
  final ChipForm form;

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
            form: form,
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
    required this.form,
  });

  final Color color;
  final Color ringColor;
  final int level;
  final bool isFirstPerson;
  final ChipForm form;

  /// A snowman-like union of two circles — head and body — standing in for
  /// a nesting doll's side profile. Simple enough to render reliably at any
  /// size, and different enough from [_ringSilhouette] to read as a
  /// distinct skin at a glance.
  static Path _dollSilhouette(Offset center, double radius) {
    final headRadius = radius * 0.42;
    final headCenter = center - Offset(0, radius * 0.62);
    final bodyRadius = radius * 0.95;
    final bodyCenter = center + Offset(0, radius * 0.12);
    final head = Path()
      ..addOval(Rect.fromCircle(center: headCenter, radius: headRadius));
    final body = Path()
      ..addOval(Rect.fromCircle(center: bodyCenter, radius: bodyRadius));
    return Path.combine(PathOperation.union, body, head);
  }

  static Path _ringSilhouette(Offset center, double radius) =>
      Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  Path _silhouetteAt(Offset center, double radius) => switch (form) {
        ChipForm.rings => _ringSilhouette(center, radius),
        ChipForm.dolls => _dollSilhouette(center, radius),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    canvas.drawPath(_silhouetteAt(center, radius), Paint()..color = color);

    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07;
    for (var i = 0; i < level; i++) {
      canvas.drawPath(
        _silhouetteAt(center, radius * (0.9 - 0.16 * i)),
        ringPaint,
      );
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
      old.isFirstPerson != isFirstPerson ||
      old.form != form;
}
