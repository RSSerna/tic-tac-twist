import 'package:flutter/material.dart';

/// Where the 3×3 playable area sits inside a board's art, as fractions of
/// the board's side. Fractions, not pixels, so one set of numbers holds at
/// every size — and four separate numbers, not one, because a piece of art
/// is rarely centred on its own canvas.
@immutable
class BoardInsets {
  const BoardInsets({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  static const zero = BoardInsets();

  final double left;
  final double top;
  final double right;
  final double bottom;

  /// The playable area inside a board of [side] × [side].
  Rect gridRect(double side) => Rect.fromLTRB(
    left * side,
    top * side,
    side - right * side,
    side - bottom * side,
  );

  @override
  bool operator ==(Object other) =>
      other is BoardInsets &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// Where a board's nine cells land, derived from one place so the grid that
/// takes taps, the art underneath it and the winning-line overlay can never
/// disagree about it.
@immutable
class BoardLayout {
  const BoardLayout({required this.insets, required this.gap});

  final BoardInsets insets;

  /// Space between cells, in logical pixels.
  final double gap;

  Rect gridRect(double side) => insets.gridRect(side);

  @override
  bool operator ==(Object other) =>
      other is BoardLayout && other.insets == insets && other.gap == gap;

  @override
  int get hashCode => Object.hash(insets, gap);

  /// Width ÷ height of one cell. 1 unless the art's playable area isn't
  /// square, in which case the cells stretch with it rather than the grid
  /// overflowing its area.
  double cellAspect(double side) {
    final grid = gridRect(side);
    return (grid.width - 2 * gap) / (grid.height - 2 * gap);
  }

  /// The nine cell rectangles in row-major order, in board coordinates.
  List<Rect> cellRects(double side) {
    final grid = gridRect(side);
    final cellW = (grid.width - 2 * gap) / 3;
    final cellH = (grid.height - 2 * gap) / 3;
    return [
      for (var cell = 0; cell < 9; cell++)
        Rect.fromLTWH(
          grid.left + (cell % 3) * (cellW + gap),
          grid.top + (cell ~/ 3) * (cellH + gap),
          cellW,
          cellH,
        ),
    ];
  }
}

/// Colours of a painted slab. Lives with the model rather than in a widget:
/// nothing outside the theme layer names a colour (CLAUDE.md), and a skin's
/// palette is part of the skin.
@immutable
class SlabPalette {
  const SlabPalette({
    required this.slabLight,
    required this.slabDark,
    required this.edgeLight,
    required this.edgeDark,
    required this.cellFace,
    required this.recess,
    required this.shadow,
  });

  /// Slab gradient, top-left to bottom-right.
  final Color slabLight;
  final Color slabDark;

  /// Bevel strokes on the slab's rim.
  final Color edgeLight;
  final Color edgeDark;

  /// The playing surface of one cell, and the inner shadow along its top-left
  /// edges that makes it read as set into the slab.
  final Color cellFace;
  final Color recess;

  /// The slab's drop shadow on the app background.
  final Color shadow;
}

/// What a board is drawn with. Both subtypes only ever supply *backdrop*: the
/// grid, the taps, the highlight and everything gameplay-critical are drawn by
/// the board widget on top (same split as `ChipAppearance`).
sealed class BoardArt {
  const BoardArt();
}

/// Drawn procedurally — no asset, so nothing to ship, size or fail to load.
@immutable
class PaintedBoard extends BoardArt {
  const PaintedBoard(this.palette);

  final SlabPalette palette;
}

/// Drawn from a bundled image. If it fails to load the board falls back to
/// plain cells, so a missing asset never leaves an invisible board.
@immutable
class AssetBoard extends BoardArt {
  const AssetBoard(this.path, {required this.cellScrim});

  final String path;

  /// How strongly a pale plate (`GameColors.surface`) is laid over each cell
  /// of the art, 0–1. Busy or mid-tone art would otherwise sink the buried
  /// collar and the amber chips below the 3:1 graphics-contrast bar
  /// (`02-DESIGN-SYSTEM.md` §2.1), so the cell is lightened rather than the
  /// collar or the chips being altered — those aren't a skin's to change.
  final double cellScrim;
}

/// Everything about how a board lays out and looks.
@immutable
class BoardStyle {
  const BoardStyle({
    this.art,
    this.insets = BoardInsets.zero,
    this.gap = 8,
    this.cellRadius = 4,
  });

  /// Null for the classic board: a transparent slab, with each cell painting
  /// its own `surface` face (design doc §2.4: the grid is negative space).
  final BoardArt? art;

  /// Where the nine cells sit inside the art. Zero when the art *is* the grid.
  final BoardInsets insets;

  /// Space between cells in logical pixels — the classic board's negative
  /// space. Art that draws its own grooves uses 0.
  final double gap;

  final double cellRadius;

  BoardLayout get layout => BoardLayout(insets: insets, gap: gap);
}

/// A cosmetic board for the 3×3 stacking modes (Stack-Static, Stack-Movable).
///
/// **One board per match, not one per player** — unlike chips, a board has no
/// owner, so it's chosen and persisted once. **Ultimate doesn't use these**:
/// its 81 cells aren't a board that art for a 3×3 slab can sit under (see
/// `09-DECISIONS-LOG.md`).
///
/// A board may only change appearance, never the gameplay-critical parts of
/// `02-DESIGN-SYSTEM.md` §2.4–2.6: cell tap targets, the legal-move highlight,
/// the buried collar and chip size relationships are all drawn by the board
/// widget on top of whatever a board paints.
enum BoardSkin {
  /// Today's look, and the default: same gap, radius and colours as the board
  /// had before boards were skinnable.
  classic(id: 'classic', free: true, style: BoardStyle()),

  /// Pale on purpose: a dark board would sink the indigo chip, the `neutral`
  /// buried collar and the 15% player highlight (`02-DESIGN-SYSTEM.md` §2.1).
  sandstone(
    id: 'sandstone',
    free: true,
    style: BoardStyle(
      art: PaintedBoard(_sandstonePalette),
      insets: BoardInsets(left: 0.045, top: 0.045, right: 0.045, bottom: 0.045),
      gap: 6,
      cellRadius: 8,
    ),
  ),

  /// Bought in the Shop (`ProductId.boardRock`), not free.
  ///
  /// TODO(rock-board-art): this ships on `rock_board.png` **as it was
  /// delivered**, which does not meet `docs/10-BRIEF-DISENADOR.md`: it is
  /// 3758×3625 (not square), the grid is off-centre and its carved cells are
  /// uneven (~420–540 px), and it has a red/yellow halo along some edges.
  /// When the designer's version arrives: replace the PNG, re-measure
  /// [BoardStyle.insets] (the temporary debug outline in `BoardSurface` is the
  /// quickest way — see `07-SKINS.md` "authoring a board"), then drop the
  /// `BoxFit.fill` squash and `cacheWidth` workarounds in `board_surface.dart`.
  rock(
    id: 'rock',
    // purchaseOnly: true,
    free: true,
    style: BoardStyle(
      art: AssetBoard('assets/boards/rock_board.png', cellScrim: 0.7),
      // Measured by eye from the delivered art; calibrate against the app.
      insets: BoardInsets(left: 0.095, top: 0.075, right: 0.125, bottom: 0.13),
      gap: 0,
      cellRadius: 12,
    ),
  );

  const BoardSkin({
    required this.id,
    required this.style,
    this.free = false,
    this.purchaseOnly = false,
  }) : assert(
         !(free && purchaseOnly),
         'a board is either free or bought, never both',
       );

  /// Stable, persisted, never shown to players — renaming one orphans a
  /// player's saved choice.
  final String id;

  final BoardStyle style;

  /// Available without unlocking.
  final bool free;

  /// Only a store purchase unlocks it — no achievement, chest or fragment
  /// route exists for boards (see `08-STORE-ITEMS.md`).
  final bool purchaseOnly;

  /// Used when nothing is selected yet, and whenever a saved choice can't be
  /// honoured (retired id, or one that isn't unlocked).
  static const defaultChoice = BoardSkin.classic;
}

const _sandstonePalette = SlabPalette(
  slabLight: Color(0xFFDCCFB9),
  slabDark: Color(0xFFBFAE93),
  edgeLight: Color(0xFFF1E8D8),
  edgeDark: Color(0xFF9C8B72),
  // Checked against the cell face: `neutral` collar 3.98:1, `ink` 9.99:1,
  // `playerA` 6.82:1, `playerB` 3.08:1 — all over the 3:1 graphics bar.
  cellFace: Color(0xFFEADFCC),
  recess: Color(0xFFB9A78B),
  shadow: Color(0x33000000),
);
