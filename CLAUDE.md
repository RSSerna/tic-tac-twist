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

## Decided (Phase 0, 2026-07-19)

- App name: **Nested**. Bundle ID / Android package: `dev.rsaldarris.nested`. Dart package: `nested_game` (plain `nested` collides with the pub.dev package of that name).
- Developer name: Ricardo Saldarriaga Serna.
- Minimums: iOS 13, Android 6.0 (API 23 — Google Mobile Ads SDK floor).
- Stack-Movable stall rule: threefold repetition of position = draw (see `01-GAME-RULES.md` §3.3).
- Movable staging: free cancellation, no touch-move commitment (see `02-DESIGN-SYSTEM.md` §3.2).
- Mode names are untranslated proper nouns with translated blurbs (see `02-DESIGN-SYSTEM.md` §8).
- Local stats (Phase 6): pass-and-play results are tracked **by seat** (Player 1 / Player 2 / Draw), not a "you"-perspective win/loss — pass-and-play has no persistent per-seat identity across games. Vs-AI results are tracked from the human's perspective, split by difficulty tier.
- Abandon (Phase 6): added an explicit confirm-guarded back/leave action during an ongoing game (`GameScreen`'s `PopScope`) — none existed before, and the "abandoning vs AI counts as a loss" rule (`03-PRODUCT.md` §4) needs something to actually trigger it.
- Turn timer expiry (Phase 6): the timer-expired player **loses the game outright** (`EndReason.timeout`), like losing on time in chess — not "pass the turn with no move played." Neither engine supports a voluntary pass when legal moves exist, and inventing that would be a rules-engine change, not a controller/UI feature.
- Audio content (Phase 7): shipped the plumbing only, no real SFX/music files yet — `AudioService` plays from `assets/audio/sfx/*.wav` and `assets/audio/music/theme_loop.mp3`, none of which are bundled. A missing/failing asset fails silently (never blocks a move); a sound designer drops matching files in later with no code change. `audioServiceProvider` also auto-no-ops under `flutter test` (checks the `FLUTTER_TEST` env var) since audioplayers has no official test-mock story and constructing real `AudioPlayer`s in tests leaks unhandled async errors — every widget/controller test would otherwise need an explicit override just to submit a move.
- Silent switch (Phase 7): both SFX and music use `AudioContextConfig(respectSilence: true)`, not `duckOthers`/`mixWithOthers` — audioplayers' iOS validation forbids combining those with `respectSilence` (the `ambient` category it forces already implies mixing with other audio). SFX respects silent mode too, not just music — a player who flips silent mode almost certainly wants no sound from the app at all.

## Still undecided — ask before assuming

- Launch skin count and chest rarity tiers
