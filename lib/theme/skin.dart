import 'package:meta/meta.dart';

/// How a chip's level is rendered *procedurally*. The concentric-band
/// mechanic itself (design doc §2.3: level = a countable, non-colour marker)
/// never changes between skins — only its geometry does (design doc §2.6:
/// "chip form (rings → dolls, stones, tiles)"). Only meaningful for a
/// [PaintedAppearance]; an [AssetAppearance] ships art instead of geometry.
enum ChipForm { rings, dolls }

/// Everything a skin's asset resolver keys its art on. [level] is null for
/// Ultimate marks (X/O have no stacking level) and 1–4 for stacking chips;
/// [isFirstPerson] picks the per-seat variant (person 1 vs 2 / X vs O).
@immutable
class ChipAssetRequest {
  const ChipAssetRequest({required this.isFirstPerson, this.level});

  final bool isFirstPerson;
  final int? level;
}

/// How a skin's chips and marks are drawn: procedurally with a `CustomPainter`
/// (today's default) or from a bundled image asset (future premium skins that
/// ship art instead of geometry). The render widgets ([ChipView] for stacking
/// chips, the Ultimate board's mark) switch on this, so no call site
/// hard-codes which skin is active — the flag the whole system keys off is
/// just "which subtype is this".
///
/// Gameplay-critical constraints are enforced *outside* this type and apply to
/// both subtypes equally: chip size relationships ([ChipView.sizeFactor]) and
/// the buried-collar/legibility rules (CLAUDE.md) are never a skin's to alter,
/// so an asset skin still renders at the same size a painted one would.
sealed class ChipAppearance {
  const ChipAppearance();
}

/// Drawn procedurally — the rings/dolls chip silhouettes and the X/O marks.
/// [form] is ignored for Ultimate marks (those are always X/O, never
/// rings/dolls) and drives only the stacking-chip silhouette.
@immutable
class PaintedAppearance extends ChipAppearance {
  const PaintedAppearance(this.form);

  final ChipForm form;
}

/// Drawn from a bundled image asset. If the asset is missing or fails to load,
/// the render widgets fall back to painting [fallbackForm] instead — so this
/// flag is safe to ship before any art exists, the same "a missing asset
/// fails gracefully, never blocks play" stance the audio layer takes.
@immutable
class AssetAppearance extends ChipAppearance {
  const AssetAppearance({
    required this.resolve,
    this.fallbackForm = ChipForm.rings,
  });

  /// Resolves the image path for a chip/mark. Called once per render — keep
  /// it cheap (a `switch`/string build, not I/O).
  final String Function(ChipAssetRequest request) resolve;

  /// The procedural form painted if [resolve]'s asset can't be loaded.
  final ChipForm fallbackForm;
}

/// A cosmetic skin (design doc §2.6 / product doc §2.2). Chips, boards, and
/// backgrounds are all in scope per the docs; this phase's one premium skin
/// varies chip form only — palette, board, and background stay the
/// turned-wood defaults (`GameColors.baseSkin`) so as not to redo the Phase 4
/// accessibility/contrast pass for values nothing here actually requires
/// changing yet. The model itself doesn't prevent a future skin from varying
/// those too, nor from shipping image art via an [AssetAppearance].
@immutable
class GameSkin {
  const GameSkin({required this.id, required this.appearance});

  /// Stable identity, persisted in [SkinService] — never shown to players.
  final String id;

  /// How this skin's chips and marks are drawn (painted vs. asset).
  final ChipAppearance appearance;

  /// Free default (design doc §2: "turned wood" direction). Always
  /// unlocked — never stored in [SkinService.unlockedSkinIds].
  static const turnedWood = GameSkin(
    id: 'turned_wood',
    appearance: PaintedAppearance(ChipForm.rings),
  );

  /// The one premium set this phase ships (roadmap Phase 8: "base free set
  /// plus at least one premium set"). Derived from the nesting-doll origin
  /// the design doc calls out by name (§2). Achievement-unlocked this phase
  /// — real purchases are Phase 9. Still painted for now (art assets are a
  /// later drop); flip to an [AssetAppearance] once the doll art ships.
  static const nestingDolls = GameSkin(
    id: 'nesting_dolls',
    appearance: PaintedAppearance(ChipForm.dolls),
  );

  static const values = [turnedWood, nestingDolls];
}

/// The two skins in play at once: a player dresses their own chips
/// independently of their opponent's (the shop sells the X mark and the O
/// mark as separate items).
///
/// Passed down through the board widgets instead of a single
/// [ChipAppearance], because the choice of skin can only be made where the
/// *person* being drawn is known — at the individual chip or mark.
@immutable
class SkinPair {
  const SkinPair({required this.firstPerson, required this.secondPerson});

  final GameSkin firstPerson;
  final GameSkin secondPerson;

  GameSkin skinFor({required bool isFirstPerson}) =>
      isFirstPerson ? firstPerson : secondPerson;

  ChipAppearance appearanceFor({required bool isFirstPerson}) =>
      skinFor(isFirstPerson: isFirstPerson).appearance;

  /// Used while the controller is still loading, so a board never waits on
  /// storage to draw itself.
  static const fallback = SkinPair(
    firstPerson: GameSkin.turnedWood,
    secondPerson: GameSkin.turnedWood,
  );
}
