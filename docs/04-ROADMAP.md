# 04 — Build Roadmap

Each phase ends in something runnable. **Do not start UI before Phase 1 is tested** — engine bugs are far cheaper to fix before anything renders.

---

## Phase 0 — Foundations
- Flutter project setup. Targets: iOS, Android. (Web deferred to Phase 10 — but don't write anything that structurally blocks it.)
- Riverpod wired up.
- **Localization scaffolding from day one** — `intl`/ARB, English + Spanish files. No hardcoded strings from the very first screen.
- Folder structure per `CLAUDE.md`, separating pure-Dart engines from UI.
- Git repo, `.gitignore`, GitHub Actions running `flutter analyze` + `flutter test` on push.
- **Blocked on the developer:** app name, bundle ID, package name, developer name, minimum iOS/Android versions. Ask.

## Phase 1 — Game engines (pure Dart, no Flutter imports)
- `stacking_engine`: board state, chip inventories, placement legality, cover rules, L4 uncoverability, topmost-visible win detection. `canMovePlacedChips` flag + data-driven inventory serves both stacking modes.
- `ultimate_engine`: nested board state, active-board tracking, send rule, claiming, free-move rule, big-board win detection, tiebreak.
- Shared interface: `legalMoves()`, `applyMove()`, `status()`, JSON serialise/deserialise.
- **Exhaustive unit tests** covering every rule in `01-GAME-RULES.md`, especially: pass rule, Static tiebreak, drawn small boards, free move, L4 behaviour, JSON round-trip, determinism (same move list → same state).
- **Deliverable: engines fully playable and verified from tests alone, with no UI.**

## Phase 2 — Playable local UI
- Mode select → sub-mode select → board → result.
- All three modes playable in local pass-and-play.
- Confirm-before-commit staging.
- **Deliverable: the actual game, playable end to end, unstyled.**

## Phase 3 — AI
- Minimax + alpha-beta + transposition table for the stacking engine.
- Heuristic agent for Ultimate Easy/Medium; MCTS for Hard/Impossible.
- Four difficulty tiers via depth + randomness.
- **Run engine-vs-engine balance batches here** (see `01-GAME-RULES.md` §6.1) *before* art and monetization are built on these numbers. Report findings — they may change the chip inventories.

## Phase 4 — Core UX
- Legal-move highlighting.
- Ultimate tap-to-zoom.
- Responsive layouts, both orientations, state survives rotation.
- Accessibility pass: colorblind-safe palette, shape/ring differentiation, contrast, tap targets.
- Interruption handling — in-progress game persists across backgrounding and relaunch.

## Phase 5 — Onboarding
- Interactive guided first game per mode, using the real engine with a scripted opponent.

## Phase 6 — Stats & settings
- Per-mode W/L/D split by opponent type and difficulty.
- Settings: reset stats, replay tutorial, language, local turn timer.

## Phase 7 — Audio & animation
- SFX + background music with independent toggles.
- Moderate animation layer, **parameterised so skins can supply their own effects and sounds**.

## Phase 8 — Cosmetics
- Skin system: chips, boards, backgrounds; swappable without touching game logic.
- Base free set (the turned-wood direction) plus at least one premium set.
- Achievement-unlocked skins.
- **Blocked on the developer:** how many skins at launch.

## Phase 9 — Monetization & compliance
- **Neutral age screen first — it gates ad initialisation.**
- Ads (frequency-capped interstitial, rewarded), remove-ads IAP, skin pack IAPs.
- Chest system: progress meter → daily chest → capped ad chest.
- Crash reporting + the small analytics event set.
- Privacy policy, privacy nutrition labels, mixed-audience ad configuration.

## Phase 10 — Web target
- Flutter web build, mouse/keyboard input, performance pass.
- Monetization behind platform checks so web omits rather than breaks.

## Phase 11 — Release
- Store assets, screenshots per device class, listings in English and Spanish.
- Device testing on low-end Android and older tablets.
- **Blocked on the developer:** Apple Developer account ($99/yr, enrolment can take days) and Google Play account. These block real-device testing and submission — start them early, not here.

---

## Post-launch (v2)
See `05-V2-DEFERRED.md`. Do not build from it.
- Online multiplayer
- Ranked mode with mandatory turn timers
- Mixed Ultimate × Stacking mode
- Additional languages
