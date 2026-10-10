import 'package:flutter/material.dart';

import '../../theme/board_skin.dart';
import '../../theme/tokens.dart';

/// Builds one cell's content. [face] is the cell's own backdrop — the classic
/// board's `surface` square, or nothing at all when the board's art already
/// draws the cell — so a cell only has to apply it, never decide it.
typedef BoardCellBuilder =
    Widget Function(BuildContext context, int cell, BoxDecoration face);

/// A 3×3 board: a skin's art, with the nine cells laid over its playable area.
///
/// The one place that knows how a [BoardSkin] turns into pixels, so the real
/// board, the picker previews and the shop card can't drift apart. The art is
/// backdrop only — taps, the legal-move highlight, the buried collar and the
/// chips are all drawn by whatever [cellBuilder] returns, on top.
class BoardSurface extends StatelessWidget {
  const BoardSurface({
    super.key,
    required this.skin,
    required this.cellBuilder,
    this.detailScale = 1,
  });

  final BoardSkin skin;

  /// Shrinks the board's gaps and corner radii (not its layout) for a small
  /// preview, where a full-size 8px gap would swallow the cells. 1 on a real
  /// board.
  final double detailScale;
  final BoardCellBuilder cellBuilder;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    final style = skin.style;
    final layout = BoardLayout(
      insets: style.insets,
      gap: style.gap * detailScale,
    );
    final cellRadius = style.cellRadius * detailScale;
    final art = style.art;

    // The classic board has no art, so each cell paints its own face. With
    // art, the art paints it and the cell stays transparent — anything else
    // would hide the grooves it's meant to show.
    final face = BoxDecoration(
      color: art == null ? colors.surface : null,
      borderRadius: BorderRadius.circular(cellRadius),
    );

    return AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.maxWidth;
          final grid = layout.gridRect(side);
          return Stack(
            children: [
              if (art != null)
                Positioned.fill(
                  child: switch (art) {
                    PaintedBoard(:final palette) => CustomPaint(
                      painter: _SlabPainter(
                        palette: palette,
                        layout: layout,
                        cellRadius: cellRadius,
                      ),
                    ),
                    final AssetBoard asset => _AssetArt(
                      art: asset,
                      layout: layout,
                      cellRadius: cellRadius,
                    ),
                  },
                ),
              Positioned.fromRect(
                rect: grid,
                child: GridView.count(
                  crossAxisCount: 3,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  mainAxisSpacing: layout.gap,
                  crossAxisSpacing: layout.gap,
                  childAspectRatio: layout.cellAspect(side),
                  children: [
                    for (var cell = 0; cell < 9; cell++)
                      cellBuilder(context, cell, face),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A board image, with a safe fallback and a pale plate over each cell.
class _AssetArt extends StatelessWidget {
  const _AssetArt({
    required this.art,
    required this.layout,
    required this.cellRadius,
  });

  final AssetBoard art;
  final BoardLayout layout;
  final double cellRadius;

  @override
  Widget build(BuildContext context) {
    final colors = context.gameColors;
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          art.path,
          // TODO(rock-board-art): `fill` squashes the delivered, non-square
          // PNG (~3.7% horizontally) into the square board, and `cacheWidth`
          // caps its decoded size (~54 MB at full resolution). Both exist only
          // because the art doesn't meet `docs/10-BRIEF-DISENADOR.md`; drop
          // them when it's replaced with a 1536×1536 square.
          fit: BoxFit.fill,
          cacheWidth: 1600,
          // A missing or broken asset must never leave an invisible board:
          // fall back to plain cells, which is also what the plates below are.
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
        // Lightens each cell so the buried collar and the chips keep their
        // contrast over mid-tone art (see [AssetBoard.cellScrim]). Also the
        // fallback face if the image failed to load.
        CustomPaint(
          painter: _CellPlatePainter(
            layout: layout,
            color: colors.surface.withValues(alpha: art.cellScrim),
            radius: cellRadius,
          ),
        ),
      ],
    );
  }
}

class _CellPlatePainter extends CustomPainter {
  _CellPlatePainter({
    required this.layout,
    required this.color,
    required this.radius,
  });

  final BoardLayout layout;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final rect in layout.cellRects(size.width)) {
      // Pulled in a touch so a plate on an outer cell can't hang over the
      // art's irregular edge.
      final plate = rect.deflate(rect.shortestSide * 0.04);
      canvas.drawRRect(
        RRect.fromRectAndRadius(plate, Radius.circular(radius)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CellPlatePainter old) =>
      old.layout != layout || old.color != color || old.radius != radius;
}

/// The painted slab: a bevelled stone block with the nine cells set into it.
class _SlabPainter extends CustomPainter {
  _SlabPainter({
    required this.palette,
    required this.layout,
    required this.cellRadius,
  });

  final SlabPalette palette;
  final BoardLayout layout;
  final double cellRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width;
    final bounds = Offset.zero & size;
    final slab = RRect.fromRectAndRadius(bounds, Radius.circular(side * 0.05));

    // Drop shadow, so the slab sits on the app background rather than in it.
    canvas.drawRRect(
      slab.shift(Offset(0, side * 0.008)),
      Paint()
        ..color = palette.shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, side * 0.012),
    );

    canvas.drawRRect(
      slab,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.slabLight, palette.slabDark],
        ).createShader(bounds),
    );

    // Rim bevel: lit from the top-left, shaded bottom-right — one gradient
    // stroke, so the light turns the corners instead of changing at a seam.
    canvas.drawRRect(
      slab.deflate(side * 0.004),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * 0.008
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.edgeLight, palette.edgeDark],
        ).createShader(bounds),
    );

    // The cells, each set into the slab: a face, plus an inner shadow along
    // its top and left edges where the slab's lip overhangs it.
    for (final rect in layout.cellRects(side)) {
      final cell = RRect.fromRectAndRadius(rect, Radius.circular(cellRadius));
      canvas.drawRRect(cell, Paint()..color = palette.cellFace);
      canvas.save();
      canvas.clipRRect(cell);
      canvas.drawRRect(
        cell.shift(Offset(side * 0.006, side * 0.006)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side * 0.012
          ..color = palette.recess,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SlabPainter old) =>
      old.palette != palette ||
      old.layout != layout ||
      old.cellRadius != cellRadius;
}
