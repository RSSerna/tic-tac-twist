import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Draws a bundled image, falling back to an icon when the art isn't there.
///
/// Every cosmetic catalogue in the app ships before its art does — emotes and
/// celebrations both currently render nothing but fallbacks — so this is the
/// one place that behaviour lives. Same convention `ChipView` uses for asset
/// skins: a missing asset degrades to something drawable, never to a broken
/// image glyph.
class AssetGlyph extends StatelessWidget {
  const AssetGlyph({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.color,
  });

  final String assetPath;
  final IconData fallbackIcon;

  /// Tints the fallback icon. Ignored by real art, which carries its own
  /// colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.gameColors.ink;

    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          FittedBox(child: Icon(fallbackIcon, color: tint)),
    );
  }
}
