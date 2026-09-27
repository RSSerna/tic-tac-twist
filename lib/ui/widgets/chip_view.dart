import 'package:flutter/material.dart';

import '../../theme/skin.dart';
import '../../theme/typography.dart';

/// Renders a chip: a flat shape in the owner's colour with `level`
/// concentric bands — level legible by size, band count, and colour at once
/// (design doc §2.3). Persons are additionally told apart by a centre
/// marker (dot vs cross) so colour is never the only signal (§6).
///
/// [appearance] is the one thing a skin may vary here (design doc §2.6: "chip
/// form (rings → dolls...)"), and it also carries the painted-vs-asset flag:
/// a [PaintedAppearance] draws the silhouette procedurally, an
/// [AssetAppearance] blits a bundled image (falling back to the painter if the
/// asset can't be loaded). Either way the band-count mechanic and every value
/// [sizeFactor] returns stay identical across skins — those are
/// gameplay-critical, not decorative (CLAUDE.md: skins may never alter chip
/// size relationships or level legibility), which is why the size wrapper
/// lives outside the appearance switch.
class ChipView extends StatelessWidget {
  const ChipView({
    super.key,
    required this.color,
    required this.ringColor,
    required this.level,
    required this.isFirstPerson,
    required this.appearance,
    this.ghost = false,
    this.showLevel = false,
    this.fillsCell = false,
  });

  final Color color;
  final Color ringColor;
  final int level;
  final bool isFirstPerson;
  final ChipAppearance appearance;

  /// Translucent staged-preview rendering.
  final bool ghost;

  /// Draws the level as a numeral in the bottom-right corner — a fourth
  /// signal alongside size, band count and colour (design system §2.3).
  ///
  /// **Only ever set this where the chip is already visible.** Level is
  /// public information for a chip you can see; it is emphatically not
  /// public for a buried one, and a numeral would leak it far more plainly
  /// than any of the other three signals. The board only draws
  /// `topChipAt`, which is why this is safe there.
  final bool showLevel;

  /// Draws at the full size of whatever box this is given, ignoring
  /// [sizeFactor].
  ///
  /// **Only for surfaces that have no chip levels at all** — today just the
  /// Ultimate board, where a skin's chip art stands in for the X/O mark and
  /// every mark is equal. The size ladder is gameplay-critical wherever
  /// levels coexist (CLAUDE.md), so this must never be set on a stacking
  /// board or the inventory, where relative size is how a player reads
  /// level.
  final bool fillsCell;

  /// Diameter relative to the cell, by level: L1 smallest … L4 largest.
  static double sizeFactor(int level) => 0.38 + 0.14 * level;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: ghost ? 0.45 : 1,
      child: FractionallySizedBox(
        widthFactor: fillsCell ? 1 : sizeFactor(level),
        heightFactor: fillsCell ? 1 : sizeFactor(level),
        child: showLevel
            ? Stack(
                fit: StackFit.expand,
                children: [
                  _forAppearance(appearance),
                  // Sized as a fraction of the chip, so the badge grows with
                  // the level rather than fighting the size ladder.
                  FractionallySizedBox(
                    alignment: Alignment.bottomRight,
                    widthFactor: 0.42,
                    heightFactor: 0.42,
                    child: _LevelBadge(
                      level: level,
                      fill: ringColor,
                      accent: color,
                    ),
                  ),
                ],
              )
            : _forAppearance(appearance),
      ),
    );
  }

  /// The painted rendering, also the fallback when an asset fails to load.
  Widget _painted(ChipForm form) => CustomPaint(
    painter: _ChipPainter(
      color: color,
      ringColor: ringColor,
      level: level,
      isFirstPerson: isFirstPerson,
      form: form,
    ),
    // A childless CustomPaint has no intrinsic size; the enclosing
    // FractionallySizedBox gives tight constraints, so an explicit child
    // isn't needed here — but SizedBox.expand keeps it robust if this
    // painter is ever reused under looser constraints.
    child: const SizedBox.expand(),
  );

  Widget _forAppearance(ChipAppearance appearance) => switch (appearance) {
    PaintedAppearance(:final form) => _painted(form),
    AssetAppearance(:final resolve, :final fallbackForm) => Image.asset(
      resolve(ChipAssetRequest(level: level, isFirstPerson: isFirstPerson)),
      fit: BoxFit.contain,
      // Missing/broken art never shows a broken-image glyph — it paints
      // the equivalent procedural chip instead (design decision: asset
      // skins degrade to painted, they never break the board).
      errorBuilder: (context, error, stackTrace) => _painted(fallbackForm),
    ),
  };
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

  /// A faceted gem silhouette for `GameSkin.fragmentShard` — 6 vertices,
  /// stretched vertically so it reads as a cut stone rather than a plain
  /// hexagon (the same asymmetric-about-the-vertical-axis trick
  /// [_dollSilhouette] uses to read as a doll rather than "two circles").
  /// Feeds the same concentric-band level loop [_ringSilhouette]/
  /// [_dollSilhouette] already use in [paint] — level legibility (band
  /// count + size ladder) comes for free from that shared mechanism, no
  /// change needed anywhere else.
  static Path _shardSilhouette(Offset center, double radius) {
    const points = [
      Offset(0, -1.0), // top point
      Offset(0.62, -0.38), // upper-right shoulder
      Offset(0.5, 0.55), // lower-right
      Offset(0, 1.0), // bottom point
      Offset(-0.5, 0.55), // lower-left
      Offset(-0.62, -0.38), // upper-left shoulder
    ];
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = center + points[i] * radius;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path _silhouetteAt(Offset center, double radius) => switch (form) {
    ChipForm.rings => _ringSilhouette(center, radius),
    ChipForm.dolls => _dollSilhouette(center, radius),
    ChipForm.shards => _shardSilhouette(center, radius),
    // Never reached: `marks` is drawn as a stroked glyph by [_paintMark],
    // not as a filled silhouette with bands. Kept exhaustive so adding a
    // form is a compile error rather than a blank chip.
    ChipForm.marks => _ringSilhouette(center, radius),
  };

  /// The classic tic-tac-toe glyphs — a stroked X or O in the player's
  /// colour, with none of the fill, bands or centre marker the other forms
  /// use. Level comes from the size ladder and the numeral badge instead
  /// (design system §2.3).
  void _paintMark(Canvas canvas, Offset center, double radius) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.28
      ..strokeCap = StrokeCap.round;

    if (isFirstPerson) {
      final arm = radius * 0.58;
      canvas.drawLine(
        center - Offset(arm, arm),
        center + Offset(arm, arm),
        stroke,
      );
      canvas.drawLine(
        center - Offset(arm, -arm),
        center + Offset(arm, -arm),
        stroke,
      );
    } else {
      canvas.drawCircle(center, radius * 0.64, stroke);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    if (form == ChipForm.marks) {
      _paintMark(canvas, center, radius);
      return;
    }

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
      canvas.drawLine(
        center - Offset(arm, arm),
        center + Offset(arm, arm),
        markPaint,
      );
      canvas.drawLine(
        center - Offset(arm, -arm),
        center + Offset(arm, -arm),
        markPaint,
      );
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

/// The level numeral, as a small badge on the chip's lower-right.
///
/// Filled with the chip's ring colour and outlined in the player's colour:
/// the badge straddles the chip's edge, so it has to read against both the
/// chip's fill and the cell behind it. A solid player-coloured badge would
/// vanish into the chip; a plain numeral would vanish into the cell.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.fill,
    required this.accent,
  });

  final int level;
  final Color fill;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // Excluded from semantics: the numeral repeats what the cell's own label
    // already says ("…, level 1"), and letting it merge in appends a bare
    // "1" to that label — noise for a screen reader, and it silently broke
    // the label assertions.
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: FittedBox(
            child: Text(
              '$level',
              // Tabular figures, per design system §2.2 — and the numeral is
              // the same width at every level, so the badge doesn't jump.
              style: context.gameTextStyles.data.copyWith(color: accent),
            ),
          ),
        ),
      ),
    );
  }
}
