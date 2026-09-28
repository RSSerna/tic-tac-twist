# 03 — Product: Monetization, Compliance, Analytics

All of this is **Phase 9**. Don't build it earlier. But read §1 before Phase 0, because the age-rating decision shapes the SDK choices.

---

## 1. Target age rating — DECIDED: mixed audience with a neutral age screen

This constrains ads, analytics, and chests simultaneously. The mechanics below are Google Play's; Apple's are similar in spirit but less prescriptive.

**Why not "children only":** apps whose target audience is only children must use ad SDK versions self-certified under Google Play's Families Self-Certified Ads SDK Program, must not request AD_ID permission on Android API 33+, and must not contain SDKs not approved for child-directed services. AdMob then serves only Families-compliant ads — a subset of the broader pool, meaning materially lower revenue.

**Why not "adults only":** a tic-tac-toe game plainly appeals to children. Under-declaring risks reclassification or enforcement.

**Chosen: mixed audience.**
- Mixed-audience apps must include a **neutral age screen** so children only see non-personalised ads.
- Apps targeting both children and adults may use non-certified ad SDKs, but **only for users who are not children**.
- For requests served to children or users of unknown age: call `tagForChildDirectedTreatment(true)` and set `max_ad_content_rating` to `G`.
- Preserves full ad revenue from adult players while staying compliant for younger ones.

### 1.1 Implementation consequences
- **Build the neutral age screen early — it gates ad initialisation** and can't be bolted on at the end.
- "Neutral" means it must not encourage a particular answer: ask date of birth or age plainly, with no framing that nudges toward an older answer.
- Persist the result locally; don't re-prompt every launch.
- **Users of unknown age are treated as children by default.**
- The app must comply with COPPA (US) and GDPR (EU), and needs a privacy policy accurately describing its data handling.
- **Verify against current policy at implementation time.** Rules in this area change often; the above reflects policy as documented when this was written.

---

## 2. Monetization model

Free to download, ad-supported, with **cosmetic-only** purchases. **No mechanic, mode, or gameplay advantage is ever sold or locked.** Everything affecting play is available to every player from install.

### 2.1 Ads
- Non-intrusive only: interstitial between games (frequency-capped), plus optional rewarded video the player chooses.
- **Never interrupt an active game. Never place an ad where a mis-tap can hit it.**
- A one-time **remove-ads IAP** should exist — highest-converting purchase in a game like this, and nearly free to implement.

### 2.2 Cosmetics
Skins for chips, boards, and backgrounds. Two routes:
1. **Direct purchase** — the player sees exactly what they're buying.
2. **Earned through play.**

---

## 3. Chests — never purchasable

**Chests cannot be bought with money. Ever.** They come from:
1. Playing the game
2. Optionally watching a rewarded ad

Chests contain **cosmetics only**. No chest content ever affects gameplay.

**Why this structure:** regulatory risk in random rewards comes almost entirely from *money buying randomness*. Belgium and the Netherlands have acted against paid loot boxes, and both app stores require published odds disclosure for paid random rewards. With no real-money path to a chest, that exposure disappears. Anything sold for money must remain a specific, named item shown before purchase.

### 3.1 Chest sources

### As built (2026-08)

The no-ad earner exists and is the **daily challenge set**: four goals that
reset each day (`DailyChallenge`), shown on the Challenges screen and drawn as
the meter under the Shop's Claim button. Finishing all four enables one claim,
which opens one chest.

- **Four goals:** play 2 games · win a game · play all three modes · beat the
  AI on Hard or above.
- **Deliberately non-coercive**, given §1's mixed and possibly child-directed
  audience: no streaks, no timers, nothing lost by not playing. A stale day is
  simply a new empty day — you cannot fall behind.
- **One claim per day**, enforced in the service, so a double tap can't grant
  twice.
- **A chest only ever grants fragments** (2026-09-27). It picks one
  *fragment-gated* cosmetic the player doesn't own yet, uniformly at random
  across skins, emotes and celebrations, and adds fragments toward it; the
  cosmetic unlocks when its running total reaches its requirement. Nothing is
  ever unlocked outright by a chest. Free, achievement-only (Nesting Dolls)
  and purchase-only (Burger Stack) cosmetics are never in the pool. Once
  every fragment-gated cosmetic is unlocked a claim is a no-op that says so.
- **Rarity is real** (2026-09): every chest open independently rolls a tier —
  see the odds table in §3.2 — which decides *how many fragments* that grant
  is worth. Requirements today: Fragment Shard 100, each locked emote 20, each
  locked celebration 30 (emote/celebration amounts are placeholders). See
  `07-SKINS.md` §6. The reveal animation (cycling Common→Legendary, landing
  on the rolled tier) plays on every claim.
- Still **unpurchasable**, per this section's whole point — rarity decides a
  free chest's *fragment yield*, never something a player can pay to skip or
  weight in their favour.

Rewarded-ad chests and achievement chests remain unbuilt.

**A gap to avoid:** if every chest requires watching an ad, there's no ad-free progression at all. That reads as aggressive, and under a child-directed configuration rewarded ads may be restricted — which would leave the whole cosmetic economy unreachable. **At least one chest source must require no ad.**

| Source | Ad required | Notes |
|---|---|---|
| **Progress meter** | No | Every completed game fills a bar; full bar = chest (~5–8 games). **The core earner — build this first.** Self-limiting, scales with engagement, no timers, works offline. **As built:** the meter is filled by *daily challenges* rather than a raw game count (see below) — same shape, but the goals say what to do rather than just counting. |
| **Daily first game** | No | First completed game each day awards a chest. Retention hook without an ad wall. |
| **Rewarded ad chest** | Yes | Optional, offered post-game. **Cap at 2–3/day** or the economy is farmable. |
| **Achievement chests** | No | One-time: beat Impossible in each mode, win with an L4 chip on the final move, claim all 9 boards in Ultimate. Drives mode exploration, makes skins feel earned. |
| **Streak chest** | No | Optional. Skip if retention mechanics feel heavy-handed. |

### 3.2 Constraints
- **Publish drop odds anyway.** Not strictly required when chests are unpurchasable, but free to do, builds trust, future-proofs against policy changes. Done: every chest open rolls one of these tiers (`lib/theme/rarity.dart`), shown live in `RarityLegend` and the chest-reveal sheet:

  | Tier | Odds | Fragments (if the pick is fragment-gated) |
  |---|---|---|
  | Common | 60% | 1 |
  | Rare | 25% | 5 |
  | Epic | 12% | 10 |
  | Legendary | 3% | 25 |

  Fragments are per item and each chest feeds one randomly-picked item, so
  progress is spread across every fragment-gated cosmetic still locked (19 at
  launch) — unlocking any *particular* item takes far longer than its
  requirement divided by the average yield. Pacing is unresolved; see the
  decisions log.
- **Handle offline.** Ads need network. Rewarded chests must fail gracefully offline; **play-earned chests must work with no connection**, since v1 is otherwise fully offline.
- **Never gate a rematch behind an ad.** The rewarded offer is always genuinely optional, never friction in the core loop.
- Daily/streak rewards keyed to device clock are trivially cheated by changing system time. Low stakes for cosmetics — either accept it or gate on a network timestamp when available.

### 3.3 Scope note
The chest system (inventory, drop tables, rarity, odds, caps) is meaningful engineering for a game whose loop is a 2-minute match. **If Phase 9 needs trimming, ship ads + remove-ads IAP + directly-sold skin packs + achievement-unlocked skins first**, and add chests once the game is proven.

**OPEN:** launch skin count, progress-meter length, ad-chest daily cap.

---

## 4. Local stats

Persist per-mode **win / loss / draw** counts on device. No accounts, no sync.

- Tracked separately per mode.
- **Split local-play results from vs-AI results, and vs-AI by difficulty tier** — otherwise the numbers are meaningless once someone farms Easy.
- Storage: `shared_preferences` is sufficient; Hive if the schema grows.
- Include a **reset stats** control in settings.
- Abandoning a game vs AI counts as a loss.

---

## 5. Analytics & crash reporting

**Crash reporting: build it.** Non-negotiable — without it you learn about crashes from one-star reviews. Crashlytics or Sentry; Firebase is the easier choice if v2 online uses it too.

**Gameplay analytics: a small, purposeful set.** This spec has real open balance questions that can't be answered from a desk:

| Open question | Event that answers it |
|---|---|
| First-player advantage in stacking modes? | `game_ended` with `first_player` + `result` |
| Is the 9-chip Static inventory right? | Draw rate and average game length per mode |
| Does the "most visible chips" tiebreak ever fire? | `game_ended` with `end_reason` |
| Is Impossible actually unbeatable? | Win/loss by difficulty tier |
| Is the tutorial working? | `tutorial_completed` vs `tutorial_skipped` |

Keep the event set this small:
`game_started(mode, opponent_type, difficulty)`, `game_ended(mode, result, end_reason, move_count, duration, first_player)`, `tutorial_completed / skipped(mode)`, `chest_opened(source)`, `ad_watched(placement)`.

**No user IDs. No advertising ID. No per-move tracking. Aggregate only.**

### 5.1 Privacy
- Under the mixed-audience configuration (§1), only serve personalised ads to confirmed non-children, and don't collect the advertising ID from children or users of unknown age.
- Apple requires accurate **privacy nutrition labels**. App Tracking Transparency is only needed if tracking across apps — this design should avoid that entirely.
- **Settle the SDK list against the age-rating configuration before wiring anything in.** Retrofitting is significantly more work than doing it right first.
