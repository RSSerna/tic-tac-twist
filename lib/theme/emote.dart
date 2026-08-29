import 'package:flutter/material.dart';

/// The emotes a player can equip and send during a match.
///
/// Catalogue, not a fixed set: emotes are a purchasable cosmetic, so this
/// list is expected to grow. Adding one means an entry here, a name string
/// in both ARBs, and (optionally) art at [assetPath] — nothing else.
///
/// Each emote renders from a bundled image and falls back to [fallbackIcon]
/// when the art is missing, the same convention `ChipView` uses for asset
/// skins. That's what lets the catalogue ship before any art exists.
enum Emote {
  thumbsUp(id: 'thumbs_up', fallbackIcon: Icons.thumb_up, free: true),
  clap(id: 'clap', fallbackIcon: Icons.sign_language, free: true),
  laugh(id: 'laugh', fallbackIcon: Icons.sentiment_very_satisfied, free: true),
  cry(id: 'cry', fallbackIcon: Icons.sentiment_very_dissatisfied, free: true),
  surprised(id: 'surprised', fallbackIcon: Icons.sentiment_neutral),
  thinking(id: 'thinking', fallbackIcon: Icons.psychology),
  fire(id: 'fire', fallbackIcon: Icons.local_fire_department),
  heart(id: 'heart', fallbackIcon: Icons.favorite),
  party(id: 'party', fallbackIcon: Icons.celebration),
  star(id: 'star', fallbackIcon: Icons.star);

  const Emote({
    required this.id,
    required this.fallbackIcon,
    this.free = false,
  });

  /// Stable, persisted, never shown to players — renaming one orphans a
  /// player's saved loadout.
  final String id;

  final IconData fallbackIcon;

  /// Available without unlocking. The rest arrive by purchase (product doc
  /// §2.2's cosmetics route) once store products exist for them.
  final bool free;

  /// Where this emote's art lives once a designer produces it.
  ///
  /// Nothing is bundled yet, so every emote currently renders its
  /// [fallbackIcon]. Dropping PNGs here and adding `assets/emotes/` to
  /// pubspec.yaml switches them over with no code change.
  String get assetPath => 'assets/emotes/$id.png';

  /// How many emotes a player may equip for a match.
  static const loadoutSize = 4;
}
