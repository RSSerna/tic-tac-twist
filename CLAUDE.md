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
- Launch skin count (Phase 8): **2 total** — the free "Turned Wood" default plus one premium "Nesting Dolls" set, meeting the design/product docs' documented floor exactly. The premium skin varies chip *form* only (rings → dolls, per design doc §2.6's own example); palette, board, and background stay the turned-wood defaults so as not to redo the Phase 4 accessibility/contrast pass for values nothing here requires changing.
- Achievement-unlocked skins (Phase 8): implemented product doc §3.1's 5 example achievements (beat Impossible × 3 modes, win with an L4 on the final move, claim a majority of Ultimate's boards). Unlocking *any one* fully unlocks the single premium skin — with only one premium skin to unlock, a per-achievement reward mapping is Phase 9 (chests/rarity) scope, not this phase's. Chests themselves are still untouched, per `03-PRODUCT.md`'s explicit "don't build it earlier."
- Achievement condition change (Phase 8): the product doc's literal "claim all 9 boards in Ultimate" is combinatorially unreachable — the engine ends the game the instant any 3-in-a-row of boards completes, and owning 8 of 9 boards always already contains a complete line (removing any single cell from a 3×3 grid still leaves a full row, column, or diagonal among the rest). Redefined as `Achievement.claimBoardMajority`: win while owning **6 or more** of the 9 boards — the highest threshold actually reachable in a real game, while still reading as a dominant win.
- Chests deferred (Phase 9): the full chest system (progress meter, drop tables, rarity, daily/ad-chest sources) was **not built this phase**, per `03-PRODUCT.md` §3.3's own explicit permission to trim it first ("If Phase 9 needs trimming, ship ads + remove-ads IAP + directly-sold skin packs + achievement-unlocked skins first, and add chests once the game is proven") — all four of those *were* built. Rewarded-video ads are deferred alongside chests: their entire purpose in the doc is granting a chest, so there's nothing for one to reward yet.
- Crash reporting (Phase 9): built as a **skeleton for both** Crashlytics and Sentry rather than choosing — `CrashReportingService`'s active default is a no-op (`NoOpCrashReportingService`); `CrashlyticsCrashReportingService` and `SentryCrashReportingService` are real, ready-to-finish implementations, each with a doc comment listing exactly what setup (project creation, config files, DSN) remains before switching one in via `crashReportingServiceProvider`.
- Ads/IAP identifiers (Phase 9): built against Google's officially-published, safe-to-ship-in-development **AdMob test ad unit IDs** (wired into `AndroidManifest.xml` / `Info.plist` and `ads_service.dart`) rather than leaving ads unbuilt. In-app purchase product IDs (`dev.rsaldarris.nested.remove_ads`, `dev.rsaldarris.nested.skin_nesting_dolls`) are placeholders — unlike ad units, IAP has no universal test ID; matching products must be created in App Store Connect and the Play Console before a real purchase can complete. `adsServiceProvider`/`purchaseServiceProvider` auto-no-op under `flutter test`, same rationale and mechanism as `audioServiceProvider` (Phase 7).
- Analytics backend (Phase 9): `AnalyticsService`'s active default is a no-op; `FirebaseAnalyticsService` is the one real backend built (no Sentry-equivalent ambiguity here — the product doc doesn't offer analytics-backend alternatives the way it does for crash reporting), sharing whichever Firebase project Crashlytics ends up configured with.
- Web platform (Phase 10): added via `flutter create . --platforms=web` (`flutter create` also stripped the `android`/`ios` entries from `.metadata`'s migration-tracking list as a side effect — restored them rather than leaving Flutter's own platform bookkeeping wrong). `web/index.html` and `web/manifest.json` updated with the app's real name/description/theme colour; `manifest.json`'s orientation lock changed from the template's `portrait-primary` to `any`, since a mouse/keyboard target has no reason to force portrait.
- Web found a real bug, not just a gap (Phase 10): `audioServiceProvider`/`adsServiceProvider`/`purchaseServiceProvider` all detected the test runner via `Platform.environment['FLUTTER_TEST']` (`dart:io`) — `flutter test` always runs on the VM even for "web" widget tests, so this never once executed on web and the bug stayed invisible until an actual `flutter build web`. `Platform.environment` throws `UnsupportedError` at runtime on web (dart:io is only a partial stub there). Fixed by checking `kIsWeb` (a compile-time constant, safe everywhere, from `package:flutter/foundation.dart`) *before* ever touching `Platform.environment` in all three providers.
- Ads/IAP on web (Phase 10): both are no-ops on web regardless of the `FLUTTER_TEST` check, per design doc §9 ("AdMob does not support Flutter web"; "in_app_purchase is mobile-only") — `adsServiceProvider`/`purchaseServiceProvider` return their `_Null...Service` the moment `kIsWeb` is true. The Settings screen's remove-ads section and the Skins screen's buy button are hidden on web to match (`SkinsScreen`'s `_productFor` returns null on web) — achievement-unlocking still works there since it's pure local storage.
- Web verification (Phase 10): no browser-automation tool is available in this environment, so manual UI verification used the Chrome DevTools Protocol directly (via a raw WebSocket connection) rather than clicking through the app — confirmed the page loads, title renders correctly, and the console shows no fatal errors (only the already-documented Phase 7 "music asset not bundled, fails silently" 404). This is not the same as a human clicking through mouse/keyboard flows in a real browser window — that check is still worth doing before shipping the web build.

## Still undecided — ask before assuming

- Chest rarity tiers, progress-meter length, ad-chest daily cap (deferred past Phase 9 — see `03-PRODUCT.md` §3 and the Phase 9 "chests deferred" decision above)
- Which crash-reporting backend (Crashlytics vs. Sentry) to actually finish and switch on
- Whether to switch on `FirebaseAnalyticsService` (and therefore configure a real Firebase project)
