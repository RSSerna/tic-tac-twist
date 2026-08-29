import 'package:flutter/material.dart';

import '../../theme/emote.dart';
import 'asset_glyph.dart';

/// Draws an emote from its bundled art, falling back to its icon when the
/// art isn't there.
///
/// No emote art is bundled yet, so today every emote renders its fallback —
/// which is the point: the catalogue, the loadout and the persistence all
/// work now, and a designer's PNGs drop in later without touching code.
class EmoteView extends StatelessWidget {
  const EmoteView({super.key, required this.emote, this.color});

  final Emote emote;
  final Color? color;

  @override
  Widget build(BuildContext context) => AssetGlyph(
    assetPath: emote.assetPath,
    fallbackIcon: emote.fallbackIcon,
    color: color,
  );
}
