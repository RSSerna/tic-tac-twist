import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../theme/tokens.dart';

/// One of the project's own SVG icons (`AppIcons`), tinted from the theme.
///
/// The tint is not optional decoration: every file in the set is authored
/// white, so an untinted one is invisible on `surface` and `ground` alike.
/// Painting through a `srcIn` filter also means the icons inherit state the
/// way Material's did — a dimmed glyph for something unavailable, a player
/// colour where one applies — rather than each call site having to know how
/// the file was drawn.
class AppGlyph extends StatelessWidget {
  const AppGlyph(
    this.asset, {
    super.key,
    this.size,
    this.color,
    this.flipped = false,
    this.semanticLabel,
  });

  final String asset;

  /// Both dimensions — the icons are square.
  ///
  /// Null takes the ambient [IconTheme]'s size, exactly as [Icon] does, and
  /// 24 where there is none. It must not fall through to the SVG's own
  /// dimensions: the files are 101×101, so an unsized glyph in an unbounded
  /// row renders four times the size of the icon it replaced and shoves
  /// everything below it off the screen.
  final double? size;

  /// Defaults to `ink`. Pass `neutral` for a badge, or a player's colour
  /// where the glyph stands for a seat.
  final Color? color;

  /// Mirrors horizontally. The set has one chevron; the backwards direction
  /// is that same file flipped, so the two can never drift apart.
  final bool flipped;

  /// Announced by a screen reader. Only for a glyph carrying meaning of its
  /// own — a lock badge, say. Leave null where the surrounding row already
  /// says it, or the label gets read twice.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? IconTheme.of(context).size ?? 24;
    final glyph = SvgPicture.asset(
      asset,
      width: dimension,
      height: dimension,
      fit: BoxFit.contain,
      semanticsLabel: semanticLabel,
      colorFilter: ColorFilter.mode(
        color ?? context.gameColors.ink,
        BlendMode.srcIn,
      ),
    );

    if (!flipped) return glyph;
    return Transform.flip(flipX: true, child: glyph);
  }
}
