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
| `ink` | `#2E2C29` | Text, outlines, grid structure |
| `playerA` | `#1B4B7A` | Player 1 — deep indigo |
| `playerB` | `#C9601F` | Player 2 — burnt amber |
| `neutral` | `#8A8C84` | Drawn boards, disabled states, buried-stack collar |

Indigo/amber survives all three common colour-vision deficiencies, unlike red/green, and stays legible on both `ground` and `surface`.

**Highlighting uses the active player's own colour at ~15% opacity** — no seventh token. The highlight then tells you *whose* turn it is as well as *where* you may play.

### 2.2 Typography
- **Display — Bricolage Grotesque.** Mode names, win banners, big numbers. Used sparingly.
- **UI & body — Archivo.** Buttons, labels, tutorial copy, settings. Clean at small sizes; handles Spanish diacritics without substitution.
- **Data — Archivo, tabular figures.** Stats, timers, counters — so numbers don't jitter as they update.
- Sentence case throughout. No all-caps except very small utility labels.

### 2.3 Chips — the signature element
**A chip is a set of concentric rings, flat-filled in its player colour. Level = number of rings** (L1 = one ring, L4 = four).

This is the most important decision in the visual system: level becomes legible three ways at once — size, ring count, and colour — so accessibility is satisfied *by the design* rather than bolted on. It also stays readable when Ultimate's cells shrink.

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
- **OPEN — ask before implementing:** the physical game enforces "touch it, move it." The digital equivalent is that selecting a chip commits you to moving it somewhere (destination may change, chip selection may not). Strict enforcement preserves the memory element; free cancellation is friendlier but weakens the mode.

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
- In Ultimate, claimed boards must differ from each other and from drawn boards by **pattern or symbol**, not colour alone.
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
- **OPEN:** are mode names translated or kept as proper nouns? Recommend untranslated (like game titles) with a translated one-line description underneath.
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
- Game board screen — shared skeleton, mode-specific board widget
- Win / draw result screen (with one-tap Rematch)
- Stats screen (per-mode W/L/D)
- Settings — reset stats, SFX/music toggles, replay tutorial, language, local turn timer
- Neutral age screen (see `03-PRODUCT.md`; gates ad initialisation)
- *(v2)* Lobby / matchmaking
