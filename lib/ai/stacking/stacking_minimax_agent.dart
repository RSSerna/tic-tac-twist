import 'dart:convert';
import 'dart:math';

import '../../engines/common/game_status.dart';
import '../../engines/common/player.dart';
import '../../engines/stacking/stacking_engine.dart';
import '../../engines/stacking/stacking_move.dart';
import '../difficulty.dart';

/// Minimax + alpha-beta + transposition table for the stacking engine
/// (rules doc §6). Branching is small enough to reach or near-reach full
/// depth, especially in the endgame.
///
/// Search is iterative deepening under a time budget: each tier gets a
/// depth cap and a wall-clock budget, whichever is hit first. Static's
/// bounded inventory keeps its game tree small; Movable's repetition rule
/// is the only thing bounding its tree, so Movable leans more on the time
/// budget than the depth cap.
class StackingMinimaxAgent {
  const StackingMinimaxAgent(this.difficulty);

  final Difficulty difficulty;

  static const _tiers = {
    Difficulty.easy: _Tier(maxDepth: 2, randomChance: 0.40, budgetMs: 200),
    Difficulty.medium: _Tier(maxDepth: 4, randomChance: 0.15, budgetMs: 300),
    Difficulty.hard: _Tier(maxDepth: 40, randomChance: 0, budgetMs: 400),
    Difficulty.impossible: _Tier(maxDepth: 40, randomChance: 0, budgetMs: 1500),
  };

  StackingMove chooseMove(StackingEngine engine, Random random) {
    final legalMoves = engine.legalMoves().cast<StackingMove>();
    if (legalMoves.length == 1) return legalMoves.single;

    final tier = _tiers[difficulty]!;
    if (random.nextDouble() < tier.randomChance) {
      return legalMoves[random.nextInt(legalMoves.length)];
    }

    final stopwatch = Stopwatch()..start();
    final budget = Duration(milliseconds: tier.budgetMs);
    final tt = <String, _TtEntry>{};
    var bestMove = legalMoves.first;

    for (var depth = 1; depth <= tier.maxDepth; depth++) {
      if (stopwatch.elapsed > budget) break;

      StackingMove? depthBest;
      var bestScore = -_infinity;
      var alpha = -_infinity;
      var timedOut = false;

      for (final move in _ordered(legalMoves, tt[_key(engine)])) {
        final child = engine.applyMove(move);
        final score =
            -_negamax(child, depth - 1, -_infinity, -alpha, tt, stopwatch, budget);
        if (stopwatch.elapsed > budget) {
          timedOut = true;
          break;
        }
        if (score > bestScore) {
          bestScore = score;
          depthBest = move;
        }
        if (score > alpha) alpha = score;
      }

      // A depth that ran out of the clock mid-search is unreliable — keep
      // the previous (fully searched) depth's answer instead.
      if (timedOut || depthBest == null) break;
      bestMove = depthBest;
      tt[_key(engine)] = _TtEntry(depth, bestScore, depthBest);
    }
    return bestMove;
  }
}

class _Tier {
  const _Tier({
    required this.maxDepth,
    required this.randomChance,
    required this.budgetMs,
  });

  final int maxDepth;
  final double randomChance;
  final int budgetMs;
}

class _TtEntry {
  const _TtEntry(this.depth, this.score, this.bestMove);

  final int depth;
  final double score;
  final StackingMove? bestMove;
}

const double _infinity = 1e15;

const _lines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6],
];

/// Negamax: returns a score from the perspective of whoever is about to
/// move at [engine]'s state — the caller negates it for its own turn.
double _negamax(
  StackingEngine engine,
  int depth,
  double alpha,
  double beta,
  Map<String, _TtEntry> tt,
  Stopwatch stopwatch,
  Duration budget,
) {
  final status = engine.status;
  if (status.isOver) {
    return _terminalScore(status, engine.currentPlayer, depth);
  }
  if (depth == 0 || stopwatch.elapsed > budget) {
    return _evaluate(engine);
  }

  final key = _key(engine);
  final cached = tt[key];
  if (cached != null && cached.depth >= depth) {
    return cached.score;
  }

  final legal = _ordered(engine.legalMoves().cast<StackingMove>(), cached);
  var best = -_infinity;
  StackingMove? bestMove;
  for (final move in legal) {
    final child = engine.applyMove(move);
    final score = -_negamax(child, depth - 1, -beta, -alpha, tt, stopwatch, budget);
    if (score > best) {
      best = score;
      bestMove = move;
    }
    if (best > alpha) alpha = best;
    if (alpha >= beta) break; // beta cutoff
    if (stopwatch.elapsed > budget) break;
  }
  tt[key] = _TtEntry(depth, best, bestMove);
  return best;
}

List<StackingMove> _ordered(List<StackingMove> moves, _TtEntry? entry) {
  final preferred = entry?.bestMove;
  if (preferred == null || !moves.contains(preferred)) return moves;
  return [preferred, ...moves.where((m) => m != preferred)];
}

String _key(StackingEngine engine) => jsonEncode(engine.toJson());

/// Prefers a quicker win / a slower loss by weighting in the remaining
/// search depth at which the terminal state was found.
double _terminalScore(GameStatus status, Player perspective, int depthRemaining) {
  if (status.outcome == GameOutcome.draw) return 0;
  final magnitude = 100000.0 + depthRemaining;
  return status.winner == perspective ? magnitude : -magnitude;
}

/// Heuristic for non-terminal cutoffs: visible-chip advantage (the same
/// metric the tiebreak rule uses) plus live line threats — a line where a
/// player holds 2 of 3 visible tops and the third is not opponent-blocked.
double _evaluate(StackingEngine engine) {
  final me = engine.currentPlayer;
  final opp = me.opponent;
  final visibleDiff = engine.visibleChipCount(me) - engine.visibleChipCount(opp);
  final lineDiff = _linePotential(engine, me) - _linePotential(engine, opp);
  return visibleDiff * 3.0 + lineDiff * 8.0;
}

int _linePotential(StackingEngine engine, Player player) {
  var count = 0;
  for (final line in _lines) {
    var mine = 0;
    var blockedByOpponent = false;
    for (final cell in line) {
      final top = engine.topChipAt(cell);
      if (top == null) continue;
      if (top.owner == player) {
        mine++;
      } else {
        blockedByOpponent = true;
      }
    }
    if (!blockedByOpponent && mine == 2) count++;
  }
  return count;
}
