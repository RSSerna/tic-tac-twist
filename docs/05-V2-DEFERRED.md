# 05 — Deferred to v2

**Do not build from this file.** It exists so v1 doesn't accidentally block these, and so the design work already done isn't lost.

---

## 1. Online multiplayer

Cut from v1 — the app is fully offline (no accounts, no backend, no network permission).

### 1.1 What v1 must do so this isn't a rewrite
These three are already `CLAUDE.md` rules. They're cheap now and expensive later:

1. **Engines are deterministic and serialisable.** State round-trips to JSON; the same move list on a fresh state always reproduces the same position. Online sync then becomes "send the move, replay it locally" rather than syncing whole boards.
2. **Every move routes through `GameController.submitMove()`.** v1 callers are local UI and AI; v2 adds a network listener as a third caller with zero engine changes.
3. **Move validation lives in the engine, not the UI.** In v2, `legalMoves()` re-verifies the remote player's move. **Never trust a move that arrived over the network.**

### 1.2 When built
- Firebase (Firestore or Realtime Database + Cloud Functions for matchmaking) is the fastest path for a solo/small team. A custom WebSocket server offers more control at meaningfully more build time.
- **OPEN:** room-code invites, random matchmaking, or both. Accounts needed?

---

## 2. Ranked mode

- A **mandatory turn timer is effectively required** — without one, an opponent who walks away hangs the match indefinitely. Standard approach: per-move limit plus a per-game reserve, so a player can think hard once or twice without stalling.
- Needs its own design pass: rating system, matchmaking bands, leaver penalties, forfeit handling.
- **Do not partially build this in v1.** The only v1 obligation is keeping timers out of the engines (they stay time-independent).

---

## 3. Mixed mode: Ultimate × Stacking

Design is **locked** — this section is complete enough to build from when the time comes. It's the only mode in the app that isn't an existing published game, so it's the most distinctive thing here and worth doing properly rather than rushing into v1.

### 3.1 Why the obvious approach fails
Porting the 9-chip, 4-level pyramid onto an Ultimate board does not work:
- **Inventory math.** 81 squares vs 9 chips per player. Nothing stretches. Per-board inventories would work but create fiddly bookkeeping across 9 boards.
- **Cognitive load.** Remembering stack contents across 81 cells on a phone is beyond reasonable.

The fix is to stop treating it as "Mode 1 on a bigger board."

### 3.2 The design: two sizes, one scarce resource
Each player has:
- **Unlimited normal chips** — placed as in standard Ultimate.
- **A fixed budget of 6 "gobblers"** for the whole game. A gobbler covers any normal chip on the board, either player's, in any small board.

**Gobblers cannot cover other gobblers. Stacks are therefore never more than one layer deep.**

Why this works:
- *Inventory solved* — no per-board bookkeeping, no running dry across 81 cells.
- *Cognitive load solved* — "what's underneath" is a single yes/no per cell, not a stack history.
- *Scarcity is the strategy* — six board-steals across a ~40-move game makes each one a genuine decision.
- *Send rule untouched* — you still place into a cell, and that cell still dictates the opponent's next board. All standard Ultimate rules carry over unchanged.

**The new tension this creates:** you can break up an opponent's forming line inside a small board right before they claim it. That's the point of the mode.

### 3.3 Additional rules required
1. **Small boards lock permanently the instant they are won.** Once claimed, no further placement (gobbler or otherwise) is possible there, and the claim can never be reversed. Without this the big board never stabilises.
2. A gobbler completing a line wins that small board immediately, same as a normal chip.
3. Win checks inside a small board use the **topmost visible chip**.
4. A gobbler counts as a normal move for the send rule.
5. Gobbler budget is **public information** — both players see remaining counts at all times.
6. Gobbler count (6) is the primary balance lever. Keep it data-driven.

### 3.4 Movable variant — deferred further
Needs one extra restriction: **chips may only be moved within the small board they currently occupy.** Without it, a player can relocate a chip out of any board they're sent to, destroying Ultimate's central constraint. With it, the destination is always inside the board you were sent to, so the send rule stays intact.

Playable, but the heaviest thing in the app. Hold it until the static mixed mode has been tested.

---

## 4. Cosmetics already built ahead of v2

The customisation UI was rebuilt around **categories** rather than a single
skin list, and some of those categories exist for v2 features. Everything
below is **already in the codebase** — v2 wires it to multiplayer rather than
designing it from scratch.

> **Board skins** are the one category with nothing behind it. Its tile keeps its
> own icon with a lock badge, and the shop's `sakura` pack shows a stand-in glyph;
> real board previews arrive with a `BoardSkin` type (one more case in
> `_ShopCard._art`). Not built.

### 4.1 The customisation root

`SkinsScreen` (`lib/ui/screens/skins_screen.dart`) is no longer the chip
picker — it's a category selector titled "Custom". The chip picker moved to
`ChipSkinsScreen`.

Categories live in one enum, each with an `available` flag:

```dart
// lib/ui/screens/skins_screen.dart
enum CustomizationCategory {
  board(available: false),   // no board-skin system yet
  chips(available: true),    // -> ChipSkinsScreen
  emote(available: true),    // -> EmoteSkinsScreen
  flexing(available: true),  // -> CelebrationSkinsScreen
}
```

An unavailable category renders locked and refuses taps. **Adding a system
means flipping its flag and filling in one `switch` arm** — the row's layout
already accounts for all four, so nothing needs re-laying-out when they land.

`board` is the only one still empty: no model, no service, no art. It's a
placeholder for the design, not a half-built feature.

### 4.2 Emotes — sending works locally; the network path is v2

| Piece | File | State |
|---|---|---|
| Catalogue (10 emotes, stable ids, `free` flag) | `lib/theme/emote.dart` | Done |
| Persistence (loadout + purchased ids) | `lib/services/emote_service.dart` | Done |
| Loadout state + rules | `lib/controllers/emote_controller.dart` | Done |
| Picker UI (4 slots + catalogue) | `lib/ui/screens/emote_skins_screen.dart` | Done |
| Rendering (asset with icon fallback) | `lib/ui/widgets/emote_view.dart` | Done |
| **In-match send tray + seat bubbles** | `lib/ui/widgets/match_emotes.dart` | Done |
| **In-match state (display, cooldown)** | `lib/controllers/match_emote_controller.dart` | Done |
| **Sending to a remote opponent** | — | **v2** |
| **Purchase route (`ProductId`s)** | — | Needs store products |

`Emote.loadoutSize` is 4 — the number a player takes into a match. The
controller enforces it, refuses locked emotes, and drops saved ids that no
longer match a catalogue entry (a saved loadout outlives any emote you
retire; there's a test for this).

**What's built, precisely.** In all three modes, a toggle in the staging bar
opens the player's equipped emotes; tapping one shows it in that seat's
bubble above the board for 3s, with a 2s cooldown. The tray belongs to
whoever is to move. **In pass-and-play this is the finished feature** — the
opponent is sitting at the same device and sees it.

**What is a placeholder.** Each seat's bubble is drawn empty when nothing is
showing, in every mode. That empty frame is the reserved place a *received*
emote will appear once there's a network to receive one. Vs the AI, the AI's
bubble never fills: nothing sends to it, and nothing pretends to.

**What v2 must add:** the network path only. A received emote is pushed into
`MatchEmoteController.send` exactly as the local tray does — it's
presentation state, never engine state, so no engine change is involved.

**Never trust a received emote id.** Same rule as moves (§1.1.3): resolve it
against `Emote.values` and drop it if it doesn't match, rather than rendering
whatever arrived.

### 4.3 Celebrations ("flexing") — choosing works now, playing one doesn't

A celebration is what plays when you win. Choosing one is local and works
today; **nothing plays one yet**, because the format isn't decided.

| Piece | File | State |
|---|---|---|
| Catalogue (16 celebrations, stable ids, `free` flag) | `lib/theme/celebration.dart` | Done |
| Persistence (selection + purchased ids) | `lib/services/celebration_service.dart` | Done |
| Selection state + rules | `lib/controllers/celebration_controller.dart` | Done |
| Picker UI (preview + paged grid) | `lib/ui/screens/celebration_skins_screen.dart` | Done |
| **Playing one on a win** | — | **Needs a format decision** |
| **Purchase route (`ProductId`s)** | — | Needs store products |

**The open decision is the format**: a still image, a sprite sequence, or a
video. `Celebration.assetPath` currently points at a single PNG, and the
preview frame renders the same `AssetGlyph` the grid tiles do. A sequence or
a video changes the preview widget and the asset convention — not the
catalogue, the persistence, or the picker.

Two behaviours worth keeping if this is reworked:

- **Locked celebrations can be previewed.** Tapping one shows it in the frame
  without equipping it — that's what the lock indicator in the header is
  reporting on. Only *equipping* is gated.
- **A persisted id that no longer matches the catalogue falls back to the
  default** rather than throwing (there's a test). Same hazard as the emote
  loadout: a saved choice outlives any catalogue change.

This is v1-visible, not v2-only — a player can pick a celebration today, it
just has no moment to play in until wins get a celebration beat. It's listed
here because it was built alongside the v2-facing cosmetics and shares their
shape.

### 4.4 The Online skins tab

`ChipSkinsScreen`'s header has **LOCAL / ONLINE** source pills. `ONLINE` is
rendered but permanently disabled — v1 has no server to fetch skins from
(`CLAUDE.md`: no network). The switch is state (`_source`) that nothing reads
yet.

When v2 adds a backend, this is where a remote catalogue hangs. Note that a
downloaded skin still has to resolve to a `ChipAppearance`, so the transport
is art plus an id, not new render code.

### 4.5 Per-mark skins

`GameSkin` no longer dresses both players at once. `SkinPair` carries one
skin per mark, `SkinState` persists them separately, and the boards resolve
which to draw at the individual chip or mark — the first point that knows
whose it is.

This exists because the shop sells an **X pack** and an **O pack** as
separate items, which is meaningless if one skin dresses both.

For v2: a remote player's mark is drawn with *their* chosen skin, so the
pair has to come from the match, not from local storage. `SkinPair` is
already the unit to send.

### 4.6 Rarity tiers — real for chest odds, not yet a per-cosmetic property

**Built (2026-09):** `Rarity` (`lib/theme/rarity.dart`) is real — every chest
open rolls one of four weighted tiers (Common 60%/Rare 25%/Epic 12%/
Legendary 3%), and `ChipSkinsScreen`/`CelebrationSkinsScreen`'s shared
`RarityLegend` (`lib/ui/widgets/rarity_legend.dart`) shows the actual odds
and fragment amounts, not placeholder text. See `03-PRODUCT.md` §3.2 and
`07-SKINS.md` §6.

**Still deferred:** the roll only ever decides a **fragment-gated**
cosmetic's payout (`GameSkin.fragmentsRequired`, and the matching field on
`Emote`/`Celebration`) — which specific cosmetic drops from a chest is still
**uniform**, not weighted by rarity. No skin, emote or celebration carries
"this one is Epic" as a property of itself; only whether it's fragment-gated
at all. Making a cosmetic's *drop chance* depend on a rarity it's tagged
with — rather than rarity only setting a fragment payout — is the part still
undecided, and would mean reweighting `ChestController._grantOne`'s pool
pick, not just consulting `Rarity.roll`.

---

## 5. Additional languages

v1 ships English and Spanish. The localization scaffolding built in Phase 0 means additional languages are translation files, not a refactor.
