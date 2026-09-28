# 07 — SKINS: How to Author a Skin

Developer guide for adding and wiring cosmetic skins. Read this with
`02-DESIGN-SYSTEM.md` §2.6 (the design intent) and `03-PRODUCT.md` §2.2 / §3.1
(how skins are sold and earned). This file is the *how*; those are the *why*.

Everything here is additive: adding a skin never touches engine code, game
rules, or the controller's move path.

---

## 1. Mental model

A skin is a small value object. It decides **how a player's chip (Stacking) or
mark (Ultimate) is drawn** — nothing else.

**Two are in play at once.** Each mark carries its own skin (`SkinPair`), so
player 1's chips and player 2's chips can differ; the shop sells them as
separate packs. Board widgets take the pair and call
`appearanceFor(isFirstPerson:)` at the chip or mark, because that's the first
point in the tree that knows whose it is. Never resolve a skin higher up —
you'd draw both players with one. Board colours, backgrounds, and
palette are *not* skinned today (they come from the fixed `GameColors.baseSkin`
theme extension; the design doc allows skinning them later, but the model here
doesn't wire them yet).

Two independent axes:

| Axis | Type | Values |
|---|---|---|
| **Render source** | `ChipAppearance` (sealed) | `PaintedAppearance` (a `CustomPainter`) or `AssetAppearance` (a bundled image) |
| **Painted form** | `ChipForm` (enum) | `rings`, `dolls`, `marks`, … — only meaningful for `PaintedAppearance` |

A `GameSkin` bundles a stable `id` and one `ChipAppearance`. That's it.

```dart
// lib/theme/skin.dart
class GameSkin {
  const GameSkin({required this.id, required this.appearance, this.free = false});
  final String id;              // persisted; never shown to players
  final ChipAppearance appearance;
  final bool free;              // available without unlocking
}
```

**`free` decides availability, not identity.** It used to be a hardcoded
"is this `turnedWood`?" check in three places; that stopped being the right
question the moment a second free skin existed. `SkinState.isUnlocked` reads
the flag, and `ChestController` never puts a free skin in the reward pool.

### The painted-vs-asset flag

`ChipAppearance` *is* the flag. The render widgets `switch` on its subtype:

- `PaintedAppearance(form)` → draw procedurally (`_ChipPainter` for chips,
  `_MarkPainter` for Ultimate X/O marks).
- `AssetAppearance(resolve, fallbackForm)` → blit `Image.asset(resolve(...))`,
  and if the image is missing/broken, **fall back to painting** `fallbackForm`.

Both surfaces honour it: `ChipView` (Stacking chips) and `_UltimateMark`
(Ultimate move marks), both in `lib/ui/widgets/`.

### Non-negotiable invariants (CLAUDE.md)

A skin may change *appearance only*. It must never change:

- **Chip size relationships** — `ChipView.sizeFactor(level)` is applied
  *outside* the appearance switch, so an asset chip is sized identically to a
  painted one. Do not resize art to "look bigger"; the L1…L4 size ladder is
  gameplay-critical.
- **Level legibility** — level must stay readable at a glance, and it must
  come from **at least two** of: the size ladder, a band/element count, and
  the level numeral (`ChipView.showLevel`, design system §2.3).

  Bands are the usual answer, but they are not the only one. `ChipForm.marks`
  — the classic X and O — has no bands at all: it leans on size plus the
  numeral. That's the exception that made the numeral necessary, and it's why
  the numeral is not optional decoration. If you add a glyph-style form, say
  so in its doc comment, as `GameSkin.classicMarks` does.
- **The buried-collar rule** — never reveal what's under a chip. Skins don't
  touch the collar; don't add art that implies buried contents.

If a change would alter any of those, it's not a skin.

---

## 2. File map

| Concern | File |
|---|---|
| The model (`GameSkin`, `ChipAppearance`, `ChipForm`, `ChipAssetRequest`) | `lib/theme/skin.dart` |
| Painted chip silhouettes | `lib/ui/widgets/chip_view.dart` (`_ChipPainter`) |
| Painted Ultimate marks (X/O) | `lib/ui/widgets/ultimate_board.dart` (`_MarkPainter`, `_UltimateMark`) |
| Which chip variant dresses an Ultimate mark | `GameSkin.variesByLevel`, `SkinPair.ultimateLevelFor`, `SkinController.setUltimateMarkLevel` |
| Selection + unlock state (Riverpod) | `lib/controllers/skin_controller.dart` |
| Persistence (SharedPreferences) | `lib/services/skin_service.dart` |
| **Category root** ("Custom": which kind of cosmetic) | `lib/ui/screens/skins_screen.dart` |
| **Chip picker** + names/descriptions + purchase route | `lib/ui/screens/chip_skins_screen.dart` |
| Unlock triggers (achievement / purchase) | `lib/controllers/game_controller.dart`, `lib/controllers/monetization_controller.dart` |
| Display strings | `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` |
| **Sending an emote in a match** (tray + seat bubbles) | `lib/ui/widgets/match_emotes.dart`, `lib/controllers/match_emote_controller.dart` |
| **Rarity tiers + odds** (fourth unlock route: fragments) | `lib/theme/rarity.dart` |
| **Chest-opening reveal** (fragment outcomes only) | `lib/controllers/chest_reveal_controller.dart`, `lib/ui/screens/chest_reveal_sheet.dart` |

---

## 2a. Cosmetics are no longer just chip skins

`SkinsScreen` is the **category root**, not the chip picker. It lists
`CustomizationCategory` — board, chips, emote, flexing — and routes to a
screen per category. Two are live:

| Category | Screen | Model |
|---|---|---|
| `chips` | `ChipSkinsScreen` | `GameSkin` (`lib/theme/skin.dart`) |
| `emote` | `EmoteSkinsScreen` | `Emote` (`lib/theme/emote.dart`) |
| `flexing` | `CelebrationSkinsScreen` | `Celebration` (`lib/theme/celebration.dart`) |
| `board` | — (locked) | none yet |

**Each is a separate model, deliberately.** A skin decides how one thing is
*drawn*; an emote is something a player *equips and sends*; a celebration is
something that *plays on a win*. They share nothing but the "cosmetic,
unlockable, purchasable" shape, so they get parallel — not shared —
model/service/controller trios:

```
Emote (theme/emote.dart)
  -> EmoteService (services/emote_service.dart)           persists loadout + unlocks
  -> EmoteController (controllers/emote_controller.dart)  enforces the rules
  -> EmoteView (ui/widgets/emote_view.dart)               asset, icon fallback

Celebration (theme/celebration.dart)
  -> CelebrationService / CelebrationController           persists one selection
  -> AssetGlyph (ui/widgets/asset_glyph.dart)             asset, icon fallback
```

What they *do* share is rendering: `AssetGlyph` is the single place that
draws a bundled image and degrades to an icon when the art isn't there.
`EmoteView` is a thin wrapper over it. Anything else that ships before its
art should use it rather than repeating the `errorBuilder`.

They also share `RarityLegend` (`ui/widgets/rarity_legend.dart`), the
COMMON/RARE/EPIC/LEGENDARY row at the foot of the chip and celebration
pickers. **It's real now** (decisions log, 2026-09): `Rarity` is a chest's
independent per-open roll (`lib/theme/rarity.dart`), and the legend shows the
actual published odds and fragment amounts `ChestController._grantOne` uses.
It still doesn't *filter* which cosmetic the pool picks — every locked
cosmetic is equally likely regardless of rarity — only how many fragments a
fragment-gated pick is worth.

See `05-V2-DEFERRED.md` §4 for what's built vs. what's still open.

### Adding an emote

Three steps, no code beyond them:

1. Add an entry to the `Emote` enum with a **stable `id`** (it is persisted —
   renaming one orphans a player's saved loadout), a `fallbackIcon`, and
   `free: true` if it should need no unlock.
2. Add `emoteName<Name>` to both ARBs and a case to `emoteName()` in
   `emote_skins_screen.dart`. The switch is exhaustive, so the analyzer will
   point at it.
3. Optionally drop art at `assets/emotes/<id>.png`.

### Adding a celebration

Identical shape: an entry in the `Celebration` enum, a `celebrationName<Name>`
string in both ARBs plus a case in `celebrationName()`, and optionally art at
`assets/celebrations/<id>.png`.

Two things specific to celebrations:

- **The grid pages in blocks of `Celebration.perBlock` (12).** Adding a 13th
  celebration creates a second block automatically; no layout change needed.
- **The playback format is undecided** — still, sequence or video. The picker
  and persistence don't depend on it; only the preview frame and the asset
  convention would change. See `05-V2-DEFERRED.md` §4.3.

**No emote or celebration art is bundled yet.** Neither `assets/emotes/` nor
`assets/celebrations/` is declared in `pubspec.yaml` — declaring a directory
with no files fails the build. Every entry currently renders its
`fallbackIcon` through `AssetGlyph`, the same degrade-to-something convention
`ChipView` uses for asset skins. When real art arrives, add the files *and*
the pubspec entry together.

---

## 2b. Ultimate marks: which chip does a levelled skin wear?

Ultimate has no chip levels — every mark is the same rank — so a skin whose
art changes per level has no natural mark to draw there. It wears one of its
four chips, and the player says which.

- **The default is the L4 chip** (`kDefaultUltimateMarkLevel`). Ultimate's
  cells are small — 81 of them on the unzoomed board — and L4 is the boldest
  silhouette a skin has, so it's the one that survives that scale.
- **The picker offers the four chips and nothing else.** There is deliberately
  no "classic X/O" entry: the classic mark is what a *glyph* skin gives you,
  and it's reachable by wearing one (Classic is free). Listing it here too
  would offer the same thing by two routes, and let a player select a skin
  that then never appears on the Ultimate board.
- A glyph skin (`ChipForm.marks`) has no variants to choose between, so
  `SkinPair.ultimateLevelFor` returns null for it and `_MarkPainter` draws the
  X/O. Its picker is absent for the same reason — there's nothing to pick.
- The choice is **per mark** (`firstPersonUltimateLevel` /
  `secondPersonUltimateLevel`), like the skin itself — the X mark and the O
  mark are separate items. It **carries across a skin change untouched**:
  every levelled skin has all four chips, so a choice made on one is
  meaningful on the next, and a glyph skin in between simply ignores it.
- Offered on `ChipSkinsScreen`, under the Select/Selected action, only when
  the focused skin is **the one currently worn for that mark** and
  `GameSkin.variesByLevel` is true.
- Persisted under `nested_game.skin.ultimate_level[.p2]`; anything outside
  1–4 reads back as unset, so a level retired by a future change to the chip
  ladder degrades to the default rather than crashing.
- **A claimed small board is stamped with the winner's own mark**, not a bare
  X/O — the same `_UltimateMark` their moves use, at 0.7 of the board. Whoever
  claimed it owns it, and the stamp is the loudest place on the board to say
  whose it is. A **drawn** board keeps the neutral filled disc: it belongs to
  nobody, so it wears nobody's skin, and that's also what keeps claimed and
  drawn distinguishable by symbol rather than colour (design system §6).
- Rendering: `_UltimateMark` draws the chosen chip through `ChipView` with
  `fillsCell: true` — Ultimate has no size ladder to sit in, so the chip
  fills its cell instead of shrinking to L1's share of one. **`fillsCell` is
  for Ultimate only**; the ladder is gameplay-critical anywhere levels
  coexist (CLAUDE.md). No level numeral is drawn either — it would state a
  level this board doesn't have.

## 3. Recipe A — a painted skin (fastest)

Use this when the new look can be drawn procedurally.

### A1. If it needs a genuinely new shape, add a `ChipForm`

`ChipForm` currently has `rings` and `dolls`. To add e.g. `stones`:

1. Add the value in `lib/theme/skin.dart`: `enum ChipForm { rings, dolls, stones }`.
2. Add its silhouette in `chip_view.dart` → `_ChipPainter._silhouetteAt`'s
   `switch` (the compiler forces this — the switch is exhaustive):

```dart
Path _silhouetteAt(Offset center, double radius) => switch (form) {
      ChipForm.rings  => _ringSilhouette(center, radius),
      ChipForm.dolls  => _dollSilhouette(center, radius),
      ChipForm.stones => _stoneSilhouette(center, radius),   // add this
    };
```

Your form shows up on the Ultimate board too — a levelled skin wears one of
its own chips as its mark (default L4, see **§2b**), so `_MarkPainter` needs
no change; only a glyph form reaches it. If your form reuses `rings`/`dolls`,
skip this step entirely.

`ChipForm.shards` (`GameSkin.fragmentShard`, `_shardSilhouette` in
`chip_view.dart`) is a real instance of this recipe, not the hypothetical
`stones` above — a 6-point faceted silhouette, asymmetric about the vertical
axis the same way `_dollSilhouette` is, feeding the same concentric-band
level loop with zero other changes needed.

### A2. Declare the skin

In `lib/theme/skin.dart`:

```dart
static const stoneStack = GameSkin(
  id: 'stone_stack',
  appearance: PaintedAppearance(ChipForm.stones),
);

static const values = [turnedWood, nestingDolls, stoneStack]; // add to the list
```

Then do the shared wiring in **§5 (naming)** and **§6 (unlocking)**.

---

## 4. Recipe B — an asset-backed skin (images)

Use this when the skin ships real art instead of geometry.

### B1. Lay out the art

Convention (mirror it for consistency):

```
assets/skins/<skin_id>/
  chip_p1_l1.png … chip_p1_l4.png   # person 1, levels 1–4  (Stacking)
  chip_p2_l1.png … chip_p2_l4.png   # person 2, levels 1–4
  mark_p1.png                       # person 1 mark          (Ultimate)
  mark_p2.png                       # person 2 mark
```

Art should be square, transparent PNG (or WebP), and rendered with
`BoxFit.contain` — so keep the meaningful shape centred with a little padding.
Provide four visually distinct levels (see the legibility invariant, §1).

**Per-mark art is the default, not a requirement.** `GameSkin.burgerStack`
(`lib/theme/skin.dart`) ships only `assets/chips/burguer1.png` …
`burguer4.png` — one photo per level, no `_p1`/`_p2` split — because both
marks are meant to look identical when a player wears it. `resolve` simply
ignores `ChipAssetRequest.isFirstPerson` in that case. Split by person only
when the art is actually meant to differ.

### B2. Register the folder in `pubspec.yaml`

There is **no `assets:` section yet** — add one under `flutter:`:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/skins/stone_stack/
```

A trailing-slash entry bundles every file in the folder. Run
`flutter pub get` after editing.

### B3. Write the `resolve` function and declare the skin

`resolve` maps a `ChipAssetRequest` to an asset path. `level` is **always
1–4** in practice: Stacking chips carry their own, and an Ultimate mark
carries whichever chip the player picked (§2b — an asset skin always counts
as varying by level). The nullable `level` remains for a future skin that
declares itself levelless; a skin that wants one dedicated mark image can
return the same path for every level.

`GameSkin` is `const`, so `resolve` **must be a `static` or top-level function**
(a tear-off is a constant expression) — not a closure, which would force the
skin to be non-`const` and break `static const`.

```dart
// lib/theme/skin.dart
static const stoneStack = GameSkin(
  id: 'stone_stack',
  appearance: AssetAppearance(
    resolve: _stoneStackAsset,
    fallbackForm: ChipForm.rings, // painted if an image fails to load
  ),
);

static String _stoneStackAsset(ChipAssetRequest r) {
  final person = r.isFirstPerson ? 'p1' : 'p2';
  return r.level == null
      ? 'assets/skins/stone_stack/mark_$person.png'          // levelless mark
      : 'assets/skins/stone_stack/chip_${person}_l${r.level}.png'; // chip
}
```

### B4. Fallback behaviour (already handled)

If any path 404s / fails to decode, `Image.asset`'s `errorBuilder` paints the
equivalent procedural chip/mark using `fallbackForm`. This means you can ship
the skin *before* the art exists and it degrades gracefully — same "a missing
asset never breaks play" stance as the audio layer. It also means: **if your
chips render as plain rings, your paths are wrong** — check the console for the
asset-load error.

Then do §5 and §6.

---

## 5. Naming & localization (both recipes)

Names/descriptions are localized and keyed by `skin.id`.

1. Add strings to **both** ARB files (`app_en.arb` and `app_es.arb`):

```json
"skinStoneStackName": "Stone Stack",
"skinStoneStackDesc": "Chips carved from river stones."
```

2. Add cases to the two switches in `chip_skins_screen.dart` (both keyed by
   `skin.id`):

```dart
String skinName(AppLocalizations l10n, GameSkin skin) => switch (skin.id) {
      'turned_wood'   => l10n.skinTurnedWoodName,
      'nesting_dolls' => l10n.skinNestingDollsName,
      'stone_stack'   => l10n.skinStoneStackName,   // add
      _ => skin.id,
    };
// …same for _skinDesc
```

Run `flutter gen-l10n` (or just build — `generate: true` regenerates on build).
The picker already iterates `GameSkin.values`, so the card appears automatically
once the skin is in that list.

---

## 6. Unlocking (both recipes)

A skin is one of four access tiers. **Pick exactly one** — every skin today
has a single route: Turned Wood and Classic are free, Nesting Dolls is
achievement-only, Burger Stack is purchase-only, Fragment Shard is
fragment-gated. (The model doesn't forbid combining, but nothing combines
today, and `free`/`purchaseOnly` each `assert` against `fragmentsRequired`.)

### Free / always unlocked
Model it like `turnedWood`: `SkinState.isUnlocked` treats
`GameSkin.turnedWood.id` as implicitly unlocked and it's never stored. Only one
free skin is special-cased today; a second free skin would need that check
generalized.

### Achievement-earned
Unlocks fire from `GameController._checkAchievements`. Today, unlocking *any*
achievement unlocks `nestingDolls`, which is **achievement-only** (no store
product, never in a chest):

```dart
if (anyNewlyUnlocked) {
  await ref.read(skinControllerProvider.notifier).unlockSkin(GameSkin.nestingDolls);
}
```

For a new earned skin, add its own trigger there (map specific achievements →
specific skins). With more than one premium skin, replace the single unlock
with a per-achievement mapping.

### Direct purchase (IAP)
1. Add a `ProductId` in `lib/services/purchase_service.dart` and create the
   matching product in App Store Connect + Play Console (IAP has no universal
   test ID; see the Phase 9 note in `CLAUDE.md`).
2. Map the skin → product in `chip_skins_screen.dart`'s `_productFor` (returns
   `null` on web — `in_app_purchase` is mobile-only):

```dart
ProductId? _productFor(GameSkin skin) {
  if (kIsWeb) return null;
  return switch (skin.id) {
    'burger_stack' => ProductId.skinBurgerStack,
    'stone_stack'  => ProductId.skinStoneStack,   // add
    _ => null,
  };
}
```

3. Grant the unlock when the purchase stream reports success, in
   `MonetizationController._onPurchased`:

```dart
case ProductId.skinStoneStack:
  await ref.read(skinControllerProvider.notifier).unlockSkin(GameSkin.stoneStack);
```

The purchase button and lock icon in the picker are already driven by
`_productFor` + `isUnlocked`.

**If this skin should never be earned for free**, set `purchaseOnly: true` on
the `GameSkin` (`GameSkin.burgerStack` is the one skin sold this way).
Chests only ever grant fragments toward *fragment-gated* cosmetics, so a
purchase-only skin is never in a chest's pool regardless; the flag is what
documents the intent and `assert`s it can't also be fragment-gated.

### Fragment-gated (chest-only)

Set `fragmentsRequired: <n>` on the `GameSkin` (`GameSkin.fragmentShard` is
the first: 100). The mechanism is generic across all three cosmetic catalogs
— `Emote` and `Celebration` carry the same field. Today it is the **only**
route to: Fragment Shard (100), the six locked emotes (20 each) and the twelve
locked celebrations (30 each). The emote/celebration amounts are placeholders
(`_kEmoteFragments`, `_kCelebrationFragments`) — tune them in
`emote.dart`/`celebration.dart`.

- **What happens**: a chest **only ever grants fragments** (decisions log,
  2026-09-27). `ChestController._grantOne` picks one cosmetic uniformly from
  every *fragment-gated* cosmetic the player doesn't own yet, independently
  rolls a `Rarity` (`lib/theme/rarity.dart`), and adds `rarity.fragments`
  toward the pick (a `SkinFragmentReward`/`EmoteFragmentReward`/
  `CelebrationFragmentReward`). Cosmetics on any other route — free,
  achievement-only, purchase-only — are never in the pool, and a chest never
  unlocks anything outright except by crossing a fragment threshold.
  **Fragments are per item**, not a shared currency: each chest's fragments
  go to whichever single item was picked, so progress is spread across the
  whole pool (see the pacing note in the decisions log).
- **Granting fragments**: `SkinController.addFragments(skin, amount)` (and the
  `Emote`/`Celebration` controllers' equivalents) persists the running total
  and calls the ordinary `unlockSkin`/`unlock` itself once the total reaches
  `fragmentsRequired` — the unlock-writing code path is never duplicated.
- **Never mixes with `free` or `purchaseOnly`** on the same item — the
  constructors `assert` it. Nothing has a fragment route *and* an achievement
  or purchase route today.
- **Progress UI**: each picker shows `l10n.skinFragmentProgress(current,
  required)` in place of the ordinary locked state once
  `skin.isFragmentGated` — see `_FocusedSkinActions` in
  `chip_skins_screen.dart`, `_CatalogueTile` in `emote_skins_screen.dart`, and
  `_PreviewAction` in `celebration_skins_screen.dart`.
- **The reveal**: a cycling Common→Legendary reveal (`ChestRevealController`
  + `ChestRevealSheet`, `lib/controllers/chest_reveal_controller.dart` /
  `lib/ui/screens/chest_reveal_sheet.dart`) plays on **every** chest claim
  (every claim is a fragment grant). Triggered from `shop_screen.dart`'s
  `_ClaimBar._claim`; skipped in favour of an equivalent snackbar under
  reduced motion. A claim with nothing left to grant (every fragment-gated
  cosmetic already unlocked) shows a plain "everything unlocked" snackbar.

---

## 7. Selection & persistence (no code needed)

Handled for you once the skin is in `GameSkin.values`:

- `SkinController.selectSkin` gates on `isUnlocked` (the controller is the real
  gate, not just the UI) and writes the choice via `SkinService`.
- `SharedPreferencesSkinService` persists the selected id
  (`nested_game.skin.selected`) and the unlocked-id set
  (`nested_game.skin.unlocked`). The free default is never stored.
- Every render surface reads
  `ref.watch(skinControllerProvider).value?.selectedSkin.appearance`, falling
  back to `PaintedAppearance(ChipForm.rings)` before load — so a newly selected
  skin repaints the board immediately.

---

## 8. What is and isn't skinnable

| Surface | Skinnable? | Where |
|---|---|---|
| Stacking chips | ✅ painted or asset | `ChipView` |
| Ultimate move marks (a player's X/O) | ✅ painted or asset | `_UltimateMark` |
| Ultimate board-claim glyph / drawn disc | ❌ painted only | `_SmallBoard` (board *outcome*, not a move — "drawn" has no person/asset) |
| Board colours, background, palette | ❌ not wired to skins | `GameColors.baseSkin` |
| Buried-collar dots, highlight, staging ghost | ❌ never | gameplay-critical |

Extending the claim glyph to assets is possible but out of scope by default —
it's an outcome indicator, not the placed token.

---

## 9. Testing checklist

- `flutter analyze` clean (a new `ChipForm` value will fail to compile until the
  `_silhouetteAt` switch handles it — that's the safety net working).
- `flutter test` — `test/ui/skins_test.dart` covers select/unlock/persist; the
  Ultimate flow test asserts a committed mark renders at real cell size (the
  regression guard against zero-size marks). Assert **rendered size**, never
  just widget presence — a zero-size painter still exists in the tree.
- For an asset skin: run on a real device/browser and confirm the art loads
  (rings showing instead of your art = wrong path; check the console).
- `flutter build web` — asset skins load fine on web; the whole board must never
  regress to blank.

---

## 10. Quick checklist

Adding a skin, end to end:

- [ ] Declare `GameSkin` in `skin.dart`; add to `GameSkin.values`.
- [ ] Painted new shape? Extend `ChipForm` + `_silhouetteAt`.
- [ ] Asset? Add art, register the folder in `pubspec.yaml`, write a `static`
      `resolve`, set a sensible `fallbackForm`.
- [ ] Add name/description to `app_en.arb` **and** `app_es.arb`; add cases to
      `skinName`/`_skinDesc`.
- [ ] Choose an unlock tier (free / achievement / purchase / fragment-gated,
      §6) and wire its trigger. Fragment-gated needs no trigger to wire — just
      set `fragmentsRequired`; `ChestController` and the picker screens pick
      it up generically.
- [ ] `flutter analyze`, `flutter test`, and eyeball on device.
