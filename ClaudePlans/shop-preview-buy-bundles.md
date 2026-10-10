# Shop: preview dialog with Buy, bundle contents, "Owned" marker

## Context
The locked-preview pass (done) made the shop cards show real art, but a card tap only shows a basic preview with a status line — there is no way to buy from it, no way to see what is inside a bundle, and the owned state is only a small corner check. All changes are in `lib/ui/screens/shop_screen.dart` (plus a small extension of `lib/ui/widgets/locked_preview.dart`, l10n, tests, docs).

Decisions from the user: detail **dialog** on card tap; Buy is **disabled "Coming soon"** when a pack has no `ProductId`; `ShopItem` gets a **contents list**; marker means **owned via any route** (no new persistence).

## Approach

### 1. Data: bundle contents
- New sealed/simple value type in `shop_screen.dart`: `ShopContent` wrapping exactly one of `GameSkin` / `Emote` / `Celebration` (with `name(l10n)`, `art(context, size)`, `owned(ref)`), so the dialog and card share one resolver. This replaces the ad-hoc `item.skin/emote/celebration` branching in `_ShopCard._art` and `ShopScreen._owned`.
- `ShopItem` gains `contents: List<ShopContent>`. The existing single `skin`/`emote`/`celebration` fields are kept as the "primary" cosmetic (card art) to avoid churn; when `contents` is empty it is derived from them (one entry), when empty with none → no real contents.
- A pack is a **bundle** when `contents.length > 1`. Bundle owned = every item owned.
- Seed data: `fire`, `burger`, `troll`, `loser` stay single-item. `elements` (combo) becomes a bundle of **placeholder** existing cosmetics (e.g. a skin + `Emote.fire` + `Celebration.crown`) clearly commented as placeholders — the user to correct. `apple`/`sakura` keep empty contents (stand-in art; `sakura` is the board pack).

### 2. Detail dialog (`_ShopItemDialog`, in `shop_screen.dart`)
Replaces the current `showCosmeticPreview` call in `_ShopCard._tap` (both owned and unowned open it):
- Large primary art in `LockedPreview` (reuse; locked or owned badge), pack name, kind label (`_kindLabel`).
- **Bundle**: a horizontal/wrapped row of content thumbnails (each `LockedPreview` badged per its own owned state, with its name). Tapping a thumbnail swaps the large preview art/name to that item (local dialog state only — presentation state). Single-item packs show no list.
- **Footer**: if owned → "Owned" label with check (no button). Else `PillActionButton` Buy:
  - `item.product != null` → enabled, calls the same path as today (`purchaseServiceProvider.buy(product)`; debug shortcut / release "payments unavailable" unchanged — `kDebugMode` gating moved into the dialog's `onBuy`, not duplicated).
  - `item.product == null` → disabled, label "Coming soon" (existing key `categoryComingSoon` reuse if wording fits, else new ARB key en+es).
- Dialog watches `skinControllerProvider`/`emoteControllerProvider`/`celebrationControllerProvider` (Riverpod `Consumer`), so after a purchase the dialog flips to Owned live and the card behind updates.
- Dialog sized for a 320pt phone: scrollable content, thumbnails scroll horizontally, no overflow.
- `showCosmeticPreview` in `locked_preview.dart` is left for the emote screen; shop uses its own dialog because it needs Buy + contents. Share the `LockedPreview` and art helpers only.

### 3. Owned marker on the card
- Keep the corner check badge; add an **"OWNED" pill** across the bottom of the art window (or replacing the name bar tint) using `colors.surface` on `colors.ink`, label from existing `l10n.shopOwned` (uppercased in widget like other caps labels). Bundle cards owned only when every content item is owned; a partly-owned bundle shows "n/m" using a new ARB key (`shopBundleProgress(owned, total)`, en+es). Tokens only, no hardcoded colours.
- Semantics label already includes `shopOwned`; extend with bundle progress.

### 4. Out of scope (documented, not built)
- No new `ProductId`s/store products (per `08-STORE-ITEMS.md`); no purchase-record persistence; no "purchased vs earned" distinction. Add to `08-STORE-ITEMS.md` that only Burger has a product and that other Buy buttons are disabled "Coming soon".

## Files
- `lib/ui/screens/shop_screen.dart` — ShopItem/ShopContent, `_ShopItemDialog`, card marker, tap flow.
- `lib/ui/widgets/locked_preview.dart` — only if a small tweak is needed (e.g. badge size param already exists).
- `lib/l10n/app_en.arb`, `app_es.arb` — `shopComingSoon` (if not reusing `categoryComingSoon`), `shopBundleProgress`, `shopBundleContents` heading; regenerate l10n.
- `test/ui/shop_test.dart` — update the existing tap test; add: dialog shows Buy disabled for a no-product pack; Burger shows enabled Buy; bundle (`elements`) lists its contents and tapping one swaps the preview; owned pack shows Owned marker and no Buy.
- Docs: `docs/02-DESIGN-SYSTEM.md` §10 (shop screen: dialog, bundle list, owned marker), `docs/08-STORE-ITEMS.md` (contents list, Buy states, placeholder bundle contents), `docs/09-DECISIONS-LOG.md` (owned-by-any-route marker, disabled Buy until a ProductId exists, why dialog over page).

## Reuse
`LockedPreview` (`lib/ui/widgets/locked_preview.dart`), `ChipView`, `EmoteView`, `AssetGlyph`, `PillActionButton`, `purchaseServiceProvider`, `skinName`/`emoteName`/`celebrationName` helpers, existing `_art`/`_owned` logic (moved into `ShopContent`), `l10n.shopOwned`/`shopPaymentsUnavailable`.

## Verification
- `flutter analyze` clean; `flutter test` (shop_test + related UI tests).
- Run in simulator: open Shop → tap Burger (Buy enabled; in debug it grants and the dialog/card flip to Owned), Fire/Troll/Loser (Buy disabled "Coming soon"), Elements (bundle thumbnails, tap to preview each, partial ownership count), Apple/Sakura (stand-in art). Check a 320pt-wide portrait and a landscape tablet size for dialog overflow, plus Spanish strings.
