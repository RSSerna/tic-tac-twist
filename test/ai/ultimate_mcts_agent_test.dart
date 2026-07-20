import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nested_game/ai/difficulty.dart';
import 'package:nested_game/ai/ultimate/ultimate_mcts_agent.dart';
import 'package:nested_game/engines/ultimate/ultimate_engine.dart';
import 'package:nested_game/engines/ultimate/ultimate_move.dart';

const winP1 = [1, 1, 1, 2, 2, 0, 0, 0, 0];
const winP2 = [2, 2, 2, 1, 1, 0, 0, 0, 0];

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

void main() {
  // MCTS is inherently approximate (rules doc §6: "strong, but not truly
  // unbeatable"), so these tests only lean on scenarios with an immediate,
  // unambiguous reward signal — not general tactical perfection.
  group('Hard tier (350ms budget)', () {
    const agent = UltimateMctsAgent(Difficulty.hard);

    test('finds a move that wins the entire game outright', () {
      // Boards 0 and 1 are already claimed by P1; board 2 has P1 one cell
      // away from completing its own row AND the big-board top row —
      // playing it ends the whole game immediately, the strongest possible
      // signal for a rollout-based search to detect.
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {
          0: winP1,
          1: winP1,
          2: [1, 1, 0, 2, 2, 0, 0, 0, 0],
        },
        currentPlayer: 1,
        targetBoard: 2,
      ));
      final move = agent.chooseMove(engine, Random(0));
      expect(move, const UltimateMove(2, 2));
    });

    test('always returns a legal move', () {
      final engine = UltimateEngine.fromJson(stateJson(
        boards: {0: winP1, 4: [1, 0, 2, 0, 2, 0, 1, 0, 0]},
        currentPlayer: 2,
        targetBoard: null,
      ));
      final move = agent.chooseMove(engine, Random(1));
      expect(engine.legalMoves(), contains(move));
    });

    test('a single legal move is returned without searching', () {
      // Boards 0–7 finished with a mix of claimants chosen so no big-board
      // line is complete yet; board 8 has exactly one empty cell: forced.
      final boards = <int, List<int>>{
        0: winP1, 1: winP2, 2: winP1, 3: winP2,
        4: winP1, 5: winP2, 6: winP2, 7: winP1,
        8: [1, 2, 1, 2, 1, 2, 0, 1, 2],
      };
      final engine = UltimateEngine.fromJson(
          stateJson(boards: boards, currentPlayer: 1, targetBoard: 8));
      expect(engine.status.isOngoing, isTrue);
      expect(engine.legalMoves(), hasLength(1));
      final move = agent.chooseMove(engine, Random(0));
      expect(move, engine.legalMoves().single);
    });
  });
}
