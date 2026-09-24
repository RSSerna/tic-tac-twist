import 'package:meta/meta.dart';

/// How a chip's level is rendered *procedurally*. The concentric-band
/// mechanic itself (design doc §2.3: level = a countable, non-colour marker)
/// never changes between skins — only its geometry does (design doc §2.6:
/// "chip form (rings → dolls, stones, tiles)"). Only meaningful for a
/// [PaintedAppearance]; an [AssetAppearance] ships art instead of geometry.
enum ChipForm { rings, dolls, marks }

/// The chip a levelled skin wears on the Ultimate board until the player
/// says otherwise. The largest chip: Ultimate's cells are small (81 of them
/// on the unzoomed board), and L4 is the boldest silhouette the skin has —
/// the one that survives that scale.
const kDefaultUltimateMarkLevel = 4;

/// Everything a skin's asset resolver keys its art on. [level] is 1–4 for
/// stacking chips, and null for an Ultimate mark left as the classic X/O —
/// a player who picks a chip variant for their mark (see
/// [SkinPair.ultimateLevelFor]) gets that level here instead.
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
/// [form] drives the stacking-chip silhouette. On the Ultimate board it
/// applies only once the player has picked a chip variant for their mark
/// ([SkinPair.ultimateLevelFor]); until then the mark is the classic X/O.
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
  const GameSkin({
    required this.id,
    required this.appearance,
    this.free = false,
    this.purchaseOnly = false,
  });

  /// Stable identity, persisted in [SkinService] — never shown to players.
  final String id;

  /// How this skin's chips and marks are drawn (painted vs. asset).
  final ChipAppearance appearance;

  /// Available without unlocking. Replaces the old "is it turnedWood?"
  /// check, which stopped being the right question the moment a second free
  /// skin existed.
  final bool free;

  /// True for a skin sold only for real money — it never enters the
  /// achievement-unlock path or the daily chest's random reward pool
  /// (`ChestController._grantOne` checks this flag). `free` and
  /// `purchaseOnly` are independent axes; a free skin is trivially never
  /// purchase-only.
  final bool purchaseOnly;

  /// Whether this skin looks different at each of the four chip levels.
  ///
  /// Ultimate has no levels, so a skin that varies by one has to be told
  /// *which* variant to use as a mark. A glyph skin ([ChipForm.marks]) draws
  /// the same thing at every level, so there is nothing to choose.
  bool get variesByLevel => switch (appearance) {
    PaintedAppearance(:final form) => form != ChipForm.marks,
    // An asset resolver is handed the level, so it may well vary by it.
    AssetAppearance() => true,
  };

  /// Free default (design doc §2: "turned wood" direction). Always
  /// unlocked — never stored in [SkinService.unlockedSkinIds].
  static const turnedWood = GameSkin(
    id: 'turned_wood',
    appearance: PaintedAppearance(ChipForm.rings),
    free: true,
  );

  /// The classic tic-tac-toe glyphs: an X for player 1, an O for player 2.
  ///
  /// **This is the one form that carries no band count.** A glyph has no
  /// rings to count, so level is legible from the size ladder and the level
  /// numeral (`ChipView.showLevel`, design system §2.3) rather than from
  /// bands — which is why the numeral exists. Free, because it's the shape
  /// everyone already expects from the game and shouldn't be behind a wall.
  static const classicMarks = GameSkin(
    id: 'classic_marks',
    appearance: PaintedAppearance(ChipForm.marks),
    free: true,
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

  /// The first asset-backed skin to ship real art (07-SKINS.md Recipe B):
  /// four photographed burger stages, one per chip level, instead of a
  /// procedural silhouette. **Only one image per level exists** — there is
  /// no separate first-/second-person variant the way Recipe B's convention
  /// suggests, so [_burgerStackAsset] ignores [ChipAssetRequest.isFirstPerson]
  /// and both marks share the same art when this skin is worn. Level
  /// legibility (§1's invariant) comes from the photos themselves: patty
  /// count and toppings grow with the level, standing in for the usual band
  /// count, stacked on top of the ordinary size ladder.
  ///
  /// `purchaseOnly: true` — direct purchase is its only unlock route; it is
  /// never granted by an achievement or the daily chest (decisions log,
  /// 2026-09).
  static const burgerStack = GameSkin(
    id: 'burger_stack',
    appearance: AssetAppearance(
      resolve: _burgerStackAsset,
      fallbackForm: ChipForm.rings,
    ),
    purchaseOnly: true,
  );

  static String _burgerStackAsset(ChipAssetRequest r) =>
      'assets/chips/burguer${r.level ?? kDefaultUltimateMarkLevel}.png';

  static const values = [turnedWood, classicMarks, nestingDolls, burgerStack];
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
  const SkinPair({
    required this.firstPerson,
    required this.secondPerson,
    this.firstPersonUltimateLevel,
    this.secondPersonUltimateLevel,
  });

  final GameSkin firstPerson;
  final GameSkin secondPerson;

  /// The chip level the player picked for this mark in Ultimate, or null if
  /// they never picked one. Read [ultimateLevelFor] rather than these —
  /// null means "the default", not "no chip".
  final int? firstPersonUltimateLevel;
  final int? secondPersonUltimateLevel;

  /// Which chip level dresses this mark on the Ultimate board, or null if
  /// this skin has no chip to wear there and paints the classic X/O instead.
  ///
  /// A skin whose art varies by level ([GameSkin.variesByLevel]) always shows
  /// one of its chips — Ultimate has no levels of its own, so it wears
  /// [kDefaultUltimateMarkLevel] until the player picks another. A glyph skin
  /// ([ChipForm.marks]) has no variants to choose between and is already the
  /// classic mark, so it returns null and the X/O painter draws it.
  int? ultimateLevelFor({required bool isFirstPerson}) {
    if (!skinFor(isFirstPerson: isFirstPerson).variesByLevel) return null;
    return (isFirstPerson
            ? firstPersonUltimateLevel
            : secondPersonUltimateLevel) ??
        kDefaultUltimateMarkLevel;
  }

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
