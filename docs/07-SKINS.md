# 07 — SKINS: How to Author a Skin

Developer guide for adding and wiring cosmetic skins. Read this with
`02-DESIGN-SYSTEM.md` §2.6 (the design intent) and `03-PRODUCT.md` §2.2 / §3.1
(how skins are sold and earned). This file is the *how*; those are the *why*.

Everything here is additive: adding a skin never touches engine code, game
rules, or the controller's move path.

---

## 1. Mental model

A skin is a small value object. It decides **how a player's chip (Stacking) or
mark (Ultimate) is drawn** — nothing else. Board colours, backgrounds, and
palette are *not* skinned today (they come from the fixed `GameColors.baseSkin`
theme extension; the design doc allows skinning them later, but the model here
doesn't wire them yet).

Two independent axes:

| Axis | Type | Values |
|---|---|---|
| **Render source** | `ChipAppearance` (sealed) | `PaintedAppearance` (a `CustomPainter`) or `AssetAppearance` (a bundled image) |
| **Painted form** | `ChipForm` (enum) | `rings`, `dolls`, … — only meaningful for `PaintedAppearance` |

A `GameSkin` bundles a stable `id` and one `ChipAppearance`. That's it.

```dart
// lib/theme/skin.dart
class GameSkin {
  const GameSkin({required this.id, required this.appearance});
  final String id;              // persisted; never shown to players
  final ChipAppearance appearance;
}
```

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
- **Level legibility** — level must stay countable at a glance (bands for
  painted; your art must keep four visually distinct levels).
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
| Selection + unlock state (Riverpod) | `lib/controllers/skin_controller.dart` |
| Persistence (SharedPreferences) | `lib/services/skin_service.dart` |
| **Category root** ("Custom": which kind of cosmetic) | `lib/ui/screens/skins_screen.dart` |
| **Chip picker** + names/descriptions + purchase route | `lib/ui/screens/chip_skins_screen.dart` |
| Unlock triggers (achievement / purchase) | `lib/controllers/game_controller.dart`, `lib/controllers/ads_controller.dart` |
| Display strings | `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` |

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

They also share `RarityLegend` (`ui/widgets/rarity_legend.dart`), the static
COMMON/RARE/EPIC/LEGENDARY row at the foot of the chip and celebration
pickers. It's a legend, not a filter — nothing carries a rarity yet.

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

Ultimate marks are always X/O and ignore `form`, so `_MarkPainter` needs no
change. If your form reuses `rings`/`dolls`, skip this step entirely.

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

`resolve` maps a `ChipAssetRequest` to an asset path. `level` is **null for
Ultimate marks** and **1–4 for Stacking chips**; `isFirstPerson` picks the
per-seat art.

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
      ? 'assets/skins/stone_stack/mark_$person.png'          // Ultimate mark
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

2. Add cases to the two switches in `skins_screen.dart` (both keyed by
   `skin.id`):

```dart
String _skinName(AppLocalizations l10n, GameSkin skin) => switch (skin.id) {
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

A skin is one of three access tiers. Pick one.

### Free / always unlocked
Model it like `turnedWood`: `SkinState.isUnlocked` treats
`GameSkin.turnedWood.id` as implicitly unlocked and it's never stored. Only one
free skin is special-cased today; a second free skin would need that check
generalized.

### Achievement-earned
Unlocks fire from `GameController._checkAchievements`. Today, unlocking *any*
achievement unlocks `nestingDolls`:

```dart
if (anyNewlyUnlocked) {
  await ref.read(skinControllerProvider.notifier).unlockSkin(GameSkin.nestingDolls);
}
```

For a new earned skin, add its own trigger there (map specific achievements →
specific skins). With more than one premium skin, replace the single unlock
with a per-achievement mapping — this is exactly the "chests/rarity" seam
`03-PRODUCT.md` §3 defers.

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
    'nesting_dolls' => ProductId.skinNestingDolls,
    'stone_stack'   => ProductId.skinStoneStack,   // add
    _ => null,
  };
}
```

3. Grant the unlock when the purchase stream reports success, in
   `AdsController._onPurchased`:

```dart
case ProductId.skinStoneStack:
  await ref.read(skinControllerProvider.notifier).unlockSkin(GameSkin.stoneStack);
```

The purchase button and lock icon in the picker are already driven by
`_productFor` + `isUnlocked`.

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
      `_skinName`/`_skinDesc`.
- [ ] Choose an unlock tier (free / achievement / purchase) and wire its
      trigger.
- [ ] `flutter analyze`, `flutter test`, and eyeball on device.
