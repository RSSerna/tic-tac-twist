import 'package:flutter/material.dart';

/// Colour tokens from `docs/02-DESIGN-SYSTEM.md` §2.1 (base "turned wood" skin).
///
/// Modelled as a [ThemeExtension] so Phase 8 skins can swap the whole set
/// without touching widgets. Widgets must read colours from here, never
/// hardcode them.
@immutable
class GameColors extends ThemeExtension<GameColors> {
  const GameColors({
    required this.ground,
    required this.surface,
    required this.ink,
    required this.playerA,
    required this.playerB,
    required this.neutral,
  });

  /// App background — putty/limestone grey.
  final Color ground;

  /// Board squares, cards, sheets.
  final Color surface;

  /// Text, outlines, grid structure.
  final Color ink;

  /// Player 1 — deep indigo.
  final Color playerA;

  /// Player 2 — burnt amber.
  final Color playerB;

  /// Drawn boards, disabled states, buried-stack collar.
  final Color neutral;

  /// Legal-move highlight: the active player's own colour at ~15% opacity
  /// (design system §2.1 — no separate highlight token).
  Color highlightFor(Color playerColor) => playerColor.withValues(alpha: 0.15);

  static const GameColors baseSkin = GameColors(
    ground: Color(0xFFDCDAD1),
    surface: Color(0xFFF2F0EA),
    ink: Color(0xFF2E2C29),
    playerA: Color(0xFF1B4B7A),
    playerB: Color(0xFFC9601F),
    neutral: Color(0xFF8A8C84),
  );

  @override
  GameColors copyWith({
    Color? ground,
    Color? surface,
    Color? ink,
    Color? playerA,
    Color? playerB,
    Color? neutral,
  }) {
    return GameColors(
      ground: ground ?? this.ground,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      playerA: playerA ?? this.playerA,
      playerB: playerB ?? this.playerB,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  GameColors lerp(ThemeExtension<GameColors>? other, double t) {
    if (other is! GameColors) return this;
    return GameColors(
      ground: Color.lerp(ground, other.ground, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      playerA: Color.lerp(playerA, other.playerA, t)!,
      playerB: Color.lerp(playerB, other.playerB, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
    );
  }
}

extension GameColorsContext on BuildContext {
  GameColors get gameColors => Theme.of(this).extension<GameColors>()!;
}
