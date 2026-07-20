import 'dart:math';

import '../../engines/common/player.dart';
import '../../engines/ultimate/ultimate_engine.dart';
import '../../engines/ultimate/ultimate_move.dart';
import '../difficulty.dart';

/// Heuristic agent for Ultimate Easy/Medium (rules doc §6): no lookahead,
/// full minimax is not viable on this state space. Scores each candidate
/// move by whether it wins or blocks a small board, whether it hands the
/// opponent a board they can win outright next turn, and centre-board /
/// centre-cell preference — then ranks are perturbed by the tier's
/// randomness rate.
class UltimateHeuristicAgent {
  const UltimateHeuristicAgent(this.difficulty);

  final Difficulty difficulty;

  static const _randomChance = {
    Difficulty.easy: 0.40,
    Difficulty.medium: 0.15,
    Difficulty.hard: 0.0,
    Difficulty.impossible: 0.0,
  };

  UltimateMove chooseMove(UltimateEngine engine, Random random) {
    final legal = engine.legalMoves();
    if (legal.length == 1) return legal.single;

    final chance = _randomChance[difficulty] ?? 0.0;
    if (chance > 0 && random.nextDouble() < chance) {
      return legal[random.nextInt(legal.length)];
    }

    final me = engine.currentPlayer;
    var bestScore = -(1 << 30);
    final best = <UltimateMove>[];
    for (final move in legal) {
      final score = _score(engine, move, me);
      if (score > bestScore) {
        bestScore = score;
        best
          ..clear()
          ..add(move);
      } else if (score == bestScore) {
        best.add(move);
      }
    }
    return best[random.nextInt(best.length)];
  }

  int _score(UltimateEngine engine, UltimateMove move, Player me) {
    final after = engine.applyMove(move);
    var score = 0;

    // Win (or neutralise via a draw claim is impossible to target
    // deliberately, so only claimant wins count) the small board.
    if (after.resultOf(move.board).claimant == me) score += 1000;

    // Block: deny a cell that would have let the opponent win this board.
    if (_immediateWinCells(engine, move.board, me.opponent).contains(move.cell)) {
      score += 500;
    }

    // Never hand the opponent a board they can win outright next turn.
    final sentTo = after.targetBoard;
    if (sentTo != null &&
        _immediateWinCells(after, sentTo, me.opponent).isNotEmpty) {
      score -= 800;
    }

    score += _positionalWeight(move.board) * 6;
    score += _positionalWeight(move.cell) * 2;
    return score;
  }
}

const _lines = [
  [0, 1, 2], [3, 4, 5], [6, 7, 8],
  [0, 3, 6], [1, 4, 7], [2, 5, 8],
  [0, 4, 8], [2, 4, 6],
];

/// Empty cells in [board] where, were [player] to play there, they would
/// immediately win that small board.
Set<int> _immediateWinCells(UltimateEngine engine, int board, Player player) {
  if (engine.resultOf(board).isFinished) return const {};
  final wins = <int>{};
  for (var cell = 0; cell < 9; cell++) {
    if (engine.ownerOf(board, cell) != null) continue;
    if (_wouldWinBoard(engine, board, cell, player)) wins.add(cell);
  }
  return wins;
}

bool _wouldWinBoard(UltimateEngine engine, int board, int cell, Player player) {
  for (final line in _lines) {
    if (!line.contains(cell)) continue;
    final completes =
        line.every((i) => i == cell || engine.ownerOf(board, i) == player);
    if (completes) return true;
  }
  return false;
}

/// Classic 3×3 positional weight: centre > corner > edge.
int _positionalWeight(int index) {
  if (index == 4) return 3;
  if (index == 0 || index == 2 || index == 6 || index == 8) return 2;
  return 1;
}
