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
| A decision someone could reasonably re-litigate | **Decided**, below — with the reasoning, not just the outcome |
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
- Ads/IAP on web (Phase 10): both are no-ops on web regardless of the `FLUTTER_TEST` check, per design doc §9 ("AdMob does not support Flutter web"; "in_app_purchase is mobile-only") — `adsServiceProvider`/`purchaseServiceProvider` return their `_Null...Service` the moment `kIsWeb` is true. The Settings screen's remove-ads section and the Skins screen's buy button are hidden on web to match (`_productFor` returns null on web — since moved to `ChipSkinsScreen`) — achievement-unlocking still works there since it's pure local storage.
- Web verification (Phase 10): no browser-automation tool is available in this environment, so manual UI verification used the Chrome DevTools Protocol directly (via a raw WebSocket connection) rather than clicking through the app — confirmed the page loads, title renders correctly, and the console shows no fatal errors (only the already-documented Phase 7 "music asset not bundled, fails silently" 404). This is not the same as a human clicking through mouse/keyboard flows in a real browser window — that check found two real bugs below, confirming it was worth doing.
- AI move seeding on web (Phase 10 follow-up): `AiRunner.chooseMove` seeded `Random()` with `Random().nextInt(1 << 32)`. On web, that shift wraps to 0, so `nextInt(0)` threw a `RangeError` the moment the AI needed to move — a real `DartError` in Chrome, found via the developer's own manual testing (`flutter test` can't catch this; it always runs on the VM, never the web JS runtime). Fixed by using a plain literal (`nextInt(2147483647)`, i.e. 2³¹−1) instead of any `<<` shift, rather than guessing at a shift amount that happens to be safe.
- `dart:isolate` on web (Phase 10 follow-up, found the same way): `Isolate.run` — used so an expensive AI search (Impossible's ~1.5s MCTS budget) never blocks the UI thread — has **no web implementation at all**; it throws `Unsupported operation` unconditionally there. Fixed with a `kIsWeb` branch: web runs the same computation directly on the main thread instead (there's no background-thread alternative without adding real Web Worker infrastructure, which is a bigger follow-up, not part of this fix). **Known consequence, not fully resolved:** Impossible-tier vs-AI moves will still visibly freeze the web tab for ~1.5s — the `kIsWeb` path only ensures the "AI thinking" indicator paints first, it doesn't make the computation non-blocking. Revisit if web vs-AI at higher difficulties needs to feel smooth.

## Decided (UI pass, 2026-08)

A design-led pass over the screens, driven by mockups. Engines, controllers and game rules were untouched.

- Typography: **Bricolage Grotesque bundled** (static instances, weights 400/500/600/700, SIL OFL — licence in `assets/fonts/OFL.txt`). Google Fonts only publishes the variable font, which would need `FontVariation` at every call site. Archivo is still not bundled, so Bricolage carries body text too; Bricolage ships `tnum`, so the design doc's tabular-figure requirement is genuinely met. All text goes through `GameTextStyles` (`lib/theme/typography.dart`) — see `02-DESIGN-SYSTEM.md` §2.2.
- New theme extensions: `GameTextStyles` and `GameElevations`, joining `GameColors`/`GameAnimations`. Shadows are tinted from `ink`, never black, so a skin's palette carries into them.
- `ink` changed `#2E2C29` → `#303032`. Structure strokes are unaffected at that delta; body text loses a warm cast. Contrast re-checked (9.62:1 on `surface`, 6.34:1 on `ground`).
- Panels replace `AppBar` on Settings, Custom, Chip skins and Emotes: `PanelHeader` (badge + title + subtitle + X). **Consequence:** `tester.pageBack()` no longer works on those screens — tests close them via their X key.
- Cosmetics restructured into categories (`CustomizationCategory`): board, chips, emote, flexing. `SkinsScreen` is the category root; the chip picker moved to `ChipSkinsScreen`. Board and flexing render locked. See `05-V2-DEFERRED.md` §4.
- **Emotes built** (`Emote` / `EmoteService` / `EmoteController` / `EmoteSkinsScreen`): a 10-entry catalogue, 4-slot loadout, persisted locally, 4 free and 6 locked. Sending one in a match is v2. Art isn't bundled — every emote renders its `fallbackIcon`, and `assets/emotes/` stays out of `pubspec.yaml` until real files exist (declaring an empty asset dir fails the build).
- **Celebrations built** (`Celebration` / `CelebrationService` / `CelebrationController` / `CelebrationSkinsScreen`): a 16-entry catalogue paged 12 to a "block", one selection persisted, 4 free and 12 locked, with a preview frame beside the grid. **Nothing plays a celebration yet** — the format (still / sprite sequence / video) is undecided, and only the preview widget and asset convention depend on it. Locked entries can be *previewed* but not equipped; the header's lock pill reports the previewed one's state. Same no-art-bundled arrangement as emotes.
- **Skins are now chosen and sold per mark** (`SkinPair`): player 1's chips and player 2's chips carry separate skins, separately persisted. The shop mockup sells an X pack and an O pack, which only means anything if the two are independent. Boards take a `SkinPair` and resolve at the individual chip/mark, since that's the first point that knows whose it is. Player 2 falls back to player 1's stored value on upgrade, so an existing install doesn't suddenly change half the board.
- **Daily challenges + a claim meter** (`DailyChallenge` / `DailyChallengeService` / `DailyChallengeController`): four goals that reset daily, fed by `GameController._recordDailyProgress`. Finishing all four enables Claim in the Shop, which opens one chest via `ChestController`. Deliberately non-coercive per `03-PRODUCT.md`'s audience: no streaks, no timers, nothing lost by not playing — a stale day is just a new empty day.
- **Chests, minimally** (`ChestController`): claiming grants **one uniformly-random locked cosmetic** across skins/emotes/celebrations. Uniform on purpose — rarity tiers and drop tables are still undecided, and inventing weights now would have to be unpicked later. Chests remain unpurchasable (product doc §3.3): the only way to open one is to play.
- Shared cosmetic widgets rather than a third copy each time: `AssetGlyph` (bundled image degrading to an icon — `EmoteView` is a thin wrapper) and `RarityLegend` (the static tier row, lifted out of `ChipSkinsScreen` when the celebration picker needed it too).
- **Chip level numerals** (`ChipView.showLevel`): a badge on each stacking chip's lower-right, on board chips, the staged preview and the inventory. Defaults to *off* and is only set where the chip is already visible — the board draws `topChipAt` only, so it cannot leak a buried level, which a numeral would do far more plainly than colour or band count. Excluded from semantics; the cell's label already announces the level.
- **Classic X/O skin** (`ChipForm.marks` / `GameSkin.classicMarks`, free): the traditional glyphs. It is the **only form with no band count**, so its level legibility rests on the size ladder plus the numeral — which is why the numeral was built first. `GameSkin` gained a `free` flag at the same time, replacing a hardcoded "is this turnedWood?" check in three places that stopped being the right question once a second free skin existed.
- Chip inventory is a **2×2 grid** (`InventoryGrid`, was `InventoryRow`) in both the game and the tutorial. Four in a line needs ~400pt, which a narrow landscape side panel doesn't have; the fixed arrangement also means chips don't move as the width changes.
- **Ultimate marks wear a chip variant** (`SkinPair.ultimateLevelFor`): Ultimate has no chip levels, so a levelled skin has no natural mark to draw there. It wears one of its four chips — **L4 by default** (`kDefaultUltimateMarkLevel`), the boldest silhouette at Ultimate's small cell size — and the player picks another per mark on the Chip skins screen. **The picker deliberately offers no "classic X/O" entry**: the classic mark is what the free glyph skin (`ChipForm.marks`) *is*, so listing it here would offer the same thing by two routes and let a skin be selected that then never appears in Ultimate. A glyph skin gets no picker at all, for the same reason — nothing to choose. A chosen level carries across a skin change untouched, since every levelled skin has all four. A **claimed small board** is stamped with the winner's own mark too, rather than a bare X/O — a drawn board keeps the neutral disc, since it belongs to nobody. **Consequence:** the Ultimate board no longer defaults to the painted X/O — an existing install now sees Turned Wood's L4 chips there, and the two players are told apart on it by the chip's centre marker (dot vs. cross) rather than by two unmistakably different glyphs. See `07-SKINS.md` §2b and the note on §6 in `02-DESIGN-SYSTEM.md`.
- **Emotes are sendable in a match** (`MatchEmoteController` / `match_emotes.dart`), in all three modes. A toggle in the staging bar — riding in that bar's already-reserved 64pt band, so it costs no layout — opens the four equipped emotes as a **floating overlay**, so opening it never nudges the board, inventory or staging bar. It hangs off the button: centred on it, below where there's room and above where there isn't (in portrait the bar is the last thing on screen, ~10pt from the bottom), clamped back on screen when the button is near an edge. Positioned by a `SingleChildLayoutDelegate`, because aligning to the button and keeping it on screen both need the tray's measured width — without it the obvious `Positioned(left: 0, right: 0)` centres the tray on the *screen*, which is visibly wrong wherever the button isn't central. Two things that bit while building it: the overlay's own `MediaQuery` reports the window's metrics, not the surface — and under `flutter test` doesn't follow `setSurfaceSize` at all — so the available height comes from the render tree instead, which is also what makes the rule testable; and the tray computes its position once when it opens, so **any change to the game closes it** rather than leaving it stranded over Confirm once the bar wraps onto a second run. There's a test that stages first, then opens the tray, then presses Confirm. the sent one shows in that seat's bubble above the board for 3s, with a 2s cooldown. The tray belongs to whoever is to move, and sending is **presentation state only**: it never reaches the engine, which is also why a v2 network listener can push a received emote through the same `send()` with no engine change. **In pass-and-play this is finished, not a mock** — the opponent is at the same device. The placeholder is the *empty* bubble: both seats are always drawn, so the reserved place a received emote will land is visible now, and the AI's simply never fills. No tray in the tutorial: it's a scripted lesson with nobody to emote at.
- **`InventoryGrid.compact` is now applied on the game screen** (`maxHeight < 640`), not just in the tutorial. It existed for exactly this and was never asked for: full-size chips need ~230pt, so a landscape phone's side column overflowed and the staging bar — Confirm included — sat below the fold, reachable only by scrolling. Found while checking the emote tray was on screen; the fault predated emotes. There's a regression test at 844×390.
- Unbacked UI from the mockups was **not invented**: missions, currency, profile/gamertag/level and chests are absent from Home; the Skins screen's ONLINE tab and the rarity legend render but do nothing (both documented in `05-V2-DEFERRED.md` §4.3–4.4).
- `kBoardPadding` / `kMaxBoardSize()` were made public in `game_screen.dart` because the tutorial reproduces that maths to align its side panels with the board's real edges. Duplicating the literals would let the panels drift the day the board size is tuned.
- Verification method: no browser automation here, so every screen was rendered in widget tests at 5–7 surface sizes × both locales and checked for exceptions and off-by-N alignment. That found real bugs a passing suite didn't — see the layout rules in `02-DESIGN-SYSTEM.md` §11.

## Still undecided — ask before assuming

- Chest rarity tiers and drop weights, and the ad-chest daily cap (`03-PRODUCT.md` §3). A chest now exists and grants **uniformly at random** from what the player doesn't own; the rarity legend on the Chip skins and Flexing screens is still only a legend. Giving a cosmetic a tier means settling this list first, then weighting `ChestController._grantOne`.
- Whether the Shop's six packs become real products, and what each contains — today `fire`/`troll`/`loser` point at existing cosmetics so their owned state is truthful, while `apple`/`elements`/`sakura` have nothing behind them yet (board skins don't exist at all).
- Which emotes (if any) are sold, and at what price point — the catalogue has 6 locked entries with no `ProductId` behind them (see `08-STORE-ITEMS.md` §2a)
- **What format a celebration is** — still image, sprite sequence, or video — and what plays it at the end of a won game. The picker, persistence and catalogue don't depend on the answer; the preview frame and `Celebration.assetPath` do.
- Whether `board` becomes a real category (it's the last locked one), and what a board skin may change without touching the gameplay-critical parts of `02-DESIGN-SYSTEM.md` §2.4
- Which crash-reporting backend (Crashlytics vs. Sentry) to actually finish and switch on
- Whether to switch on `FirebaseAnalyticsService` (and therefore configure a real Firebase project)
