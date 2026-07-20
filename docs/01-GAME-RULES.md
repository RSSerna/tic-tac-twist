# 01 — Game Rules

**Single source of truth for all three engines.** If code and this file disagree, this file is right.

Three modes ship in v1:

| Mode | Twist |
|---|---|
| **Stack — Static** | 4 chip sizes, bigger covers smaller. Placed chips never move. 9 chips each. |
| **Stack — Movable** | Same covering rules, but placed chips can be relocated. 6 chips each. |
| **Ultimate** | 3×3 grid of 3×3 boards; your move dictates the opponent's next board. |

---

## 1. Shared stacking rules (Static and Movable)

Both stacking modes are **one engine, two configs** — a `canMovePlacedChips` flag plus a chip inventory map.

- Board: 3×3.
- Chips have 4 levels, **L1 (smallest) → L4 (largest)**.
- A chip may be placed on an empty square, or on any chip of a **strictly smaller** level — belonging to **either player, including your own**.
- **L4 can never be covered by anything.** It permanently claims that square. (In Movable mode its owner may still pick it up and relocate it.)
- Covered chips remain underneath. In Movable mode they are revealed if the covering chip is later moved. In Static mode they are buried permanently.
- **Win condition:** three squares in a row, column, or diagonal whose **topmost visible chip** belongs to the same player.
  - Chip *level* is irrelevant to the win check. Only ownership of the visible chip matters.
  - Evaluate after every move. In Movable mode a line can be broken by a later move, so the game ends the instant a line exists at the end of a player's turn.

### 1.1 Move legality depends only on visible chips
Legality is determined entirely by the **topmost chip of each square**, which is public information. Buried chips never affect whether a move is legal. This is why legal-move highlighting leaks nothing.

---

## 2. Mode 1 — Stack: Static

### 2.1 Inventory: 9 chips per player

| Level | Count |
|---|---|
| L4 | **1** |
| L3 | **2** |
| L2 | **3** |
| L1 | **3** |

Rationale (do not "simplify" this without playtesting):
- The pyramid shape is the point — small chips are expendable, big chips are agonising decisions. Flatten it and the game becomes "whoever hoards big chips longest wins."
- **Exactly 1 L4 each is critical.** L4 can't be covered, so each one permanently freezes a square. With 2–3 each, 4–6 of only 9 squares lock and the board seizes into a forced draw.
- 18 placements over 9 squares → average stack depth ~2.
- Creates the core lesson: spend small chips early, because late-game there are no empty squares and an unspent L1 is dead weight.

### 2.2 Turn rules
- Place exactly one chip from inventory. Placed chips never move.
- **Pass rule:** if a player has no legal placement (no empty squares, and every remaining chip too small to cover anything), they pass.
- **Game end:** when neither player has a legal placement, the game ends and goes to tiebreak.

### 2.3 Tiebreak (no 3-in-a-row at game end)
**The player with more visible (topmost) chips on the board wins. Exact tie = draw.**

This deliberately mirrors Ultimate's tiebreak so the app teaches one consistent idea: if nobody lines up, whoever controlled more of the board wins. It also gives Static a live secondary objective throughout the game.

---

## 3. Mode 2 — Stack: Movable

### 3.1 Inventory: 6 chips per player

| Level | Count |
|---|---|
| L4 | **1** |
| L3 | **1** |
| L2 | **2** |
| L1 | **2** |

Rationale: 6 is the count the commercial equivalent landed on after real playtesting — enough material for tension, few enough that pieces are precious and players can track what's buried. Below 6 is too thin; you'd need 3 of 4 pieces committed just to threaten a line.

### 3.2 Turn rules
On a turn, do **one** of:
1. **Place** a new chip from inventory (empty square, or covering a smaller chip), or
2. **Move** one of your own chips **that is currently visible** to any other legal square (empty, or covering a smaller chip).
   - The moved chip must be the topmost of its stack. Buried chips cannot be extracted.
   - Moving reveals whatever was underneath.
   - Origin and destination must differ.

Once inventory is empty, a player must move.

### 3.3 Stall prevention — DECIDED (2026-07-19)
**Threefold repetition of position = draw.** A position is the board contents plus the player to move; its third occurrence ends the game immediately. Cheap via a position-count map, matches chess convention. True "no legal move" states are nearly impossible in this mode, so this is the only realistic draw path.

*(Rejected alternatives: forbidding immediate move reversal — only blocks 2-cycles; turn timer — presentation-level, not an engine rule.)*

---

## 4. Mode 3 — Ultimate

1. Big board = 3×3 grid of small boards. Each small board = standard 3×3.
2. The first move of the game may be played in **any** cell of **any** small board.
3. Whichever cell position (0–8) a player just played in, the opponent must play their next move inside the **small board at that same position** on the big board.
   - *Example: P1 plays the top-left cell of the centre board → P2 must play somewhere inside the top-left small board.*
4. Winning 3-in-a-row inside a small board **claims** it. It is marked with the winner's symbol on the big board and removed from play.
5. **Free move:** if the small board you're sent to is already finished — won by either player **or** filled with no winner — you may play any cell in **any** open board.
6. **Overall win:** first to claim 3 small boards in a row, column, or diagonal on the big board wins outright, regardless of unplayed boards.
7. **Tiebreak:** if all 9 small boards finish with no big-board line, whoever claimed the **most** small boards wins. Exact tie = draw.
8. **Drawn small boards are neutral.** They count toward neither player's big-board line, and are removed from play (a directed move into one becomes a free move per rule 5).

---

## 5. Match flow (all modes)

- **First game of a session:** Player 1 starts. Vs AI, the human starts.
- **Rematches: the loser of the previous game starts.** Rubber-band. On a draw, alternate.
  - This matters because the stacking modes may carry a real first-player advantage (measure it in Phase 3). Rubber-banding softens it without a rules change.
- In-progress games must survive backgrounding, calls, and rotation. Serialise to disk; restore on relaunch with resume-or-abandon.
- Abandoning a game vs AI counts as a loss in stats.

---

## 6. AI

Four tiers: **Easy / Medium / Hard / Impossible.** One code path per engine; tiers differ only by search depth and randomness rate.

| Tier | Behaviour |
|---|---|
| Easy | Depth 1–2, ~40% random legal move. Misses obvious blocks. |
| Medium | Moderate depth, ~15% random. Blocks immediate threats, misses 2-move traps. |
| Hard | Deep search, no randomness. |
| Impossible | Maximum strength. |

**Stacking modes:** minimax + alpha-beta + transposition table. Branching factor is small enough to reach or near-reach full depth, especially in the endgame. Truly unbeatable play is achievable here — though perfect play likely yields a **draw**, so "Impossible" means *you cannot win, you may be able to draw*. Determine empirically which it is; if a mode turns out to be a forced first-player win, consider having the AI take second turn on this tier.

**Ultimate:** full minimax is not viable at any tier — the state space is far beyond exhaustive search and the game is not solved. Use a heuristic agent for Easy/Medium (never send the opponent to a board they can immediately win; prefer moves that win or block a small board; value centre boards and centre cells), and **MCTS** for Hard and Impossible with a ~1–2s budget on Impossible. It will be extremely strong but **not** truly unbeatable, and that's acceptable.

### 6.1 Phase 3 balance testing
Run engine-vs-engine batches before art and monetization are built on top of these numbers:
- Does either stacking mode have a first-player advantage?
- Draw rate and average game length per mode — is the 9-chip Static inventory right?
- How often does the "most visible chips" tiebreak actually fire?
- Is Impossible genuinely unbeatable, or a forced draw?

**Preliminary findings (2026-07-20, `tool/balance_batch.dart`, small samples — see caveats below):**
- **Both stacking modes show a second-player advantage that sharpens with search strength**, the opposite of the naive assumption. Symmetric-difficulty batches (12 games/tier): Static P1 win rate 42%→8%→0% and Movable 67%→42%→0% going Easy→Medium→Hard. At Hard (deep, zero randomness) P2 won **100%** of games in both modes. This reads as a real property of the ruleset surfacing as play gets stronger, not search noise — worth a developer look before Phase 4 art/balance commit to the current inventories.
- **No draws observed** in any stacking symmetric batch (0/72 games). The tiebreak fired occasionally (8% of Static/Easy games) but never on an exact tie in this sample.
- **Game length shrinks as difficulty increases** (Static: 9.9→7.9→6.0 avg plies Easy→Hard; Movable: 8.3→9.8→12.0 — Movable's held roughly flat/up, plausibly because relocation gives stronger players more to do before the position resolves).
- **Ultimate**: tiebreak fires far more often than in stacking (20% Easy, 40% Medium) and games run long (~47–55 plies avg) — consistent with most/all small boards filling before a big-board line completes. Medium showed a 20% draw rate; Easy showed none in this sample.
- **Impossible-vs-Hard spot check is inconclusive on raw strength**, and Static's result illustrates why: Impossible went 2–2 against Hard, but given the P1/P2 finding above, that 2–2 is very likely just "Impossible-as-P1 lost both, Impossible-as-P2 won both" — i.e. it's re-confirming the seat effect, not showing Impossible is weaker. Movable (4–0) and Ultimate (2–0) favoured Impossible outright, but on samples of 2–4 games. **Whether Impossible is truly unbeatable vs. a forced result needs a proper follow-up**: larger trial counts, seat-controlled (report P1-seat and P2-seat records separately), before drawing a conclusion.
- Caveats: fixed random seed, small trial counts (12 games/tier for stacking, 2–10 for Ultimate depending on tier), one specific heuristic/search implementation — treat as directional. Re-run `tool/balance_batch.dart` with higher trial counts for a statistically tighter read.
