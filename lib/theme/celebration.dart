import 'package:flutter/material.dart';

/// Fragments a chest must collect toward each locked celebration before it
/// unlocks. One placeholder value for all twelve — tune per celebration if
/// some should cost more.
const _kCelebrationFragments = 30;

/// The victory celebrations ("flexing") a player can equip — one plays when
/// they win.
///
/// Like [Emote], this is a catalogue that's expected to grow.
/// Adding one means an entry here, a name string in both ARBs, and
/// (optionally) art at [assetPath].
///
/// **Nothing plays a celebration yet.** The format isn't decided — image,
/// sprite sequence or video — so this models *choosing* one, which is local
/// and works today. Playback lands with whatever format wins.
enum Celebration {
  happy(id: 'happy', fallbackIcon: Icons.sentiment_very_satisfied, free: true),
  cheer(id: 'cheer', fallbackIcon: Icons.celebration, free: true),
  dance(id: 'dance', fallbackIcon: Icons.music_note, free: true),
  bow(id: 'bow', fallbackIcon: Icons.theater_comedy, free: true),
  flex(id: 'flex', fallbackIcon: Icons.fitness_center, fragmentsRequired: _kCelebrationFragments),
  wave(id: 'wave', fallbackIcon: Icons.waving_hand, fragmentsRequired: _kCelebrationFragments),
  spin(id: 'spin', fallbackIcon: Icons.rotate_right, fragmentsRequired: _kCelebrationFragments),
  jump(id: 'jump', fallbackIcon: Icons.arrow_upward, fragmentsRequired: _kCelebrationFragments),
  salute(id: 'salute', fallbackIcon: Icons.military_tech, fragmentsRequired: _kCelebrationFragments),
  shrug(id: 'shrug', fallbackIcon: Icons.help_outline, fragmentsRequired: _kCelebrationFragments),
  facepalm(id: 'facepalm', fallbackIcon: Icons.back_hand, fragmentsRequired: _kCelebrationFragments),
  fistbump(id: 'fistbump', fallbackIcon: Icons.front_hand, fragmentsRequired: _kCelebrationFragments),
  crown(id: 'crown', fallbackIcon: Icons.workspace_premium, fragmentsRequired: _kCelebrationFragments),
  trophy(id: 'trophy', fallbackIcon: Icons.emoji_events, fragmentsRequired: _kCelebrationFragments),
  sparkle(id: 'sparkle', fallbackIcon: Icons.auto_awesome, fragmentsRequired: _kCelebrationFragments),
  rocket(id: 'rocket', fallbackIcon: Icons.rocket_launch, fragmentsRequired: _kCelebrationFragments);

  const Celebration({
    required this.id,
    required this.fallbackIcon,
    this.free = false,
    this.fragmentsRequired,
  }) : assert(
         !(free && fragmentsRequired != null),
         'fragmentsRequired is its own unlock route — it cannot also be free',
       );

  /// Stable, persisted, never shown to players — renaming one orphans a
  /// player's saved selection.
  final String id;

  final IconData fallbackIcon;

  /// Available without unlocking. Every other celebration is fragment-gated
  /// ([fragmentsRequired]) — earned from daily chests, never bought.
  final bool free;

  /// Non-null for a celebration whose only unlock route is collecting this
  /// many fragments from the daily chest (mirrors
  /// `GameSkin.fragmentsRequired` — see `lib/theme/skin.dart`). Null for
  /// every celebration today; the mechanism exists generically across all
  /// three cosmetic catalogs, but nothing currently uses it here.
  final int? fragmentsRequired;

  /// Whether collecting fragments is this celebration's unlock route at all.
  bool get isFragmentGated => fragmentsRequired != null;

  /// Where this celebration's art lives once it exists. Nothing is bundled,
  /// so every entry currently renders its [fallbackIcon].
  String get assetPath => 'assets/celebrations/$id.png';

  /// How many fill one page of the picker's grid (4 across, 3 down).
  static const perBlock = 12;

  /// The first celebration, used when nothing is selected yet.
  static Celebration get defaultChoice => Celebration.happy;
}
