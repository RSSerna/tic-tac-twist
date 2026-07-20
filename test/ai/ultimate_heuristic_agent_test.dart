import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/ai/ultimate/ultimate_heuristic_agent.dart';
import 'package:nested_game/engines/common/player.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';

Map<String, Object?> stateJson({
  required Map<int, List<int>> boards,
  required int currentPlayer,
  int? targetBoard,
}) {
  final cells = List<int>.filled(81, 0);
  boards.forEach((board, layout) {
    for (var i = 0; i < 9; i++) {
      cells[board * 9 + i] = layout[i];
    }
  });
  return {'cells': cells, 'currentPlayer': currentPlayer, 'targetBoard': targetBoard};
}

/// Whether [player] has an empty cell in [board] that would win it outright
/// — a black-box reimplementation using only public engine API, so this
/// test doesn't depend on the agent's private helpers.
bool boardHasImmediateWin(UltimateEngine engine, int board, Player player) {
  const lines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];
  for (final line in lines) {
    final owners = line.map((c) => engine.ownerOf(board, c)).toList();
    final playerCells = owners.where((o) => o == player).length;
    final emptyCells = owners.where((o) => o == null).length;
    if (playerCells == 2 && emptyCells == 1) return true;
  }
  return false;
}

void main() {
  // Difficulty.hard has zero injected randomness in this agent's own
  // lookup table, giving deterministic assertions even though production
  // code never actually routes hard/impossible to the heuristic agent.
  const agent = UltimateHeuristicAgent(Difficulty.hard);

  test('wins the small board when a winning cell is available', () {
    final engine = UltimateEngine.fromJson(stateJson(
      boards: {
        3: [1, 1, 0, 0, 0, 0, 0, 0, 0],
      },
      currentPlayer: 1,
      targetBoard: 3,
    ));
    final move = agent.chooseMove(engine, Random(0));
    expect(move, const UltimateMove(3, 2));
  });

  test('blocks the opponent\'s immediate small-board win over other cells',
      () {
    // Only cell 2 denies P2's row 0,1,2; cells 3–8 are open but tactically
    // idle, so the block bonus must outweigh raw positional weight.
    final engine = UltimateEngine.fromJson(stateJson(
      boards: {
        3: [2, 2, 0, 0, 0, 0, 0, 0, 0],
      },
      currentPlayer: 1,
      targetBoard: 3,
    ));
    final move = agent.chooseMove(engine, Random(0));
    expect(move, const UltimateMove(3, 2));
  });

  test('prefers the centre board and centre cell absent any tactics', () {
    final engine = UltimateEngine.initial();
    final move = agent.chooseMove(engine, Random(0));
    expect(move, const UltimateMove(4, 4));
  });

  test('never sends the opponent to a board they can win outright', () {
    // Board 3 is a trap: P2 already threatens row 0,1,2 there. My free
    // move must avoid playing cell-index 3 anywhere (that's what would
    // send P2 into board 3), even though plenty of other cells exist.
    final engine = UltimateEngine.fromJson(stateJson(
      boards: {3: [2, 2, 0, 0, 0, 0, 0, 0, 0]},
      currentPlayer: 1,
      targetBoard: null,
    ));
    final move = agent.chooseMove(engine, Random(0));
    final after = engine.applyMove(move);
    if (after.targetBoard != null) {
      expect(boardHasImmediateWin(after, after.targetBoard!, Player.two), isFalse,
          reason: 'sent the opponent to board ${after.targetBoard}, '
              'which they can win immediately');
    }
  });

  test('always returns a legal move across tiers and randomness', () {
    for (final difficulty in Difficulty.values) {
      final tierAgent = UltimateHeuristicAgent(difficulty);
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {0: [1, 2, 1, 2, 1, 2, 0, 0, 0]},
        currentPlayer: 2,
        targetBoard: null,
      ));
      for (var seed = 0; seed < 5; seed++) {
        final move = tierAgent.chooseMove(engine, Random(seed));
        expect(engine.legalMoves(), contains(move));
      }
    }
  });
}
