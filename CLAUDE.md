# CLAUDE.md — Project Rules

Flutter game: three tic-tac-toe variants in one app. Greenfield project. Developer is comfortable with Flutter — explain decisions, don't explain Flutter basics.

## Documents

Read the one relevant to the current task. Do not load all of them at once.

| File | Read when |
|---|---|
| `docs/01-GAME-RULES.md` | Implementing or changing any game engine. **Single source of truth for rules.** |
| `docs/02-DESIGN-SYSTEM.md` | Building any UI, visuals, animation, audio, accessibility, or localization |
| `docs/03-PRODUCT.md` | Monetization, ads, chests, analytics, stats, age rating |
| `docs/04-ROADMAP.md` | Planning what to build next, or checking phase scope |
| `docs/05-V2-DEFERRED.md` | Only when explicitly asked about post-launch work. **Do not build from this file.** |
| `docs/06-PRIVACY-COMPLIANCE.md` | Privacy policy text, App Store/Play Store nutrition-label mapping, before store submission |
| `docs/07-SKINS.md` | Adding or wiring any cosmetic — chip skins (painted or asset-backed), **emotes**, or **celebrations**: the `ChipAppearance`/`Emote`/`Celebration` models, the category root, naming, unlock routes, and constraints |
| `docs/08-STORE-ITEMS.md` | Adding purchasable items to the Shop: `ShopItem`/`ProductId` wiring, store-console setup, granting/restoring, and the "direct purchase vs. currency" decision |
| `docs/09-DECISIONS-LOG.md` | Before re-deciding something that might already have a documented reason, or when you need the historical context behind a specific phase's code |

## Documentation — a feature isn't done until the docs are true

These documents are the project's memory. Code that contradicts them is worse than no docs at all, because the next reader trusts the wrong thing. **Updating them is part of the change, not a follow-up task.**

This is not a request to document everything. A private helper, a refactor that changes no behaviour, a bug fix that restores documented behaviour — none need a word. The trigger is narrow: **a document is now wrong, or silent about something a future reader would need.**

When that happens, update the one that's now wrong:

| What changed | What to update |
|---|---|
| Any game rule or engine behaviour | `01-GAME-RULES.md` — the single source of truth. Change it **first**, then the code. |
| A new screen, or a widget meant to be reused | `02-DESIGN-SYSTEM.md` §10 (screens), §11 (shared components) |
| A design token — a new one, or a changed value | `02-DESIGN-SYSTEM.md` §2, with the actual value and, for colours, the contrast check |
| A new kind of cosmetic, or how one is authored | `07-SKINS.md` |
| Anything sellable, or a new `ProductId` | `08-STORE-ITEMS.md` |
| Work built for — or blocking — post-launch | `05-V2-DEFERRED.md` |
| Monetization, ads, analytics, age gating | `03-PRODUCT.md` |
| Anything that changes what data leaves the device | `06-PRIVACY-COMPLIANCE.md` |
| A decision someone could reasonably re-litigate | `09-DECISIONS-LOG.md` — append an entry with the reasoning, not just the outcome |
| A choice deliberately left open | **Still undecided**, below |

Four rules for the update itself:

1. **Describe what is, not what's intended.** If something renders but does nothing — a locked tab, a legend nothing filters on, a picker for a thing that never plays — say that in those words. A reader must be able to tell built from planned without running the app.
2. **Renames break docs silently.** The docs name files and symbols, and nothing type-checks them. After moving or renaming anything they reference, grep the docs for the old name.
3. **Record the why.** "Chose X" ages badly. "Chose X because Y; Z is what would change our mind" survives long enough to be useful.
4. **Not building something is a decision too.** Anything deliberately skipped goes in `05-V2-DEFERRED.md` or **Still undecided** — otherwise the next person either rebuilds it or assumes it already works.

## Architecture — non-negotiable

**Engines are pure Dart. No Flutter imports in engine code, ever.**

```
lib/
  engines/          # pure Dart, zero Flutter dependencies
    stacking/       # serves Stack-Static AND Stack-Movable via config
    ultimate/
    common/         # shared GameEngine interface, Move, GameStatus
  controllers/      # GameController — turn management, bridges engine to UI
  ui/               # widgets, screens
  theme/            # design tokens, skin system
  services/         # storage, audio, ads, analytics
  l10n/             # ARB files
```

Rules that must not be broken:

1. **Engines have no Flutter dependency.** If an engine file imports `flutter/`, it's wrong.
2. **Engines are deterministic and serialisable.** Same move list on a fresh state always reproduces the same position. Every engine state round-trips to/from JSON. This is what makes v2 online multiplayer additive rather than a rewrite — do not compromise it.
3. **All moves go through `GameController.submitMove()`.** Local UI and AI are the only callers in v1; v2 adds a network listener as a third. No other path may mutate game state.
4. **Move legality is validated inside the engine, never in the UI.** The UI asks `legalMoves()`; it never decides.
5. **Engines are time-independent.** No timers, no clocks, no `DateTime.now()` inside an engine. Turn timers live in the controller.
6. **Zoom, animation, selection, and staging are presentation state.** They live in the UI layer, never in engine state or serialisation.
7. **The two stacking modes are one engine with two configs**, differing by a `canMovePlacedChips` flag and a data-driven chip inventory. Do not write two engines.
8. **Chip inventories are config, not constants.** They will change during balance testing.

## Conventions

- State management: **Riverpod**. Use it consistently; don't mix in raw `InheritedWidget` or `setState` for shared state.
- **No hardcoded user-facing strings, starting from the first screen.** Everything goes through `intl`/ARB. English and Spanish at launch.
- **No hardcoded colours or text styles in widgets.** Everything comes from the theme tokens in `docs/02-DESIGN-SYSTEM.md`.
- Prefer composition over inheritance for widgets. Keep board rendering swappable — skins must be replaceable without touching game logic.
- Null safety throughout; avoid `late` unless genuinely unavoidable.
- `flutter analyze` must pass clean before any phase is considered done.

## Testing

- **Engines: exhaustive unit tests. This is where the correctness budget goes.** Every rule in `01-GAME-RULES.md`, and specifically the edge cases: the pass rule, the Static tiebreak, L4 uncoverability, drawn small boards, the free-move rule, topmost-visible win detection, and JSON round-tripping. Engines must be provably correct from tests alone, before any UI exists.
- **Widget tests: critical flows only.** Staging and committing a move, rotation preserving game state, resume-after-background. Don't chase widget coverage.
- **Golden tests: skip.** Too brittle for a project with a skin system.
- **CI: GitHub Actions on push — `flutter analyze` + `flutter test`.** Cheap to set up, catches regressions in the engines where they're most expensive.

## Non-negotiable gameplay constraints

These look like UI details but are gameplay-critical. Breaking them breaks the game:

- **Never reveal what is buried under a chip.** Not on staging, not on selection, not visually, not in a tooltip. A covered square may show *that* something is buried and how deep — never whose or what level. The stacking modes are memory games; this is the mechanic.
- **No undo.** Confirm-before-commit staging instead.
- **Legal-move highlighting is always on** and leaks nothing (legality depends only on the visible top chip, which is public).
- **Never block input on animation.** Queue moves and let animation catch up.
- **Skins may never alter** chip size relationships, ring-count legibility, or the buried-collar rule.

## Scope discipline

- v1 is **offline only**. No network, no accounts, no backend. Do not add them.
- v1 ships **three modes**: Stack-Static, Stack-Movable, Ultimate.
- Online multiplayer, ranked play, and the mixed Ultimate×Stacking mode are **v2**. Build nothing for them beyond the architecture rules above.
- Follow the phase order in `docs/04-ROADMAP.md`. Each phase ends in something runnable. **Do not start UI before the engines are tested.**

## Decided

The full history — Phase 0 through the 2026-08 UI pass, with the reasoning behind each — has moved to `docs/09-DECISIONS-LOG.md` to keep this file small. Read it before re-deciding anything that sounds like it was already settled. Append new entries there, not here.

## Still undecided — ask before assuming

- Chest rarity tiers and drop weights, and the ad-chest daily cap (`03-PRODUCT.md` §3). A chest now exists and grants **uniformly at random** from what the player doesn't own; the rarity legend on the Chip skins and Flexing screens is still only a legend. Giving a cosmetic a tier means settling this list first, then weighting `ChestController._grantOne`.
- Whether the Shop's six packs become real products, and what each contains — today `fire`/`troll`/`loser` point at existing cosmetics so their owned state is truthful, while `apple`/`elements`/`sakura` have nothing behind them yet (board skins don't exist at all).
- Which emotes (if any) are sold, and at what price point — the catalogue has 6 locked entries with no `ProductId` behind them (see `08-STORE-ITEMS.md` §2a)
- **What format a celebration is** — still image, sprite sequence, or video — and what plays it at the end of a won game. The picker, persistence and catalogue don't depend on the answer; the preview frame and `Celebration.assetPath` do.
- Whether `board` becomes a real category (it's the last locked one), and what a board skin may change without touching the gameplay-critical parts of `02-DESIGN-SYSTEM.md` §2.4
- Which crash-reporting backend (Crashlytics vs. Sentry) to actually finish and switch on
- Whether to switch on `FirebaseAnalyticsService` (and therefore configure a real Firebase project)
