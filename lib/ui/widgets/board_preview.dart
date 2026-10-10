import 'package:flutter/material.dart';

import '../../theme/board_skin.dart';
import 'board_surface.dart';

/// A board with no game on it — what the picker tiles and the shop card show.
/// Drawn by the same [BoardSurface] the real board uses, so what a player
/// previews is what they get.
class BoardPreview extends StatelessWidget {
  const BoardPreview({super.key, required this.skin});

  final BoardSkin skin;

  /// The side a board's gaps and radii are authored for; smaller previews
  /// scale them down in proportion so the cells don't turn into blobs.
  static const double _referenceSide = 300;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => BoardSurface(
      skin: skin,
      detailScale: (constraints.biggest.shortestSide / _referenceSide).clamp(
        0.1,
        1.0,
      ),
      cellBuilder: (context, cell, face) => DecoratedBox(decoration: face),
    ),
  );
}
