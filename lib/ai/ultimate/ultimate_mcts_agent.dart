import 'dart:math';

import '../../engines/common/game_status.dart';
import '../../engines/common/player.dart';
import '../../engines/ultimate/ultimate_engine.dart';
import '../../engines/ultimate/ultimate_move.dart';
import '../difficulty.dart';

/// Monte Carlo tree search for Ultimate Hard/Impossible (rules doc §6): full
/// minimax is not viable on this state space, so search is UCT-guided
/// random playouts under a wall-clock budget rather than a depth bound.
/// Strong, but not truly unbeatable — that's an accepted trade-off per the
/// rules doc.
class UltimateMctsAgent {
  const UltimateMctsAgent(this.difficulty);

  final Difficulty difficulty;

  static const _budgetMs = {
    Difficulty.hard: 350,
    Difficulty.impossible: 1500,
  };

  static const _explorationConstant = 1.4142135623730951; // sqrt(2)

  UltimateMove chooseMove(UltimateEngine engine, Random random) {
    final legal = engine.legalMoves();
    if (legal.length == 1) return legal.single;

    final budget = Duration(milliseconds: _budgetMs[difficulty] ?? 350);
    final root = _Node(engine, null, null)
      ..untriedMoves = (List.of(legal)..shuffle(random));

    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < budget) {
      var node = root;
      while (!node.isTerminal && node.isFullyExpanded) {
        node = _selectChild(node);
      }
      if (!node.isTerminal && node.untriedMoves!.isNotEmpty) {
        node = _expand(node, random);
      }
      final result = _rollout(node.engine, random);
      _backpropagate(node, result);
    }

    // Robust child: most-visited, not highest-average — standard MCTS
    // practice, more stable under a tight time budget than raw value.
    _Node? best;
    for (final child in root.children) {
      if (best == null || child.visits > best.visits) best = child;
    }
    return best?.move ?? legal[random.nextInt(legal.length)];
  }

  _Node _expand(_Node node, Random random) {
    final move = node.untriedMoves!.removeLast();
    final childEngine = node.engine.applyMove(move);
    final child = _Node(childEngine, move, node);
    child.untriedMoves = child.isTerminal
        ? const []
        : (List.of(childEngine.legalMoves())..shuffle(random));
    node.children.add(child);
    return child;
  }

  _Node _selectChild(_Node node) {
    final logParentVisits = log(node.visits.toDouble());
    var best = node.children.first;
    var bestUcb = double.negativeInfinity;
    for (final child in node.children) {
      // Value to the parent's mover is the complement of the child's own
      // perspective — child.engine.currentPlayer is the parent's opponent.
      final exploitation = 1.0 - child.averageValue;
      final exploration =
          _explorationConstant * sqrt(logParentVisits / child.visits);
      final ucb = exploitation + exploration;
      if (ucb > bestUcb) {
        bestUcb = ucb;
        best = child;
      }
    }
    return best;
  }

  /// Uniform-random playout to a terminal state. Ultimate's move count is
  /// bounded (≤81 plies), so this always terminates quickly.
  double _rollout(UltimateEngine engine, Random random) {
    final perspective = engine.currentPlayer;
    var current = engine;
    while (!current.status.isOver) {
      final moves = current.legalMoves();
      current = current.applyMove(moves[random.nextInt(moves.length)]);
    }
    return _resultValue(current.status, perspective);
  }

  void _backpropagate(_Node node, double resultForNodePerspective) {
    _Node? current = node;
    var value = resultForNodePerspective;
    while (current != null) {
      current.visits++;
      current.totalValue += value;
      value = 1.0 - value; // flip: the parent's mover is the opponent here
      current = current.parent;
    }
  }
}

/// Result on a [0, 1] scale from [perspective]'s point of view — the scale
/// UCT's exploration term assumes.
double _resultValue(GameStatus status, Player perspective) {
  if (status.outcome == GameOutcome.draw) return 0.5;
  return status.winner == perspective ? 1.0 : 0.0;
}

class _Node {
  _Node(this.engine, this.move, this.parent);

  final UltimateEngine engine;

  /// The move that led here from [parent]; null for the search root.
  final UltimateMove? move;
  final _Node? parent;
  final List<_Node> children = [];
  List<UltimateMove>? untriedMoves;
  int visits = 0;

  /// Sum of playout results from the perspective of `engine.currentPlayer`
  /// — whoever is about to move at this node.
  double totalValue = 0;

  bool get isTerminal => engine.status.isOver;
  bool get isFullyExpanded =>
      untriedMoves != null && untriedMoves!.isEmpty && children.isNotEmpty;
  double get averageValue => visits == 0 ? 0.5 : totalValue / visits;
}
