# 02 — Design System & UX

## 1. Platform targets

Flutter, one codebase: **phones, tablets, web.**

- **Phones** — primary. All defaults assume phone constraints.
- **Tablets** — same layouts with breakpoints. Don't stretch phone layouts; let boards grow to a sensible maximum with margin. The full Ultimate board fits comfortably, so zoom becomes optional there.
- **Web** — secondary, **Phase 10, after mobile ships.** See §9.

Both orientations, auto-rotate. Game state must survive rotation (state lives in the controller, not the widget).

---

## 2. Base visual style (free skin)

The default skin must look finished on its own. If the free skin looks like a placeholder, paid skins read as fixing a problem rather than adding delight.

**Direction: turned wood, seen from above.** Not wood texture — the *geometry* of a lathe. Concentric rings, precise circles, flat colour. Derived from the nesting-doll origin without committing to matryoshka faces, so a doll pack stays available as a paid skin.

### 2.1 Palette

| Token | Hex | Use |
|---|---|---|
| `ground` | `#DCDAD1` | App background — putty/limestone grey |
| `surface` | `#F2F0EA` | Board squares, cards, sheets |
| `ink` | `#303032` | Text, outlines, grid structure. Also the default font colour |
| `playerA` | `#1B4B7A` | Player 1 — deep indigo |
| `playerB` | `#C9601F` | Player 2 — burnt amber |
| `neutral` | `#6B6D65` | Drawn boards, disabled states, buried-stack collar |

Indigo/amber survives all three common colour-vision deficiencies, unlike red/green, and stays legible on both `ground` and `surface`.

**`neutral` was darkened from an original `#8A8C84`** during the Phase 4 accessibility pass (2026-07-20): the original failed WCAG AA's 3:1 "meaningful graphics" minimum against both `surface` (2.99:1) and `ground` (2.43:1) — the two backgrounds the buried-chip collar and drawn-board marker render against. `#6B6D65` clears both (4.61:1 / 3.75:1) at the same hue.

**Highlighting uses the active player's own colour at ~15% opacity** — no seventh token. The highlight then tells you *whose* turn it is as well as *where* you may play.

**`ink` was changed from the original `#2E2C29`** to a neutral near-black. It reads as the same value on structure (2px strokes) but removes the warm cast from body text. Contrast stays clear of WCAG AA: 9.62:1 on `surface`, 6.34:1 on `ground`.

**Player colours are for players.** `playerA`/`playerB` carry "this is Player 1/2" everywhere in the app, so generic UI — a settings toggle, a checkmark — uses `ink`, not indigo. Borrowing a player colour for a control makes it say something it doesn't mean.

### 2.1a Elevation

Shadows come from `GameElevations` (`lib/theme/tokens.dart`), a `ThemeExtension` alongside `GameColors`:

| Token | Use |
|---|---|
| `resting` | Cards and controls sitting on the background — settings pills, skin cards |
| `raised` | Elements that read as floating — menu buttons, circular icon buttons, panel badges, inventory tiles |

Both are tinted from `ink`, not black, so a skin that changes the palette doesn't leave black shadows under a warm one. **Widgets must not invent shadow colours**, same rule as text and fill colours.

### 2.2 Typography
- **Display — Bricolage Grotesque.** Mode names, win banners, big numbers. Used sparingly.
- **UI & body — Archivo.** Buttons, labels, tutorial copy, settings. Clean at small sizes; handles Spanish diacritics without substitution.
- **Data — Archivo, tabular figures.** Stats, timers, counters — so numbers don't jitter as they update.
- Sentence case throughout. No all-caps except very small utility labels.

**As built: Bricolage Grotesque only.** Archivo is not bundled, so Bricolage carries both roles. Bricolage does ship the `tnum` feature, so the tabular-figure requirement above is satisfied for real (see `data`/`dataSmall` below). Bundling Archivo later means adding the files and pointing the body/data styles at it — the styles are already separated for exactly that.

Weights bundled: **400/500/600/700**. Asking for a weight outside that set silently snaps to the nearest bundled one.

#### The type scale

Styles live in `GameTextStyles` (`lib/theme/typography.dart`), a `ThemeExtension` named for *what the text is* rather than for a point on Material's scale. Every style is **non-nullable and already coloured**, so call sites pass it straight to `Text` — no `copyWith(color:)` at each one.

`display` · `banner` · `screenTitle` · `cardTitle` · `subtitle` · `bodyLarge` · `body` · `bodyMuted` · `label` · `labelMuted` · `caption` · `data` · `dataSmall` · `mainMenuButton`

Two rules that matter:

- **`toTextTheme()` feeds Material's slots from the same scale**, so stock widgets (dropdowns, dialogs, buttons) restyle with everything else rather than drifting into a second type scale.
- **Restyling is a single edit in that file.** Don't hardcode a size or weight in a widget; if a screen needs something the scale lacks, add it to the scale.

### 2.3 Chips — the signature element
**A chip is a set of concentric rings, flat-filled in its player colour. Level = number of rings** (L1 = one ring, L4 = four).

This is the most important decision in the visual system: level becomes legible three ways at once — size, ring count, and colour — so accessibility is satisfied *by the design* rather than bolted on. It also stays readable when Ultimate's cells shrink.

**A fourth signal: the level numeral.** Stacking chips carry their level as a small badge on the lower-right (`ChipView.showLevel`) — filled with the ring colour and outlined in the player's, because the badge straddles the chip's edge and has to read against both the chip and the cell behind it. Shown on board chips, the staged preview, and the inventory tiles.

Two rules it must obey:

- **Only ever on a chip that is already visible.** Level is public for a chip you can see and emphatically private for a buried one (§2.5) — and a numeral leaks it far more plainly than colour or band count would. `showLevel` therefore defaults to *off*, so a chip rendered somewhere new can't leak by accident. The board only draws `topChipAt`, which is what makes it safe there.
- **It is redundancy for banded forms, and load-bearing for glyph ones.** On `rings` and `dolls` the bands already carry the level and the numeral just confirms it. On `ChipForm.marks` — the classic X and O — there are no bands, so level rests on the size ladder plus the numeral. That's the reason the numeral exists, and the reason a glyph skin can't ship without it. It's excluded from semantics either way, since the cell's own label already announces the level.
- **Ultimate draws no numeral at all.** That board has no levels, so a numeral there would state a rank that doesn't exist. A levelled skin's Ultimate mark is one of its chips (L4 by default — `07-SKINS.md` §2b), drawn with `fillsCell: true` and no badge: full cell size, since there's no ladder to sit in either. `fillsCell` is Ultimate's alone — everywhere levels coexist, relative size is how a player reads them, and that's gameplay-critical.

### 2.4 Board
- Grid drawn as **negative space** — gaps between `surface` squares against `ground` — not drawn lines. Cleaner at Ultimate's density, where 81 cells of gridlines is noise.
- Squares: 4px corner radius. Chips: fully round. Soft-square board against perfect-circle chips is the visual rhythm.

### 2.5 CRITICAL — never reveal what is buried
A covered square shows a thin `neutral` **collar** at its base, indicating only *that* something is buried and how deep. It must never hint at the buried chip's colour or level.

Showing a sliver of the covered chip's real colour is the obvious, tempting design — **and it destroys the memory mechanic the stacking modes are built on.** That a stack exists is public (everyone watched it happen). What's in it is memory. Respect that line exactly.

### 2.6 Skins
Skins may change palette, chip form (rings → dolls, stones, tiles), board material, placement/cover animations, and the SFX set.

Skins may **never** change chip size relationships, ring-count legibility, or the buried-collar rule. Those are gameplay-critical, not decorative.

---

## 3. Interaction

### 3.1 No undo — confirm before commit
- Tapping a chip or cell **stages** the move: it renders as a translucent preview in place. A confirm control (or a second tap on the same target) commits. Tapping elsewhere or cancel clears it.
- Prevents fat-finger mistakes without allowing take-backs — which matters most in Stack-Static where every placement is permanent.
- Committed moves are final in all modes, vs AI and local alike.

### 3.2 Staging must not leak hidden information
- Staging a cover move must **not** reveal what is beneath the target square.
- In Movable mode, selecting one of your chips to relocate must **not** preview what is underneath it.
- **DECIDED (2026-07-19): free cancellation.** Selecting a chip previews legal destinations; tapping elsewhere or cancel clears it. Friendlier on touch screens and consistent with staging in the other modes. (Strict "touch it, move it" was rejected as too punishing for mis-taps.)

### 3.3 Legal-move highlighting — always on
- **Ultimate:** clearly indicate the small board the player has been sent to. When a free move is granted, indicate that *all* open boards are available — this is the rule players most often forget.
- **Stacking:** when a chip is selected from inventory, highlight legal placements. In Movable mode, when a placed chip is selected, highlight legal destinations.
- Subtle: soft outline or tint, not a saturated overlay. Guidance, not the game playing for you.
- **Leaks nothing** — legality depends only on the topmost visible chip, which is already public.
- Not a difficulty setting. Hiding legal moves punishes new players without adding depth.

### 3.4 Ultimate board — tap to zoom
- Default view is the full big board; players need it to plan.
- Tap a small board to zoom it to fill the screen. Cells then comfortably exceed the 44pt minimum tap target.
- Tap out (or a back control) returns to the full view.
- **Do not auto-zoom on the opponent's move.** Yanking the view around is disorienting. Highlight the board they've been sent to and let them choose.
- Transitions ~200ms, respecting reduced-motion.
- On tablets and landscape, zoom may be unnecessary — keep it available for consistency.
- **Zoom is presentation state.** It lives outside game state and never affects legality or serialisation.

### 3.5 Rematch loop
- Post-game screen offers **Rematch** (same mode, opponent, difficulty) as the primary action, one tap. This is the core retention loop; friction here costs more than it appears.
- Never place an ad or chest offer *between* the tap and the new game. Offer the chest alongside the rematch button, never blocking it.

### 3.6 Turn timer
- **Local: optional, off by default.** Presets: off / 30s / 15s. On expiry, forfeit the turn rather than auto-playing a random move — a random move can hand the game away and feels punitive.
- Ranked online timers are v2. The timer is controller-level presentation state and must never live in an engine.

---

## 4. Animation — moderate

Chips drop and settle, covering has weight, board claims get a flourish, wins get a celebration. Not minimal, not maximal.

**Why not minimal:** the cosmetic economy depends on skins feeling worth having. A skin on a static, instantly-appearing chip is a colour swap, and nobody pays for a colour swap. Animation is where a cosmetic's perceived value lives.

**Why not rich:** the core loop is a 2-minute match with a one-tap rematch. Heavy particles and screen shake add seconds to every move; delightful on move one is friction by move forty. It also raises the cost of every additional skin.

### Where the budget goes
1. **Covering a chip** — the signature moment of the stacking modes. Weighty, satisfying, instantly distinguishable from a normal placement.
2. **Claiming a small board in Ultimate** — the symbol resolving into place.
3. **Winning line reveal** — draw the line through the three winning squares rather than just ending the game.
4. Everything else stays quick and unobtrusive.

### Rules
- **Never block input on animation.** Players must be able to tap the next move before the previous animation finishes; queue and catch up. This is the most common way "juicy" games become annoying.
- Move animations ≤ ~250ms. Celebrations may run longer but must be tap-skippable.
- Respect OS **reduced-motion**: fall back to cross-fades, stay fully playable.
- **Skins supply their own placement/cover/claim effects and SFX set.** Build the animation layer once, parameterised by skin — that's what makes a skin feel like a purchase rather than a recolour.
- Budget for low-end Android and Flutter web, where animation costs considerably more.

---

## 5. Audio

Sound effects **and** background music, both in v1.

- **SFX:** chip placement, cover/gobble (weightier than a normal place), small-board claim, game win, invalid move.
- **Music:** low-key looping track. One track is fine for v1; per-mode tracks are a nice-to-have.
- **Independent toggles for SFX and music** in settings, both persisted. Music defaults on but must respect the device silent switch and duck for other audio.
- **Audio must never block or delay a move being committed.**

---

## 6. Accessibility

Target: **colorblind-safe by construction**, not as a toggle.

- **Never rely on colour alone to distinguish players.** Each player has a distinct colour *and* a distinct shape/symbol on every chip. This matters more here than in plain tic-tac-toe because players scan a board of overlapping pieces at a glance.
- **Chip level is distinguishable without colour** — size is primary and inherently non-colour, and ring count (§2.3) is the secondary marker, since size differences compress on small screens.
- Palette survives deuteranopia, protanopia, and tritanopia. No red/green as the player pair.
- In Ultimate, claimed boards must differ from each other and from drawn boards by **pattern or symbol**, not colour alone. **As built:** a claimed board is stamped with the winner's own mark (`07-SKINS.md` §2b), so the two players differ by the chip's centre marker — a dot for player 1, a small cross for player 2 — as well as by colour; a drawn board is a neutral *filled* disc, which no chip form resembles. The centre marker is proportionally small, so this rule is carried mostly by the zoomed-in view — worth revisiting if the unzoomed board ever has to stand alone for a colour-blind player.
- WCAG AA contrast: 4.5:1 text and UI, 3:1 for meaningful graphics.
- **Minimum 44×44pt tap targets** — a real constraint at Ultimate's 81 cells, and the main argument for tap-to-zoom.
- Respect OS text scaling and reduced-motion.
- Screen reader support is not a v1 requirement, but don't block it: give buttons semantic labels as you go.

---

## 7. Onboarding — interactive tutorial

Each mode gets a **guided first game**: a real playable game with contextual prompts overlaid, not a static rules screen. Ultimate especially is very hard to explain cold — players need to *feel* the send rule.

- Triggered automatically the first time a mode is opened; replayable from settings.
- Skippable, but not silently — an explicit "Skip tutorial" control.
- **Implementation: run the real engine with a scripted opponent and a prompt overlay driven by move count.** Do not build a separate mock engine — it will drift out of sync with the rules.
- Persist a per-mode "tutorial completed" flag locally.

Key beats:
- **Stack-Static:** covering a chip; L4 uncoverable; placements are permanent; spend small chips early.
- **Stack-Movable:** the above, plus relocating a placed chip and revealing what was underneath.
- **Ultimate:** the send rule (**show it explicitly at least twice** — it's the single most important beat); claiming a board; the free-move rule.

---

## 8. Localization

- **No hardcoded user-facing strings, from the first screen.** `intl`/ARB, single source-of-truth string file.
- **Launch: English and Spanish.** More later — the point of doing this now is that adding a language becomes a translation file, not a refactor.
- **Allow for text expansion.** Spanish runs ~20–25% longer. Controls wrap or scale; never truncate. Test the longest string in every control.
- **DECIDED (2026-07-19):** mode names are untranslated proper nouns (like game titles), with a translated one-line description underneath.
- Numbers and dates via `intl`, not manual formatting.
- The tutorial is the most text-heavy surface — write its copy as short discrete strings, not paragraphs with embedded formatting.

---

## 9. Web caveat

**Monetization does not carry over to web.**
- AdMob does not support Flutter web. There is no drop-in path for the ad model.
- In-app purchases don't work on web either (`in_app_purchase` is mobile-only). Remove-ads and skin packs have no delivery mechanism.
- So the web build is inherently **free, ad-free, purchase-free**. Fine as a demo or shareable showcase; it cannot be the revenue platform, and if players discover it's ad-free it may cannibalise mobile.
- **Keep all monetization behind platform checks so web omits it rather than failing.**
- Web needs its own performance and input testing (mouse and keyboard, not just touch). Budget it as a real target.
- **OPEN:** does web get cosmetics at all? Simplest answer: cosmetics available, chests earned by play only, no ad chest.

---

## 10. Screens (minimum set)

- Home / mode select (three modes)
- Sub-mode select (Local / AI) + AI difficulty picker
- Game board screen — shared skeleton, mode-specific board widget, emote seat bubbles above the board and a send tray in the staging bar (`05-V2-DEFERRED.md` §4.2)
- Win / draw result screen (with one-tap Rematch)
- Stats screen (per-mode W/L/D)
- Settings — reset stats, SFX/music toggles, replay tutorial, language, local turn timer
- Neutral age screen (see `03-PRODUCT.md`; gates ad initialisation)
- Custom (cosmetic category root) → Chip skins, Emotes, Flexing/celebrations (see `07-SKINS.md` §2a). The Chip skins screen also carries the **Ultimate mark** picker for the worn skin (`07-SKINS.md` §2b).
- Challenges — today's daily goals (which fill the Shop's claim meter) above the permanent achievement list (`03-PRODUCT.md` §3)
- Shop — cosmetic packs, plus the Claim button and daily meter
- *(v2)* Lobby / matchmaking

## 11. Shared components

Built once, in `lib/ui/widgets/`. Use these rather than restyling a Material
widget at the call site — that's how a design drifts.

| Component | File | Notes |
|---|---|---|
| `PanelHeader` | `widgets/panel_header.dart` | Badge + title + subtitle + close X, with an optional `trailing` slot. Full-screen panels use this instead of an `AppBar` — they're dismissed with the X, not a back arrow. The X is always pinned to the right edge. |
| `MenuPillButton` | `widgets/buttons/menu_pill_button.dart` | The large stadium buttons on Home. Sized by height, not by label, so a row stays even across translations. |
| `PillActionButton` | `widgets/buttons/pill_action_button.dart` | Small stadium button. Dims to 45% when disabled. |
| `PillDropdown` | `widgets/buttons/pill_dropdown.dart` | Stadium-shaped dropdown. `centerLabel` and `style` for pickers that *are* the screen rather than sitting in a settings row. |
| `SegmentedPills` | `widgets/buttons/segmented_pills.dart` | One-of-many pills; a segment can be `available: false` to render locked. |
| `CircleIconButton` / `CircleButtonCluster` | `widgets/buttons/` | Corner controls. The cluster wraps rather than overflows. |
| `CategoryTile` | `widgets/buttons/category_tile.dart` | Square tile with caption + glyph; `available: false` renders locked and refuses taps. |
| `AppMark` | `widgets/app_mark.dart` | The logo mark, painted rather than bundled so it inherits `ink` and stays crisp at any size. |
| `MatchEmoteBubbles` / `MatchEmoteTray` | `widgets/match_emotes.dart` | Two always-drawn seat bubbles above the board (an empty one is the reserved place a v2 received emote lands), plus a toggle in the staging bar that opens the four equipped emotes as a floating overlay, so opening it moves nothing. The tray hangs off the button — centred on it, below where there's room and above where there isn't, clamped back on screen near an edge. Closes on any change to the game, since its position is fixed at open time. Sending is presentation state only — never a move. |
| `AssetGlyph` | `widgets/asset_glyph.dart` | A bundled image that degrades to an icon when the art isn't there. Every cosmetic catalogue ships before its art, so this is the one place that behaviour lives. |
| `RarityLegend` | `widgets/rarity_legend.dart` | The static COMMON/RARE/EPIC/LEGENDARY row. A legend, not a filter — nothing carries a rarity yet. |

**Locked/unavailable is a shared idiom**: 45% opacity, a lock glyph where the
content would be, and no tap. `CategoryTile`, `SegmentedPills`,
`PillActionButton` and the emote catalogue all use it, so "not yet" looks the
same everywhere.

### Layout rules that keep biting

Learned the hard way; each of these was a real bug:

- **Test at size, in both languages.** Spanish runs longer and wraps, and most
  overflows only appear on a short landscape phone or an SE-class portrait.
- **A fixed-height widget inside a bounded parent gets squashed, not shrunk.**
  Derive the size from the available space instead.
- **`Expanded` absorbs slack; `Flexible` doesn't.** A trailing control only
  stays pinned if something before it is `Expanded`.
- **A widget scrolled out of view still has coordinates.** A tap on it lands
  wherever those coordinates are — possibly on another control.
