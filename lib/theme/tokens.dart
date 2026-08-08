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

  /// Text, outlines, grid structure. Also the default font colour — the
  /// Material 3 [TextTheme] derives from `colorScheme.onSurface`, which
  /// `buildAppTheme` wires to this token.
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
    ground: Color(0xFFB7B3B2),
    surface: Color(0xFFE3DBD3),
    // Neutral near-black, replacing the doc's warmer #2E2C29. Keeps AA
    // comfortably on both backgrounds (9.62:1 on surface, 6.34:1 on ground).
    ink: Color(0xFF303032),
    playerA: Color(0xFF1B4B7A),
    playerB: Color(0xFFC9601F),
    // Darkened from the doc's original #8A8C84 during the Phase 4
    // accessibility pass: the original failed WCAG AA's 3:1 "meaningful
    // graphics" minimum against both surface (2.99:1) and ground (2.43:1)
    // — this is what the buried-chip collar and drawn-board marker render
    // against. #6B6D65 clears both (4.61:1 / 3.75:1) at the same hue.
    neutral: Color(0xFF6B6D65),
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

/// Drop shadows, tinted from [GameColors.ink] rather than plain black so a
/// skin's palette carries through to its shadows.
///
/// A [ThemeExtension] for the same reason [GameColors] is: widgets must not
/// invent shadow colours, and a skin swapping the palette must not leave
/// black shadows under a warm one.
@immutable
class GameElevations extends ThemeExtension<GameElevations> {
  const GameElevations({required this.resting, required this.raised});

  /// Cards and buttons sitting on the background.
  final List<BoxShadow> resting;

  /// Elements that read as floating above the layout — circular icon
  /// buttons, the home screen's mode pills.
  final List<BoxShadow> raised;

  factory GameElevations.from(GameColors colors) => GameElevations(
    resting: [
      BoxShadow(
        color: colors.ink.withValues(alpha: 0.12),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
    raised: [
      BoxShadow(
        color: colors.ink.withValues(alpha: 0.2),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static List<BoxShadow> _lerpShadows(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) => BoxShadow.lerpList(a, b, t) ?? b;

  @override
  GameElevations copyWith({
    List<BoxShadow>? resting,
    List<BoxShadow>? raised,
  }) => GameElevations(
    resting: resting ?? this.resting,
    raised: raised ?? this.raised,
  );

  @override
  GameElevations lerp(ThemeExtension<GameElevations>? other, double t) {
    if (other is! GameElevations) return this;
    return GameElevations(
      resting: _lerpShadows(resting, other.resting, t),
      raised: _lerpShadows(raised, other.raised, t),
    );
  }
}

extension GameElevationsContext on BuildContext {
  GameElevations get gameElevations =>
      Theme.of(this).extension<GameElevations>()!;
}

/// Animation durations from `docs/02-DESIGN-SYSTEM.md` §4 ("moderate":
/// covering has weight, board claims get a flourish, wins get a line reveal).
///
/// Modelled as a [ThemeExtension], same rationale as [GameColors]: "skins
/// supply their own placement/cover/claim effects" (§4) means the animation
/// layer must be built once and parameterised, not hardcoded per widget.
@immutable
class GameAnimations extends ThemeExtension<GameAnimations> {
  const GameAnimations({
    required this.placement,
    required this.cover,
    required this.boardClaim,
    required this.winLineReveal,
  });

  /// A chip landing on an empty cell.
  final Duration placement;

  /// A chip covering another — the signature moment of the stacking modes,
  /// weightier than a plain placement.
  final Duration cover;

  /// An Ultimate small board resolving to a claim.
  final Duration boardClaim;

  /// Drawing the line through the winning three squares.
  final Duration winLineReveal;

  static const GameAnimations standard = GameAnimations(
    placement: Duration(milliseconds: 160),
    cover: Duration(milliseconds: 260),
    boardClaim: Duration(milliseconds: 320),
    winLineReveal: Duration(milliseconds: 450),
  );

  static Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
    microseconds: (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
        .round(),
  );

  @override
  GameAnimations copyWith({
    Duration? placement,
    Duration? cover,
    Duration? boardClaim,
    Duration? winLineReveal,
  }) {
    return GameAnimations(
      placement: placement ?? this.placement,
      cover: cover ?? this.cover,
      boardClaim: boardClaim ?? this.boardClaim,
      winLineReveal: winLineReveal ?? this.winLineReveal,
    );
  }

  @override
  GameAnimations lerp(ThemeExtension<GameAnimations>? other, double t) {
    if (other is! GameAnimations) return this;
    return GameAnimations(
      placement: _lerpDuration(placement, other.placement, t),
      cover: _lerpDuration(cover, other.cover, t),
      boardClaim: _lerpDuration(boardClaim, other.boardClaim, t),
      winLineReveal: _lerpDuration(winLineReveal, other.winLineReveal, t),
    );
  }
}

extension GameAnimationsContext on BuildContext {
  GameAnimations get gameAnimations =>
      Theme.of(this).extension<GameAnimations>()!;
}
