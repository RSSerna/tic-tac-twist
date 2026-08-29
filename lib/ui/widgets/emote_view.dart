import 'package:flutter/material.dart';

import '../../theme/emote.dart';
import '../../theme/tokens.dart';

/// Draws an emote from its bundled art, falling back to its icon when the
/// art isn't there.
///
/// No emote art is bundled yet, so today every emote renders its fallback —
/// which is the point: the catalogue, the loadout and the persistence all
/// work now, and a designer's PNGs drop in later without touching code.
/// Same arrangement as `ChipView`'s asset skins.
class EmoteView extends StatelessWidget {
  const EmoteView({super.key, required this.emote, this.color});

  final Emote emote;

  /// Tints the fallback icon. Ignored by real art, which carries its own
  /// colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.gameColors.ink;

    return Image.asset(
      emote.assetPath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) =>
          FittedBox(child: Icon(emote.fallbackIcon, color: tint)),
    );
  }
}
